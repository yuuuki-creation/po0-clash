import AppKit
import Po0FFI
import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = model.launchError {
                RowGroup {
                    Row { ErrorText(message: error) }
                }
            } else {
                ConnectionGroup()
                ControlsGroup()
                if model.status?.mode != .direct, !model.groups.isEmpty {
                    GroupsSection()
                }
                RowGroup { WhitelistSummary() }
            }
            if let notice = model.notice {
                RowGroup {
                    NoticeBanner(text: notice) { model.notice = nil }
                }
            }
            MenuActions()
        }
        .padding(12)
        .frame(width: 340)
        .background(Color.page)
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

private struct ConnectionGroup: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        RowGroup {
            Row {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "po0-clash").font(Ui.boldFont)
                    Text(verbatim: model.stateTitle).foregroundStyle(Color.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SwitchControl(isOn: Binding(get: { model.isOn }, set: { model.setConnected($0) }))
                    .disabled(model.busy || model.status == nil)
                    .accessibilityLabel(Text("Connect"))
            }
            if case .failed(let message)? = model.status?.engine {
                Row {
                    ErrorText(message: message).lineLimit(4)
                    Button("Reconnect") { model.reconnect() }
                        .disabled(model.busy)
                }
            }
            if model.isRunning {
                ValueRow(Text("Node")) {
                    Text(verbatim: model.status?.currentNode ?? "—").textSelection(.enabled)
                }
            }
            ValueRow(Text("Exit IP")) {
                Text(verbatim: model.exitIpText).textSelection(.enabled)
            }
            if model.isRunning {
                ValueRow(Text("Speed")) {
                    Text(verbatim: "↑ \(Format.rate(model.traffic?.up ?? 0))  ↓ \(Format.rate(model.traffic?.down ?? 0))")
                }
            }
        }
    }
}

private struct ControlsGroup: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        RowGroup {
            ControlRow(Text("Mode")) {
                SegmentedControl(
                    selection: Binding(get: { model.status?.mode ?? .rule }, set: { model.setMode($0) }),
                    segments: Mode.segments
                )
            }
            ControlRow(Text("Route")) {
                SegmentedControl(
                    selection: Binding(get: { model.status?.routeMode ?? .systemProxy }, set: { model.setRouteMode($0) }),
                    segments: [Segment(RouteMode.systemProxy, "System proxy"), Segment(RouteMode.tun, "TUN")]
                )
            }
            if model.profiles.isEmpty {
                Row {
                    Text("Subscription").frame(maxWidth: .infinity, alignment: .leading)
                    Button("Add Subscription…") { MainWindow.shared.show(.profiles) }
                }
            } else {
                OptionRow(
                    "Subscription",
                    selection: Binding<String?>(
                        get: { model.profiles.first(where: \.selected)?.id },
                        set: { if let id = $0 { model.selectProfile(id) } }
                    ),
                    options: model.profiles.map { Option<String?>($0.id, $0.title) }
                )
            }
        }
        .disabled(model.busy || model.status == nil)
    }
}

private struct GroupsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Proxies").font(Ui.boldFont)
            RowGroup {
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
    }

    private var rows: some View {
        VStack(spacing: 0) {
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
        Row {
            Text(verbatim: group.name)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
            if group.selectable {
                OptionMenu(
                    selection: Binding(
                        get: { group.now ?? "" },
                        set: { model.selectNode(group: group.name, node: $0) }
                    ),
                    options: group.nodes.map { node in
                        Option(node.name, Format.delay(node).map { "\(node.name)   \($0)" } ?? node.name)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(verbatim: group.now ?? "—")
                    .foregroundStyle(Color.ink2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            IconButton(symbol: "speedometer", help: "Test delay", busy: model.testingGroups.contains(group.name)) {
                model.testDelay(group.name)
            }
        }
    }
}

private struct WhitelistSummary: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Row {
            Button {
                MainWindow.shared.show(.whitelist)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield").foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Auto whitelist")
                        Text(verbatim: model.whitelistSummary).foregroundStyle(Color.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            SwitchControl(isOn: Binding(
                get: { model.whitelist?.enabled ?? false },
                set: { model.setWhitelistEnabled($0) }
            ))
            .disabled(model.whitelist == nil)
            .accessibilityLabel(Text("Auto whitelist"))
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
            Rectangle().fill(Color.line).frame(height: 1).padding(.vertical, 4)
            MenuRow("Quit po0-clash", shortcut: "⌘Q") { quitApp() }
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
    @Environment(\.onAccent) private var onAccent
    @State private var hovering = false

    init(_ title: LocalizedStringKey, checked: Bool = false, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.checked = checked
        self.shortcut = shortcut
        self.action = action
    }

    private var highlighted: Bool { hovering && isEnabled }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
                    .opacity(checked ? 1 : 0)
                Text(title)
                Spacer(minLength: 12)
                if let shortcut {
                    Text(verbatim: shortcut)
                        .foregroundStyle(highlighted ? onAccent : Color.ink2)
                }
            }
            .padding(.horizontal, 6)
            .frame(minHeight: 26)
            .foregroundStyle(highlighted ? onAccent : Color.ink)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(highlighted ? Color.accentColor : Color.clear)
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
        Row {
            Text(verbatim: text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            IconButton(symbol: "xmark", help: "Dismiss", action: dismiss)
        }
    }
}
