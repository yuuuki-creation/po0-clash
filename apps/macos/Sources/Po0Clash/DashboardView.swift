import Po0FFI
import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing = false
    @State private var draggedCard: DashboardCard?
    @State private var previewCards: [DashboardCard]?

    private var cards: [DashboardCard] {
        previewCards ?? model.appSettings?.dashboardCards ?? DashboardCard.all
    }

    var body: some View {
        PageScaffold("Dashboard") {
            IconButton(symbol: "bolt", help: "Test delay", busy: testingPrimary) {
                if let group = model.primaryGroup { model.testDelay(group.name) }
            }
            .disabled(model.primaryGroup == nil)
            IconButton(symbol: "arrow.clockwise", help: "Refresh") { model.refreshExitIpNow() }
            if editing {
                MenuButton(placement: .belowTrailing) {
                    Image(systemName: "plus").font(.system(size: 15))
                } entries: {
                    addEntries
                }
                .buttonStyle(IconButtonStyle())
                .help("Add")
            }
            IconButton(
                symbol: editing ? "checkmark" : "square.grid.2x2",
                help: editing ? LocalizedStringKey("Done") : LocalizedStringKey("Edit Dashboard")
            ) {
                editing.toggle()
                draggedCard = nil
                previewCards = nil
            }
            .disabled(model.appSettings == nil)
        } content: {
            PageScroll {
                StatusGroup()
                TwoColumns() {
                    column(families.enumerated().filter { $0.offset % 2 == 0 }.map(\.element))
                    column(families.enumerated().filter { $0.offset % 2 == 1 }.map(\.element))
                }
                .rowListMotion(ids: cards)
            }
        }
        .background(WindowVisibility { model.setVisible(.dashboard, $0) })
        .onDisappear { model.setVisible(.dashboard, false) }
    }

    private var testingPrimary: Bool {
        model.primaryGroup.map { model.testingGroups.contains($0.name) } ?? false
    }

    private var addEntries: [MenuEntry] {
        let missing = DashboardCard.all.filter { !cards.contains($0) }.map { card in
            MenuEntry.action(card.menuTitle, perform: { save(cards + [card]) })
        }
        let restore = MenuEntry.action(String(localized: "Restore Defaults"), perform: { save(DashboardCard.all) })
        return missing + [MenuEntry.separator, restore]
    }

    /// Each card keeps its place in a family of rows; families take turns between the columns in the order of their
    /// first card, which draws the design's arrangement from the core's default order.
    private var families: [DashboardFamilyRows] {
        var order: [DashboardFamily] = []
        var rows: [DashboardFamily: [DashboardCard]] = [:]
        for card in cards {
            if rows[card.family] == nil { order.append(card.family) }
            rows[card.family, default: []].append(card)
        }
        return order.map { DashboardFamilyRows(family: $0, cards: rows[$0] ?? []) }
    }

    private func column(_ families: [DashboardFamilyRows]) -> some View {
        VStack(spacing: Ui.block) {
            ForEach(families) { family in
                RowGroup {
                    ForEach(family.cards, id: \.self) { card in
                        row(card)
                    }
                }
            }
        }
    }

    private func row(_ card: DashboardCard) -> some View {
        HStack(spacing: 0) {
            if editing {
                DashboardDragHandle {
                    previewCards = cards
                    draggedCard = card
                } ended: {
                    previewCards = nil
                    draggedCard = nil
                }
                .frame(width: Ui.control, height: Ui.control)
                .padding(.leading, 8)
            }
            card.row
                .allowsHitTesting(!editing)
            if editing {
                IconButton(symbol: "minus.circle.fill", help: "Remove", tint: .bad) {
                    save(cards.filter { $0 != card })
                }
                .padding(.trailing, 8)
            }
        }
        .opacity(draggedCard == card ? 0.55 : 1)
        .transition(.rowFold)
        .onDrop(of: [.text], delegate: DashboardDropTarget(
            card: card,
            dragged: $draggedCard,
            cards: Binding(get: { cards }, set: { previewCards = $0 }),
            save: save
        ))
    }

    private func save(_ cards: [DashboardCard]) {
        model.updateAppSettings { $0.dashboardCards = cards }
        previewCards = nil
        draggedCard = nil
    }
}

private enum DashboardFamily: Hashable {
    case controls, info, speed, stats
}

