import Charts
import Po0FFI
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PageScaffold("Dashboard", subtitle: subtitle) {
            Button {
                if let group = model.primaryGroup { model.testDelay(group.name) }
            } label: {
                Label("Test delay", systemImage: "bolt")
            }
            .help("Test delay")
            .disabled(model.primaryGroup == nil)
            Button {
                model.refreshExitIpNow()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh")
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let error = model.launchError {
                        Label {
                            Text(error).textSelection(.enabled)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface()
                    }
                    if case .failed(let message)? = model.status?.engine {
                        FailureCard(message: message)
                    }
                    DashboardGrid(spacing: 12) {
                        Group {
                            CurrentNodeCard().dashboardSpan(2)
                            SpeedCard().dashboardSpan(2)
                            ModeCard().dashboardSpan(2)
                            RouteCard()
                            WhitelistCard()
                        }
                        Group {
                            TrafficCard()
                            ConnectionsCard()
                            MemoryCard()
                            IntranetIpCard()
                            SubscriptionCard().dashboardSpan(2)
                            ExitIpCard().dashboardSpan(2)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
        }
        .background(WindowVisibility { model.setVisible(.dashboard, $0) })
        .onDisappear { model.setVisible(.dashboard, false) }
    }

    private var subtitle: String {
        let profile = model.profiles.first(where: \.selected)?.title
        return [profile, model.status?.mode.name].compactMap { $0 }.joined(separator: " · ")
    }
}

/// FlClash's dashboard grid: four columns in a wide window and two in a narrow one; a card spans one or two
/// columns, and the cards in a row share the tallest one's height.
private struct DashboardGrid: Layout {
    var spacing: CGFloat

    private struct Cell {
        let index: Int
        let x: CGFloat
        let width: CGFloat
    }

    private struct Row {
        var cells: [Cell] = []
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 720
        let rows = arrange(subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            for cell in row.cells {
                subviews[cell.index].place(
                    at: CGPoint(x: bounds.minX + cell.x, y: y),
                    proposal: ProposedViewSize(width: cell.width, height: row.height)
                )
            }
            y += row.height + spacing
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        let columns = width >= 820 ? 4 : 2
        let unit = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var rows: [Row] = []
        var row = Row()
        var used = 0
        for (index, subview) in subviews.enumerated() {
            let span = min(subview[DashboardSpan.self], columns)
            if used + span > columns {
                rows.append(row)
                row = Row()
                used = 0
            }
            let cellWidth = unit * CGFloat(span) + spacing * CGFloat(span - 1)
            row.cells.append(Cell(index: index, x: (unit + spacing) * CGFloat(used), width: cellWidth))
            row.height = max(row.height, subview.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height)
            used += span
        }
        if !row.cells.isEmpty { rows.append(row) }
        return rows
    }
}

private struct DashboardSpan: LayoutValueKey {
    static let defaultValue = 1
}

private extension View {
    func dashboardSpan(_ span: Int) -> some View {
        layoutValue(key: DashboardSpan.self, value: span)
    }
}

/// A small grey title with its symbol, an optional accessory on the right, then the card's own content.
private struct Card<Accessory: View, Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    private let accessory: Accessory
    private let content: Content

    init(
        _ title: LocalizedStringKey,
        symbol: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 8)
                accessory
            }
            .foregroundStyle(.secondary)
            .frame(minHeight: 22)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardSurface()
    }
}

private extension Card where Accessory == EmptyView {
    init(_ title: LocalizedStringKey, symbol: String, @ViewBuilder content: () -> Content) {
        self.init(title, symbol: symbol, accessory: { EmptyView() }, content: content)
    }
}

private struct Caption: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
    }
}

private struct FailureCard: View {
    @EnvironmentObject private var model: AppModel
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection failed").fontWeight(.medium)
                Text(message).font(.callout).foregroundStyle(.secondary).lineLimit(6).textSelection(.enabled)
            }
            Spacer()
            Button("Reconnect") { model.reconnect() }
                .glassButton(prominent: true)
                .disabled(model.busy)
        }
        .padding(14)
        .cardSurface()
    }
}

