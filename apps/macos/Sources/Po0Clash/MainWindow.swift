import AppKit
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case dashboard, proxies, subscriptions, whitelist, settings

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: return "Dashboard"
        case .proxies: return "Proxies"
        case .subscriptions: return "Subscriptions"
        case .whitelist: return "Whitelist"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .proxies: return "globe"
        case .subscriptions: return "tray.full"
        case .whitelist: return "checkmark.shield"
        case .settings: return "gearshape"
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
        let host = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "po0-clash"
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 760, height: 520)
        window.setContentSize(NSSize(width: 940, height: 640))
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
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch navigation.page {
            case .dashboard: DashboardView()
            case .proxies: ProxiesView()
            case .subscriptions: SubscriptionsView()
            case .whitelist: WhitelistView()
            case .settings: SettingsView()
            }
        }
        // The window has no toolbar to bring a collapsed sidebar back, so it never stays collapsed.
        .onChange(of: columns) { visibility in
            if visibility != .all { columns = .all }
        }
    }
}

/// One page of the main window: a large title with its floating actions, then opaque grouped content.
struct PageScaffold<Actions: View, Content: View>: View {
    @EnvironmentObject private var model: AppModel
    let title: LocalizedStringKey
    private let actions: Actions
    private let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder actions: () -> Actions, @ViewBuilder content: () -> Content) {
        self.title = title
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    Text(title).font(.largeTitle.weight(.bold))
                    Spacer()
                    ControlBar { actions }
                }
                if let error = model.launchError {
                    Label {
                        Text(error).textSelection(.enabled)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                    .groupedSection()
                }
                if let notice = model.notice {
                    NoticeBanner(text: notice) { model.notice = nil }.groupedSection()
                }
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 88)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

extension PageScaffold where Actions == EmptyView {
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(title, actions: { EmptyView() }, content: content)
    }
}

/// A dashboard card in the FlClash layout: a monochrome symbol and caption, then the value.
struct Card<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    private let content: Content

    init(_ title: LocalizedStringKey, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.callout)
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