private struct DashboardFamilyRows: Identifiable {
    let family: DashboardFamily
    let cards: [DashboardCard]
    var id: DashboardFamily { family }
}

extension DashboardCard {
    static let all: [DashboardCard] = [
        .currentNode, .speed, .mode, .takeover, .whitelist, .traffic, .connections, .memory, .intranetIp,
        .subscription, .exitIp,
    ]

    /// For the menu of cards to add, which AppKit draws and so cannot take a `LocalizedStringKey`.
    fileprivate var menuTitle: String {
        switch self {
        case .currentNode: return String(localized: "Current node")
        case .speed: return String(localized: "Speed")
        case .mode: return String(localized: "Mode")
        case .takeover: return String(localized: "Network takeover")
        case .whitelist: return String(localized: "Auto whitelist")
        case .traffic: return String(localized: "Traffic")
        case .connections: return String(localized: "Connections")
        case .memory: return String(localized: "Memory")
        case .intranetIp: return String(localized: "Intranet IP")
        case .subscription: return String(localized: "Subscription")
        case .exitIp: return String(localized: "Exit IP")
        }
    }

    fileprivate var family: DashboardFamily {
        switch self {
        case .currentNode, .mode, .takeover: return .controls
        case .whitelist, .subscription, .exitIp, .intranetIp: return .info
        case .speed: return .speed
        case .traffic, .connections, .memory: return .stats
        }
    }

    @ViewBuilder
    fileprivate var row: some View {
        switch self {
        case .currentNode: CurrentNodeRow()
        case .speed: SpeedRows()
        case .mode: ModeRow()
        case .takeover: RouteRow()
        case .whitelist: WhitelistRow()
        case .traffic: TrafficRow()
        case .connections: ConnectionsRow()
        case .memory: MemoryRow()
        case .intranetIp: IntranetIpRow()
        case .subscription: SubscriptionRow()
        case .exitIp: ExitIpRow()
        }
    }
}

private struct StatusGroup: View {
    @EnvironmentObject private var model: AppModel

    private var starting: Bool { model.isOn && !model.isRunning }

    private var dotColor: Color {
        if model.isRunning { return .accentColor }
        if starting { return .warn }
        if case .failed? = model.status?.engine { return .bad }
        return .ink3
    }

    private var statusText: LocalizedStringKey {
        if model.isRunning { return "Connected" }
        if starting { return "Connecting…" }
        if case .failed? = model.status?.engine { return "Connection failed" }
        return "Not connected"
    }

