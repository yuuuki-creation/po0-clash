import AppKit
import Combine
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case dashboard, proxies, profiles, whitelist, activity, tools

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: return "Dashboard"
        case .proxies: return "Proxies"
        case .profiles: return "Profiles"
        case .whitelist: return "Whitelist"
        case .activity: return "Activity"
        case .tools: return "Tools"
        }
    }

    /// The title for AppKit, which cannot take a `LocalizedStringKey`.
    var name: String {
        NSLocalizedString(rawValue.capitalized, comment: "")
    }

    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .proxies: return "globe"
        case .profiles: return "square.stack.3d.up"
        case .whitelist: return "checkmark.shield"
        case .activity: return "chart.xyaxis.line"
        case .tools: return "wrench.and.screwdriver"
        }
    }
}

final class Navigation: ObservableObject {
    @Published var page: Page = .dashboard
    @Published var tools: [ToolsPage] = []
}

/// An AppKit-owned window so a login launch can stay in the menu bar and the Dock icon only shows while it is open;
/// SwiftUI's `Window` scene cannot be opened or suppressed from the app delegate on macOS 13 and 14.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    static let shared = MainWindow()

    let navigation = Navigation()
    private var window: NSWindow?
    private var titleWatches: [Any] = []

    func show(_ page: Page? = nil) {
        if let page { navigation.page = page }
        if window == nil { build() }
        NSApp.setActivationPolicy(.regular)
        activateApp()
        window?.makeKeyAndOrderFront(nil)
    }

    func toggle() {
        if let window, window.isVisible, NSApp.isActive {
            window.close()
        } else {
            show()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard AppModel.shared.appSettings?.minimizeOnClose == false else { return true }
        NSApp.terminate(nil)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func build() {
        let root = MainView()
            .modifier(AppTheme())
            .environmentObject(AppModel.shared)
            .environmentObject(navigation)
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        if #unavailable(macOS 14) {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 760, height: 520)
        window.setContentSize(NSSize(width: 1180, height: 760))
        window.center()
        window.setFrameAutosaveName("main")
        window.delegate = self
        self.window = window
        titleWatches = [
            window.observe(\.title) { _, _ in Task { @MainActor in MainWindow.shared.keepTitle() } },
            navigation.$page.sink { _ in Task { @MainActor in MainWindow.shared.keepTitle() } },
        ]
    }

    /// SwiftUI leaves the proxies list "Untitled" while that page's subtitle still bridges, so AppKit puts it back.
    private func keepTitle() {
        guard let window, navigation.page != .tools else { return }
        if window.title != navigation.page.name { window.title = navigation.page.name }
    }
}

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            Sidebar(page: $navigation.page, accent: Theme.nsAccent(model.themeColor))
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
                // The window title bridges from the sidebar column; the detail's own title alone left it "Untitled".
                .navigationTitle(navigation.page.title)
        } detail: {
            Group {
                switch navigation.page {
                case .dashboard: DashboardView()
                case .proxies: ProxiesView()
                case .profiles: SubscriptionsView()
                case .whitelist: WhitelistView()
                case .activity: ActivityView()
                case .tools: ToolsView()
                }
            }
            .modifier(PageEntrance(enabled: model.appSettings?.pageAnimation ?? true))
            .id(navigation.page)
            .navigationTitle(navigation.page.title)
        }
        .navigationTitle(navigation.page.title)
        .alert(
            model.notice ?? "",
            isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })
        ) {
            Button("OK") { model.notice = nil }
        }
        // macOS 13 gets no toolbar, so nothing could bring a collapsed sidebar back.
        .onChange(of: columns) { visibility in
            if #unavailable(macOS 14) {
                if visibility != .all { columns = .all }
            }
        }
    }
}

/// macOS 13's hosting controller cannot bridge a toolbar into the window, so it gets the toolbar items as a header row.
struct PageScaffold<Actions: View, Content: View>: View {
    let title: LocalizedStringKey
    var subtitle: String?
    var back: (() -> Void)?
    private let actions: Actions
    private let content: Content

