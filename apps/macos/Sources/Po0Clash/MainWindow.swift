import AppKit
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
}

/// An AppKit-owned window so a login launch can stay in the menu bar and the Dock icon only shows while it is open;
/// SwiftUI's `Window` scene cannot be opened or suppressed from the app delegate on macOS 13 and 14.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    static let shared = MainWindow()

    let navigation = Navigation()
    private var window: NSWindow?

    func show(_ page: Page? = nil) {
        if let page { navigation.page = page }
        if window == nil { build() }
        NSApp.setActivationPolicy(.regular)
        activateApp()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func build() {
        let root = MainView()
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
    }
}

struct MainView: View {
    @EnvironmentObject private var navigation: Navigation
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(Page.allCases, selection: Binding<Page?>(
                get: { navigation.page },
                set: { if let page = $0 { navigation.page = page } }
            )) { page in
                Label(page.title, systemImage: page.symbol).tag(page)
            }
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
            .navigationTitle(navigation.page.title)
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
    @EnvironmentObject private var model: AppModel
    let title: LocalizedStringKey
    var subtitle: String?
    private let actions: Actions
    private let content: Content

    init(
        _ title: LocalizedStringKey,
        subtitle: String? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        page
            .alert(
                model.notice ?? "",
                isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })
            ) {
                Button("OK") { model.notice = nil }
            }
    }

    @ViewBuilder
    private var page: some View {
        if #available(macOS 14, *) {
            content
                .background(Color.pageBackground)
                .navigationTitle(title)
                .navigationSubtitle(subtitle ?? "")
                .modifier(PageToolbar(actions: actions))
        } else {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title).font(.title2.weight(.semibold))
                    if let subtitle { Text(subtitle).foregroundStyle(.secondary) }
                    Spacer()
                    ControlBar { actions }
                    ConnectButton()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                content
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
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 4)
        }
        .glassButton(prominent: true)
        .buttonBorderShapeCapsule()
        .disabled(model.busy || model.status == nil)
        .help(model.isOn ? LocalizedStringKey("Disconnect") : LocalizedStringKey("Connect"))
        .keyboardShortcut(.return, modifiers: .command)
    }
}

extension PageScaffold where Actions == EmptyView {
    init(_ title: LocalizedStringKey, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, subtitle: subtitle, actions: { EmptyView() }, content: content)
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