    var body: some View {
        RowGroup {
            Row(height: 56) {
                StatusDot(color: dotColor, pulsing: starting)
                HStack(spacing: 12) {
                    Text(statusText).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    if let since = model.connectedAt {
                        TimelineView(.periodic(from: since, by: 1)) { context in
                            Text(verbatim: Format.elapsed(since, now: context.date))
                                .foregroundStyle(Color.ink2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PowerButton(starting: starting)
            }
            if let error = model.launchError {
                Row { ErrorText(message: error) }
            }
            if case .failed(let message)? = model.status?.engine {
                Row {
                    ErrorText(message: message).lineLimit(6)
                    Button("Reconnect") { model.reconnect() }
                        .disabled(model.busy)
                }
            }
        }
    }
}

private struct PowerButton: View {
    @EnvironmentObject private var model: AppModel
    let starting: Bool

    private var busy: Bool { model.busy || starting }

    var body: some View {
        Button {
            model.setConnected(!model.isOn)
        } label: {
            ZStack {
                // The widest label holds the width, so changing state never moves the row.
                Group {
                    Text("Disconnect")
                    Text("Connect")
                    HStack(spacing: 8) {
                        Color.clear.frame(width: 14, height: 14)
                        Text("Connecting…")
                    }
                }
                .hidden()
                if busy {
                    busyLabel
                } else {
                    Text(model.isOn ? LocalizedStringKey("Disconnect") : LocalizedStringKey("Connect"))
                }
            }
            .frame(minWidth: 80)
        }
        .buttonStyle(ActionButtonStyle(primary: !model.isRunning))
        .disabled(busy || model.status == nil)
        .contextMenu {
            Button("Restart Engine") { model.reconnect() }
                .disabled(!model.isOn || model.busy)
        }
    }

    private var busyLabel: some View {
        HStack(spacing: 8) {
            Ring()
            Text(model.isRunning ? LocalizedStringKey("Disconnect") : LocalizedStringKey("Connecting…"))
        }
    }
}

private struct CurrentNodeRow: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        LinkRow(Text("Current node")) {
            navigation.page = .proxies
        } value: {
            Text(verbatim: currentNode?.name ?? "—").truncationMode(.middle)
            if let node = currentNode {
                Text(verbatim: Format.delay(node) ?? "—")
                    .foregroundStyle(Format.delayTint(node.delay))
            }
        }
        .contextMenu {
            if let node = currentNode {
                Button("Test delay") { model.testNodeDelay(node.name) }
                    .disabled(model.testingNodes.contains(node.name))
            }
            if let group = model.primaryGroup, !alternatives.isEmpty {
                Section("Switch to") {
                    ForEach(alternatives.prefix(5), id: \.name) { node in
                        Button(Format.delay(node).map { "\(node.name)   \($0)" } ?? node.name) {
                            model.selectNode(group: group.name, node: node.name)
                        }
                        .disabled(!group.selectable || model.busy)
                    }
                }
            }
        }
    }

    private var currentNode: Node? {
        guard model.isRunning, let name = model.status?.currentNode else { return nil }
        return model.groups.lazy.flatMap(\.nodes).first { $0.name == name }
    }

    /// The fastest other members of the group, one click away.
    private var alternatives: [Node] {
        guard model.isRunning, let group = model.primaryGroup else { return [] }
        return group.nodes
            .filter { $0.name != group.now && ($0.delay ?? 0) > 0 }
            .sorted { ($0.delay ?? .max) < ($1.delay ?? .max) }
    }
}

private struct RateLabel: View {
    let symbol: String
    let tint: Color
    let text: String
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .accessibilityLabel(Text(label))
            Text(verbatim: text)
        }
        .lineLimit(1)
    }
}

private struct SpeedRows: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Row {
                Text("Speed").frame(maxWidth: .infinity, alignment: .leading)
                RateLabel(
                    symbol: "arrow.down", tint: .accentColor, text: Format.rate(model.traffic?.down ?? 0),
                    label: "Download"
                )
                RateLabel(symbol: "arrow.up", tint: .ink2, text: Format.rate(model.traffic?.up ?? 0), label: "Upload")
            }
            SpeedChart(history: model.isRunning ? model.trafficHistory : [])
                .hairlineAbove()
        }
    }
}

/// Plain shapes, since Swift Charts aborts on the paravirtual GPU of Intel Mac virtual machines. Each second's newest
/// sample starts one step past the right edge and the whole chart slides it in.
private struct SpeedChart: View {
    let history: [Traffic]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 1

    private static let span = 60

    var body: some View {
        GeometryReader { proxy in
            let step = proxy.size.width / CGFloat(Self.span - 1)
            let peak = max(history.map { Double(max($0.down, $0.up)) }.max() ?? 0, 1)
            ZStack {
                SpeedLine(values: history.map { Double($0.up) / peak }, step: step)
                    .stroke(Color.ink2, lineWidth: 1.25)
                SpeedLine(values: history.map { Double($0.down) / peak }, step: step)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            }
            .offset(x: -step * phase)
        }
        .frame(height: 148)
        .clipped()
        .accessibilityElement()
        .accessibilityLabel(Text("Speed"))
        .onReceive(AppModel.shared.$trafficHistory) { _ in advance() }
    }

    private func advance() {
        guard !reduceMotion else { return }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { phase = 0 }
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 1)) { phase = 1 }
        }
    }
}

private struct SpeedLine: Shape {
    let values: [Double]
    let step: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = rect.maxX + step - CGFloat(values.count - 1 - index) * step
            let y = rect.maxY - 6 - CGFloat(value) * 0.9 * (rect.height - 16)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

private struct ModeRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ControlRow(Text("Mode")) {
            SegmentedControl(
                selection: Binding(get: { model.status?.mode ?? .rule }, set: { model.setMode($0) }),
                segments: Mode.segments
            )
            .disabled(model.busy || model.status == nil)
        }
    }
}

extension Mode {
    static let segments = [
        Segment(Mode.rule, "Rule"), Segment(Mode.global, "Global"), Segment(Mode.direct, "Direct"),
    ]
}

