import AppKit
import Po0FFI
import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = model.launchError {
                Label {
                    Text(error).textSelection(.enabled)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                }
                .groupedSection()
            } else {
                ConnectionCard().groupedSection()
                ControlsGrid().groupedSection()
                if model.status?.mode != .direct, !model.groups.isEmpty {
                    GroupsSection()
                }
                WhitelistSummary().groupedSection()
            }
            if let notice = model.notice {
                NoticeBanner(text: notice) { model.notice = nil }.groupedSection()
            }
            MenuActions()
        }
        .padding(12)
        .frame(width: 340)
        .onAppear { model.setVisible(.menu, true) }
        .onDisappear { model.setVisible(.menu, false) }
        .background(WindowVisibility { model.setVisible(.menu, $0) })
    }
}

/// macOS 13 and 14 do not call onAppear/onDisappear every time the MenuBarExtra panel opens and closes, and a closed
/// main window keeps its views; the hosting window's occlusion state always changes.
struct WindowVisibility: NSViewRepresentable {
    let onChange: @MainActor (Bool) -> Void

    func makeNSView(context: Context) -> Probe {
        Probe(onChange: onChange)
    }

    func updateNSView(_ probe: Probe, context: Context) {
        probe.onChange = onChange
    }

    final class Probe: NSView {
        var onChange: @MainActor (Bool) -> Void
        private var observer: NSObjectProtocol?

        init(onChange: @escaping @MainActor (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.report() }
            }
            report()
        }

        private func report() {
            guard let window else { return }
            onChange(window.occlusionState.contains(.visible))
        }
    }
}

private struct ConnectionCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "po0-clash").font(.headline)
                    Text(model.stateTitle).font(.subheadline).foregroundStyle(.secondary)
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
                InfoRow(title: "Exit IP", value: model.exitIpText)
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
                    Button("Add Subscription…") { MainWindow.shared.show(.profiles) }
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
            Text("Proxies").font(.subheadline).foregroundStyle(.secondary).padding(.leading, 4)
            Group {
                if model.groups.count > 6 {
                    ScrollView {
                        rows
                    }
                    .frame(height: 210)
                } else {
                    rows
                }
            }
            .groupedSection()
        }
    }

    private var rows: some View {
        VStack(spacing: 6) {
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
                MainWindow.shared.show(.whitelist)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Auto whitelist")
                        Text(model.whitelistSummary).font(.caption).foregroundStyle(.secondary)
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
}

/// FlClash's tray menu items, drawn as menu rows so the panel ends the way a native menu does.
private struct MenuActions: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            MenuRow("Open po0-clash", shortcut: "⌘O") { MainWindow.shared.show() }
                .keyboardShortcut("o")
            if model.isOn {
                MenuRow("Restart Engine") { model.reconnect() }
                    .disabled(model.busy)
            }
            MenuRow("Show Speed in Menu Bar", checked: model.showsMenuBarSpeed) {
                let shows = model.showsMenuBarSpeed
                model.updateAppSettings { $0.traySpeed = !shows }
            }
            .disabled(model.appSettings == nil)
            MenuRow("Launch at Login", checked: launchAtLogin, action: toggleLaunchAtLogin)
            MenuRow(copied ? "Copied" : "Copy Terminal Proxy Command", action: copyProxyCommand)
                .disabled(model.proxyCommand == nil)
            Divider().padding(.vertical, 4)
            MenuRow("Quit po0-clash", shortcut: "⌘Q") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }

    private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLogin.set(!launchAtLogin)
        } catch {
            model.notice = describe(error)
        }
        launchAtLogin = LaunchAtLogin.isEnabled
        if LaunchAtLogin.needsApproval { LaunchAtLogin.openSystemSettings() }
    }

    private func copyProxyCommand() {
        guard let command = model.proxyCommand else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }
}

private struct MenuRow: View {
    let title: LocalizedStringKey
    var checked = false
    var shortcut: String?
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    init(_ title: LocalizedStringKey, checked: Bool = false, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.checked = checked
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 16)
                    .opacity(checked ? 1 : 0)
                Text(title)
                Spacer(minLength: 12)
                if let shortcut {
                    Text(verbatim: shortcut).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering && isEnabled ? Color.primary.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct NoticeBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text(text).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
    }
}