private struct CurrentNodeCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        Card("Current node", symbol: "globe") {
            if let group = model.primaryGroup {
                Button {
                    navigation.page = .proxies
                } label: {
                    HStack(spacing: 3) {
                        Text(group.name).lineLimit(1)
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(Color.controlFill, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        } content: {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: currentNode?.name ?? "—")
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Caption(text: meta)
                }
                Spacer(minLength: 0)
                if let node = currentNode {
                    if let delay = Format.delay(node) {
                        HStack(spacing: 5) {
                            StatusDot(color: Format.delayTint(node.delay))
                            Text(verbatim: delay)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Format.delayTint(node.delay))
                    }
                    CircleButton(symbol: "bolt", help: "Test delay", size: 30, busy: model.testing.contains(node.name)) {
                        model.testNodeDelay(node.name)
                    }
                }
            }
            if let group = model.primaryGroup, !alternatives.isEmpty {
                Divider().padding(.vertical, 2)
                ViewThatFits(in: .horizontal) {
                    ForEach([3, 2, 1], id: \.self) { count in
                        switchRow(group, nodes: Array(alternatives.prefix(count)))
                    }
                }
            }
        }
    }

    private func switchRow(_ group: ProxyGroup, nodes: [Node]) -> some View {
        HStack(spacing: 8) {
            Text("Switch to").font(.system(size: 12)).foregroundStyle(.secondary)
            ForEach(nodes, id: \.name) { node in
                Button {
                    model.selectNode(group: group.name, node: node.name)
                } label: {
                    HStack(spacing: 6) {
                        Text(verbatim: node.name).lineLimit(1)
                        if let delay = Format.delay(node) {
                            Text(verbatim: delay).foregroundStyle(Format.delayTint(node.delay)).monospacedDigit()
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Color.controlFill, in: Capsule())
                    .contentShape(Capsule())
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .disabled(!group.selectable || model.busy)
            }
        }
    }

    private var currentNode: Node? {
        guard model.isRunning, let name = model.status?.currentNode else { return nil }
        return model.groups.lazy.flatMap(\.nodes).first { $0.name == name }
    }

    private var meta: String {
        guard model.isRunning, let group = model.primaryGroup else {
            return String(localized: "Connect to see the node in use.")
        }
        return [currentNode?.kind, group.name, Format.nodeCount(group.nodes.count)].compactMap { $0 }
            .joined(separator: " · ")
    }

    /// The fastest other members of the group, one click away.
    private var alternatives: [Node] {
        guard model.isRunning, let group = model.primaryGroup else { return [] }
        return group.nodes
            .filter { $0.name != group.now && ($0.delay ?? 0) > 0 }
            .sorted { ($0.delay ?? .max) < ($1.delay ?? .max) }
    }
}

private struct SpeedCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Speed", symbol: "chart.xyaxis.line") {
            Text("Last 60 s").font(.system(size: 12, weight: .medium))
        } content: {
            HStack(spacing: 32) {
                rate(model.traffic?.down, label: "Download", tint: .accentColor)
                rate(model.traffic?.up, label: "Upload", tint: SpeedChart.uploadTint)
            }
            SpeedChart(history: model.isRunning ? model.trafficHistory : [])
        }
    }

    private func rate(_ value: UInt64?, label: LocalizedStringKey, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Metric(model.isRunning ? Format.rate(value ?? 0) : "—", size: 28)
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(label)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
    }
}

/// The last minute of download (accent, over a flat fill) and upload (grey), newest on the right.
private struct SpeedChart: View {
    let history: [Traffic]

    static let uploadTint = Color(nsColor: .systemGray)
    private static let span = 60

    var body: some View {
        let offset = SpeedChart.span - history.count
        let peak = history.map { Double(max($0.down, $0.up)) }.max() ?? 0
        Chart {
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Color.primary.opacity(0.12))
                .lineStyle(StrokeStyle(lineWidth: 1))
            ForEach(Array(history.enumerated()), id: \.offset) { index, sample in
                AreaMark(x: .value("Time", offset + index), y: .value("Speed", Double(sample.down)))
                    .foregroundStyle(Color.accentColor.opacity(0.1))
                    .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Time", offset + index),
                    y: .value("Speed", Double(sample.down)),
                    series: .value("Direction", "down")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Time", offset + index),
                    y: .value("Speed", Double(sample.up)),
                    series: .value("Direction", "up")
                )
                .foregroundStyle(SpeedChart.uploadTint)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
        }
        .chartXScale(domain: 0...SpeedChart.span)
        .chartYScale(domain: 0...max(peak * 1.1, 1))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 64)
        .accessibilityLabel(Text("Speed"))
    }
}