    init(
        _ title: LocalizedStringKey,
        subtitle: String? = nil,
        back: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.back = back
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        if #available(macOS 14, *) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.pageBackground)
                .navigationTitle(title)
                .navigationSubtitle(subtitle ?? "")
                .navigationBarBackButtonHidden(back != nil)
                .toolbar {
                    if let back {
                        ToolbarItem(placement: .navigation) {
                            Button(action: back) {
                                Label("Back", systemImage: "chevron.backward")
                            }
                            .help("Back")
                        }
                    }
                }
                .modifier(PageToolbar(actions: actions))
        } else {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let back {
                        Button(action: back) {
                            Image(systemName: "chevron.backward")
                        }
                        .buttonStyle(.borderless)
                        .help("Back")
                    }
                    Text(title).font(.title2.weight(.semibold))
                    if let subtitle { Text(subtitle).foregroundStyle(.secondary) }
                    Spacer()
                    ControlBar { actions }
                    ConnectButton()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.pageBackground)
        }
    }
}

/// The page's own actions share one glass group; the connect button, on every page, gets its own after a gap.
private struct PageToolbar<Actions: View>: ViewModifier {
    let actions: Actions

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            content.toolbar {
                ToolbarItemGroup(placement: .primaryAction) { actions }
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { ConnectButton() }
            }
        } else {
            content.toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    actions
                    ConnectButton()
                }
            }
        }
        #else
        content.toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                actions
                ConnectButton()
            }
        }
        #endif
    }
}

/// FlClash's start button, moved into the toolbar so it never covers content: the elapsed time while connected.
struct ConnectButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.setConnected(!model.isOn)
        } label: {
            HStack(spacing: 6) {
                if model.busy || (model.isOn && !model.isRunning) {
                    ProgressView().controlSize(.small)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    Image(systemName: model.isOn ? "stop.fill" : "play.fill")
                        .replacingSymbol()
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                if let since = model.connectedAt {
                    TimelineView(.periodic(from: since, by: 1)) { context in
                        Text(Format.elapsed(since, now: context.date))
                            .monospacedDigit()
                            .rollingDigits()
                            .motion(Motion.quick, value: context.date)
                    }
                    .transition(.opacity)
                } else {
                    Text(model.isOn ? LocalizedStringKey("Connecting…") : LocalizedStringKey("Connect"))
                        .transition(.opacity)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 4)
            .motion(value: ConnectPhase(model))
        }
        .glassButton(prominent: true)
        .buttonBorderShapeCapsule()
        .disabled(model.busy || model.status == nil)
        .help(model.isOn ? LocalizedStringKey("Disconnect") : LocalizedStringKey("Connect"))
        .keyboardShortcut(.return, modifiers: .command)
        .contextMenu {
            Button("Restart Engine") { model.reconnect() }
                .disabled(!model.isOn || model.busy)
        }
    }
}

/// What the connect button shows; its glass capsule reshapes with a spring whenever this changes.
private struct ConnectPhase: Equatable {
    let busy: Bool
    let on: Bool
    let connected: Bool

    @MainActor init(_ model: AppModel) {
        busy = model.busy || (model.isOn && !model.isRunning)
        on = model.isOn
        connected = model.connectedAt != nil
    }
}

extension PageScaffold where Actions == EmptyView {
    init(
        _ title: LocalizedStringKey,
        subtitle: String? = nil,
        back: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title, subtitle: subtitle, back: back, actions: { EmptyView() }, content: content)
    }
}

struct EmptyState: View {
    let title: LocalizedStringKey
    let symbol: String
    let detail: LocalizedStringKey

    var body: some View {
        if #available(macOS 14, *) {
            ContentUnavailableView {
                Label(title, systemImage: symbol)
            } description: {
                Text(detail)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.largeTitle).foregroundStyle(.secondary)
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
