import AppKit
import Po0FFI
import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = model.launchError {
                Label {
                    Text(error).textSelection(.enabled)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            } else {
                ConnectionCard()
                ControlsGrid()
                if model.status?.mode != .direct, !model.groups.isEmpty {
                    GroupsSection()
                }
                WhitelistSummary()
            }
            if let notice = model.notice {
                NoticeBanner(text: notice) { model.notice = nil }
            }
            Divider()
            HStack {
                Button {
                    SettingsWindow.shared.show()
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                }
                .keyboardShortcut(",")
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q")
            }
            .glassButton()
        }
        .padding(14)
        .frame(width: 340)
        .onAppear { model.menuAppeared() }
        .onDisappear { model.menuDisappeared() }
    }
}

private struct ConnectionCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "po0-clash").font(.headline)
                    Text(stateTitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Connect", isOn: Binding(get: { model.isOn }, set: { model.setConnected($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(model.busy || model.status == nil)
            }
            if case .failed(let message)? = model.status?.engine {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(4)
                    .textSelection(.enabled)
                Button("Reconnect") { model.reconnect() }
                    .glassButton(prominent: true)
                    .disabled(model.busy)
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                if model.isRunning {
                    InfoRow(title: "Node", value: model.status?.currentNode ?? "—")
                }
                InfoRow(title: "Exit IP", value: exitIpText)
                if model.isRunning {
                    GridRow {
                        Text("Speed").foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Label(Format.rate(model.traffic?.up ?? 0), systemImage: "arrow.up")
                            Label(Format.rate(model.traffic?.down ?? 0), systemImage: "arrow.down")
                        }
                        .monospacedDigit()
                    }
                }
            }
            .font(.callout)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var stateTitle: String {
        switch model.status?.engine {
        case .running?:
            return model.status?.routeMode == .tun
                ? String(localized: "Connected · TUN") : String(localized: "Connected · System proxy")
        case .starting?: return String(localized: "Connecting…")
        case .failed?: return String(localized: "Connection failed")
        default: return String(localized: "Not connected")
        }
    }

    private var exitIpText: String {
        guard let exit = model.exitIp else { return "—" }
        return exit.country.map { "\(exit.ip) · \($0)" } ?? exit.ip
    }
}

private struct InfoRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
        }
    }
}

private struct ControlsGrid: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                Text("Mode").foregroundStyle(.secondary)
                Picker("Mode", selection: Binding(get: { model.status?.mode ?? .rule }, set: { model.setMode($0) })) {
                    Text("Rule").tag(Mode.rule)
                    Text("Global").tag(Mode.global)
                    Text("Direct").tag(Mode.direct)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            GridRow {
                Text("Route").foregroundStyle(.secondary)
                Picker("Route", selection: Binding(
                    get: { model.status?.routeMode ?? .systemProxy },
                    set: { model.setRouteMode($0) }
                )) {
                    Text("System proxy").tag(RouteMode.systemProxy)
                    Text("TUN").tag(RouteMode.tun)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            GridRow {
                Text("Subscription").foregroundStyle(.secondary)
                if model.profiles.isEmpty {
                    Button("Add in Settings…") { SettingsWindow.shared.show(.subscriptions) }
                        .buttonStyle(.link)
                } else {
                    Picker("Subscription", selection: Binding<String?>(
                        get: { model.profiles.first(where: \.selected)?.id },
                        set: { if let id = $0 { model.selectProfile(id) } }
                    )) {
                        ForEach(model.profiles, id: \.id) { profile in
                            Text(profile.title).tag(Optional(profile.id))
                        }
                    }
                    .labelsHidden()
                }
            }
        }
        .disabled(model.busy || model.status == nil)
    }
}

private struct GroupsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Proxies").font(.caption).foregroundStyle(.secondary)
            if model.groups.count > 6 {
                ScrollView {
                    rows
                }
                .frame(height: 210)
            } else {
                rows
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 4) {
            ForEach(model.groups, id: \.name) { group in
                GroupRow(group: group)
            }
        }
    }
}

private struct GroupRow: View {
    @EnvironmentObject private var model: AppModel
    let group: ProxyGroup

    var body: some View {
        HStack(spacing: 8) {
            Text(group.name)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
            if group.selectable {
                Picker(group.name, selection: Binding(
                    get: { group.now ?? "" },
                    set: { model.selectNode(group: group.name, node: $0) }
                )) {
                    ForEach(group.nodes, id: \.name) { node in
                        Text(Format.delay(node).map { "\(node.name)   \($0)" } ?? node.name).tag(node.name)
                    }
                }
                .labelsHidden()
            } else {
                Text(group.now ?? "—")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                model.testDelay(group.name)
            } label: {
                if model.testing.contains(group.name) {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "speedometer")
                }
            }
            .buttonStyle(.borderless)
            .frame(width: 20)
            .help("Test delay")
        }
    }
}

private struct WhitelistSummary: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                SettingsWindow.shared.show(.whitelist)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Auto whitelist")
                        Text(summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Toggle("Auto whitelist", isOn: Binding(
                get: { model.whitelist?.enabled ?? false },
                set: { model.setWhitelistEnabled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .disabled(model.whitelist == nil)
        }
    }

    private var summary: String {
        let entries = model.whitelist?.entries ?? []
        if entries.isEmpty { return String(localized: "No tokens or links yet") }
        let applied = entries.filter { $0.result?.outcome == .applied }.count
        return String(localized: "\(applied) of \(entries.count) whitelisted")
    }
}

struct NoticeBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text(text).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