private struct ModeCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Mode", symbol: "arrow.triangle.branch") {
            Picker("Mode", selection: Binding(get: { model.status?.mode ?? .rule }, set: { model.setMode($0) })) {
                Text("Rule").tag(Mode.rule)
                Text("Global").tag(Mode.global)
                Text("Direct").tag(Mode.direct)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(model.busy || model.status == nil)
            Text((model.status?.mode ?? .rule).detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct RouteCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Network takeover", symbol: "network") {
            Picker("Route", selection: Binding(
                get: { model.status?.routeMode ?? .systemProxy },
                set: { model.setRouteMode($0) }
            )) {
                Text("TUN").tag(RouteMode.tun)
                Text("System proxy").tag(RouteMode.systemProxy)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(model.busy || model.status == nil)
            HStack(spacing: 6) {
                StatusDot(color: model.isRunning ? .green : Color(nsColor: .tertiaryLabelColor))
                Text(state)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private var state: LocalizedStringKey {
        guard model.isRunning else { return "Not connected" }
        return model.status?.routeMode == .tun ? "Taking over all traffic" : "Set as the system proxy"
    }
}

private struct WhitelistCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        Card("Auto whitelist", symbol: "checkmark.shield") {
            Toggle("Auto whitelist", isOn: Binding(
                get: { model.whitelist?.enabled ?? false },
                set: { model.setWhitelistEnabled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .disabled(model.whitelist == nil)
        } content: {
            Button {
                navigation.page = .whitelist
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Metric(entries.count == 1 ? String(localized: "1 entry") : String(localized: "\(entries.count) entries"))
                    HStack(spacing: 6) {
                        StatusDot(color: tint)
                        Text(verbatim: summary)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var entries: [WhitelistEntry] { model.whitelist?.entries ?? [] }

    private var summary: String {
        guard let last = entries.compactMap({ $0.result?.at }).max() else { return model.whitelistSummary }
        return "\(model.whitelistSummary) · \(Format.ago(last))"
    }

    private var tint: Color {
        let outcomes = entries.compactMap { $0.result?.outcome }
        if model.whitelist?.enabled != true || outcomes.isEmpty { return Color(nsColor: .tertiaryLabelColor) }
        if outcomes.contains(where: { $0 == .rejected || $0 == .error }) { return .red }
        return outcomes.allSatisfy { $0 == .applied } ? .green : .orange
    }
}

private struct TrafficCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let summary = model.connectionSummary
        Card("Traffic", symbol: "arrow.up.arrow.down") {
            Metric(model.isRunning ? Format.bytes(summary.upload + summary.download) : "—")
            Caption(text: model.isRunning
                ? "↑ \(Format.bytes(summary.upload)) · ↓ \(Format.bytes(summary.download))" : " ")
        }
    }
}

private struct ConnectionsCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        Card("Connections", symbol: "link") {
            Button {
                navigation.page = .activity
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Activity")
        } content: {
            Metric(model.isRunning ? "\(model.connectionSummary.count)" : "—")
            Text("Active connections").font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

private struct MemoryCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Memory", symbol: "memorychip") {
            Metric(model.isRunning && model.memory > 0 ? Format.bytes(model.memory) : "—")
            Caption(text: "mihomo")
        }
    }
}

private struct IntranetIpCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Intranet IP", symbol: "desktopcomputer") {
            Text(verbatim: model.intranetIp?.ip ?? "—")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Caption(text: model.intranetIp?.interface ?? " ")
        }
    }
}

private struct SubscriptionCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    private var current: Profile? { model.profiles.first(where: \.selected) }

    var body: some View {
        Card("Subscription", symbol: "square.stack.3d.up") {
            if let profile = current {
                if let updated = profile.updatedAt {
                    Text("Updated \(Format.ago(updated))").font(.system(size: 12, weight: .medium))
                }
                if profile.url != nil {
                    CircleButton(symbol: "arrow.clockwise", help: "Update", busy: model.updating.contains(profile.id)) {
                        model.updateProfile(profile.id)
                    }
                }
            }
        } content: {
            if let profile = current {
                HStack(alignment: .firstTextBaseline) {
                    Menu {
                        ForEach(model.profiles, id: \.id) { other in
                            Button(other.title) { model.selectProfile(other.id) }
                        }
                    } label: {
                        Text(verbatim: profile.title).font(.system(size: 15, weight: .semibold))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(model.busy)
                    Spacer()
                    if let usage = profile.usage, usage.total > 0 {
                        Caption(text: "\(Int((usage.fraction * 100).rounded()))%")
                    }
                }
                if let usage = profile.usage, usage.total > 0 {
                    UsageBar(usage: usage)
                } else {
                    Text("The provider reports no usage.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            } else {
                Button("Add Subscription…") { navigation.page = .profiles }
                    .buttonStyle(.link)
            }
        }
    }
}

private struct ExitIpCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Exit IP", symbol: "mappin.and.ellipse") {
            CircleButton(symbol: "arrow.clockwise", help: "Refresh") { model.refreshExitIpNow() }
        } content: {
            Text(verbatim: model.exitIp?.ip ?? "—")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Caption(text: model.exitIp?.country ?? " ")
        }
    }
}

struct UsageBar: View {
    let usage: Usage

    var body: some View {
        let used = usage.upload + usage.download
        VStack(alignment: .leading, spacing: 6) {
            Capsule()
                .fill(Color.controlFill)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: usage.fraction > 0 ? max(proxy.size.width * usage.fraction, 6) : 0)
                    }
                }
            HStack {
                Text("\(Format.bytes(used)) of \(Format.bytes(usage.total)) used")
                Spacer()
                if let expire = usage.expire {
                    Text("Expires \(Format.date(expire), format: .dateTime.year().month().day())")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }
}

extension Usage {
    var fraction: Double {
        min(Double(upload + download) / Double(max(total, 1)), 1)
    }
}

extension Mode {
    var name: String {
        switch self {
        case .rule: return String(localized: "Rule mode")
        case .global: return String(localized: "Global mode")
        case .direct: return String(localized: "Direct mode")
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .rule: return "Routes by the profile's rules."
        case .global: return "Sends everything through the current node."
        case .direct: return "Connects directly without a proxy."
        }
    }
}