private struct RouteRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ControlRow(Text("Network takeover")) {
            SegmentedControl(
                selection: Binding(get: { model.status?.routeMode ?? .systemProxy }, set: { model.setRouteMode($0) }),
                segments: RouteMode.segments
            )
            .disabled(model.busy || model.status == nil)
        }
    }
}

extension RouteMode {
    static let segments = [Segment(RouteMode.tun, "TUN"), Segment(RouteMode.systemProxy, "System proxy")]
}

private struct WhitelistRow: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        LinkRow(Text("Whitelist")) {
            navigation.page = .whitelist
        } value: {
            Text(verbatim: model.whitelistSummary)
        }
        .contextMenu {
            Toggle("Auto whitelist", isOn: Binding(
                get: { model.whitelist?.enabled ?? false },
                set: { model.setWhitelistEnabled($0) }
            ))
            .disabled(model.whitelist == nil)
        }
    }
}

private struct TrafficRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let summary = model.connectionSummary
        Row {
            Text("Traffic").frame(maxWidth: .infinity, alignment: .leading)
            RateLabel(symbol: "arrow.down", tint: .accentColor, text: Format.bytes(summary.download), label: "Download")
            RateLabel(symbol: "arrow.up", tint: .ink2, text: Format.bytes(summary.upload), label: "Upload")
        }
    }
}

private struct ConnectionsRow: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        LinkRow(Text("Connections")) {
            navigation.page = .activity
        } value: {
            Text(verbatim: model.isRunning ? "\(model.connectionSummary.count)" : "—")
        }
    }
}

private struct MemoryRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ValueRow(Text("Memory")) {
            Text(verbatim: model.isRunning && model.memory > 0 ? Format.bytes(model.memory) : "—")
        }
    }
}

private struct IntranetIpRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ValueRow(Text("Intranet IP")) {
            Text(verbatim: model.intranetIp?.ip ?? "—").textSelection(.enabled)
            if let interface = model.intranetIp?.interface {
                Text(verbatim: interface)
            }
        }
    }
}

private struct SubscriptionRow: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    private var current: Profile? { model.profiles.first(where: \.selected) }

    var body: some View {
        LinkRow(current.map { Text(verbatim: $0.title) } ?? Text("Add Subscription…")) {
            navigation.page = .profiles
        } value: {
            if let profile = current {
                Text(verbatim: Format.usage(profile.usage) ?? "—")
            }
        }
        .contextMenu {
            if let profile = current, profile.url != nil {
                Button("Update") { model.updateProfile(profile.id) }
                    .disabled(model.updating.contains(profile.id))
            }
            if model.profiles.count > 1 {
                Section("Profiles") {
                    ForEach(model.profiles, id: \.id) { other in
                        Button(other.title) { model.selectProfile(other.id) }
                            .disabled(model.busy || other.selected)
                    }
                }
            }
        }
    }
}

private struct ExitIpRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ValueRow(Text("Exit IP")) {
            Text(verbatim: model.exitIp?.ip ?? "—").textSelection(.enabled)
            if let country = model.exitIp?.country {
                Text(verbatim: country)
            }
            if let quality {
                ViewThatFits(in: .horizontal) {
                    Text(verbatim: "\(quality.kind.title) · \(quality.level.title)")
                        .foregroundStyle(quality.level.tint)
                    EmptyView()
                }
            }
        }
        .help(network ?? "")
    }

    private var quality: IpQuality? {
        model.ipQuality.flatMap { $0.ip == model.exitIp?.ip ? $0 : nil }
    }

    /// FlClash names the network by its organisation, or by its AS number when no source knows the name.
    private var network: String? {
        quality?.organization ?? quality?.asn.map { "AS\($0)" }
    }
}

extension IpType {
    var title: String {
        switch self {
        case .residential: return String(localized: "Residential")
        case .mobile: return String(localized: "Mobile network")
        case .business: return String(localized: "Business")
        case .hosting: return String(localized: "Data center")
        }
    }
}

extension IpQualityLevel {
    var title: String {
        switch self {
        case .good: return String(localized: "Good")
        case .normal: return String(localized: "Normal")
        case .risky: return String(localized: "Risky")
        }
    }

    var tint: Color {
        switch self {
        case .good: return .accentColor
        case .normal: return .ink2
        case .risky: return .bad
        }
    }
}
