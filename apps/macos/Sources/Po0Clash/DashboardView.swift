import Charts
import Po0FFI
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 230), spacing: 12, alignment: .top)]

    var body: some View {
        PageScaffold("Dashboard", subtitle: model.stateTitle) {
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
                        .background(Color.sectionFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if case .failed(let message)? = model.status?.engine {
                        FailureCard(message: message)
                    }
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        Group {
                            SpeedCard()
                            TrafficCard()
                            ExitIpCard()
                            CurrentNodeCard()
                            ModeCard()
                            RouteCard()
                            SubscriptionCard()
                            ConnectionsCard()
                            MemoryCard()
                            WhitelistCard()
                        }
                        .frame(minHeight: 124)
                    }
                }
                .padding(20)
                .padding(.bottom, 64)
            }
            .overlay(alignment: .bottomTrailing) {
                ConnectButton().padding(20)
            }
        }
        .background(WindowVisibility { model.setVisible(.dashboard, $0) })
        .onDisappear { model.setVisible(.dashboard, false) }
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
        .background(Color.sectionFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// FlClash's start button: a floating pill that shows how long the connection has been up.
private struct ConnectButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.setConnected(!model.isOn)
        } label: {
            HStack(spacing: 8) {
                if model.busy || (model.isOn && !model.isRunning) {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: model.isOn ? "stop.fill" : "play.fill")
                }
                if let since = model.connectedAt {
                    TimelineView(.periodic(from: since, by: 1)) { context in
                        Text(Format.elapsed(since, now: context.date)).monospacedDigit()
                    }
                } else {
                    Text(model.isOn ? LocalizedStringKey("Connecting…") : LocalizedStringKey("Connect"))
                }
            }
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .glassButton(prominent: !model.isOn)
        .controlSize(.large)
        .buttonBorderShapeCapsule()
        .disabled(model.busy || model.status == nil)
        .help(model.isOn ? LocalizedStringKey("Disconnect") : LocalizedStringKey("Connect"))
        .keyboardShortcut(.return, modifiers: .command)
    }
}

private struct SpeedCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Speed", symbol: "speedometer") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    rate(model.traffic?.up, symbol: "arrow.up")
                    rate(model.traffic?.down, symbol: "arrow.down")
                }
                SpeedChart(history: model.trafficHistory)
            }
        }
    }

    private func rate(_ value: UInt64?, symbol: String) -> some View {
        Label {
            Text(model.isRunning ? Format.rate(value ?? 0) : "—").monospacedDigit()
        } icon: {
            Image(systemName: symbol).foregroundStyle(.secondary)
        }
        .font(.headline)
    }
}

/// The last minute of download (accent) and upload (secondary), newest on the right.
private struct SpeedChart: View {
    let history: [Traffic]

    var body: some View {
        let offset = SpeedChart.span - history.count
        Chart {
            ForEach(Array(history.enumerated()), id: \.offset) { index, sample in
                LineMark(x: .value("Time", offset + index), y: .value("Speed", Double(sample.down)), series: .value("Direction", "down"))
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Time", offset + index), y: .value("Speed", Double(sample.up)), series: .value("Direction", "up"))
                    .foregroundStyle(.secondary)
                    .interpolationMethod(.monotone)
            }
        }
        .chartXScale(domain: 0...SpeedChart.span)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 40)
    }

    private static let span = 60
}

private struct TrafficCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Traffic", symbol: "arrow.up.arrow.down") {
            VStack(alignment: .leading, spacing: 4) {
                total(model.connectionSummary.upload, symbol: "arrow.up")
                total(model.connectionSummary.download, symbol: "arrow.down")
            }
        }
    }

    private func total(_ value: UInt64, symbol: String) -> some View {
        Label {
            Text(model.isRunning ? Format.bytes(value) : "—").monospacedDigit()
        } icon: {
            Image(systemName: symbol).foregroundStyle(.secondary)
        }
        .font(.title3.weight(.medium))
    }
}

private struct ConnectionsCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        Card("Connections", symbol: "point.3.connected.trianglepath.dotted") {
            Button {
                navigation.page = .activity
            } label: {
                HStack {
                    Text(model.isRunning ? "\(model.connectionSummary.count)" : "—")
                        .font(.title3.weight(.medium).monospacedDigit())
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct MemoryCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Memory", symbol: "memorychip") {
            Text(model.isRunning && model.memory > 0 ? Format.bytes(model.memory) : "—")
                .font(.title3.weight(.medium).monospacedDigit())
        }
    }
}

private struct ExitIpCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Exit IP", symbol: "network") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.exitIp?.ip ?? "—")
                        .font(.title3.weight(.medium).monospacedDigit())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    if let country = model.exitIp?.country {
                        Text(country).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    model.refreshExitIpNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
        }
    }
}

private struct CurrentNodeCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        Card("Current node", symbol: "point.3.connected.trianglepath.dotted") {
            Button {
                navigation.page = .proxies
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.isRunning ? model.status?.currentNode ?? "—" : "—")
                            .font(.title3.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let delay = currentDelay {
                            Text(delay).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var currentDelay: String? {
        guard let name = model.status?.currentNode else { return nil }
        let node = model.groups.lazy.flatMap(\.nodes).first { $0.name == name && $0.delay != nil }
        return node.flatMap(Format.delay)
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
        }
    }
}

private struct RouteCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Card("Route", symbol: "arrow.left.arrow.right") {
            Picker("Route", selection: Binding(
                get: { model.status?.routeMode ?? .systemProxy },
                set: { model.setRouteMode($0) }
            )) {
                Text("System proxy").tag(RouteMode.systemProxy)
                Text("TUN").tag(RouteMode.tun)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(model.busy || model.status == nil)
        }
    }
}

private struct SubscriptionCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    private var current: Profile? { model.profiles.first(where: \.selected) }

    var body: some View {
        Card("Subscription", symbol: "tray.full") {
            if model.profiles.isEmpty {
                Button("Add Subscription…") { navigation.page = .profiles }
                    .buttonStyle(.link)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Subscription", selection: Binding<String?>(
                        get: { current?.id },
                        set: { if let id = $0 { model.selectProfile(id) } }
                    )) {
                        ForEach(model.profiles, id: \.id) { profile in
                            Text(profile.title).tag(Optional(profile.id))
                        }
                    }
                    .labelsHidden()
                    .disabled(model.busy)
                    if let usage = current?.usage, usage.total > 0 {
                        UsageBar(usage: usage)
                    }
                }
            }
        }
    }
}

private struct WhitelistCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        Card("Auto whitelist", symbol: "checkmark.shield") {
            HStack {
                Button {
                    navigation.page = .whitelist
                } label: {
                    Text(model.whitelistSummary).foregroundStyle(.secondary).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Toggle("Auto whitelist", isOn: Binding(
                    get: { model.whitelist?.enabled ?? false },
                    set: { model.setWhitelistEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(model.whitelist == nil)
            }
        }
    }
}

struct UsageBar: View {
    let usage: Usage

    var body: some View {
        let used = usage.upload + usage.download
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: min(Double(used) / Double(max(usage.total, 1)), 1))
                .progressViewStyle(.linear)
            HStack {
                Text("\(Format.bytes(used)) of \(Format.bytes(usage.total)) used")
                Spacer()
                if let expire = usage.expire {
                    Text("Expires \(Format.date(expire), format: .dateTime.year().month().day())")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
