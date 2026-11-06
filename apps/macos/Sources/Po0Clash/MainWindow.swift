import AppKit
import Combine
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case dashboard, proxies, profiles, whitelist, activity, tools

    var id: Self { self }

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
    /// The toolbar button's state: it hides a docked sidebar and shows a collapsed one over the content.
    @Published var sidebarToggled = false
}

/// An AppKit-owned window so a login launch can stay in the menu bar and the Dock icon only shows while it is open;
/// SwiftUI's `Window` scene cannot be opened or suppressed from the app delegate on macOS 13 and 14.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    static let shared = MainWindow()

    let navigation = Navigation()
    let dialogs = DialogCenter()
    private var window: NSWindow?
    private var titleWatch: Any?

    func show(_ page: Page? = nil) {
        if let page { navigation.page = page }
        if window == nil { build() }
        NSApp.setActivationPolicy(.regular)
        activateApp()
        window?.makeKeyAndOrderFront(nil)
        placeTrafficLights()
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

    func windowDidResize(_ notification: Notification) {
        placeTrafficLights()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        placeTrafficLights()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        placeTrafficLights()
    }

    private func build() {
        let root = MainView()
            .modifier(AppTheme())
            .environmentObject(AppModel.shared)
            .environmentObject(navigation)
            .environmentObject(dialogs)
        let host = NSHostingController(rootView: root)
        // The window's limits are set below; SwiftUI's would follow whatever page is showing.
        host.sizingOptions = []
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = .pageBackground
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 620, height: 480)
        window.setContentSize(Showcase.windowSize ?? NSSize(width: 1180, height: 760))
        window.center()
        if Showcase.windowSize == nil { window.setFrameAutosaveName("main") }
        window.delegate = self
        window.title = navigation.page.name
        self.window = window
        titleWatch = navigation.$page.sink { _ in
            Task { @MainActor in MainWindow.shared.keepTitle() }
        }
    }

    private func keepTitle() {
        window?.title = navigation.page.name
        placeTrafficLights()
    }

    /// AppKit centres the traffic lights in its own 28 pt title bar; the design's toolbar row is 48 tall.
    private func placeTrafficLights() {
        guard let window, !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton) else { return }
        let height: CGFloat = 48
        var container: NSView? = close.superview
        while let view = container, String(describing: type(of: view)) != "NSTitlebarContainerView" {
            container = view.superview
        }
        guard let container else { return }
        container.frame = NSRect(x: 0, y: window.frame.height - height, width: window.frame.width, height: height)
        var ancestor = close.superview
        while let view = ancestor, view !== container {
            view.frame = container.bounds
            ancestor = view.superview
        }
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for (index, kind) in buttons.enumerated() {
            guard let button = window.standardWindowButton(kind) else { continue }
            button.setFrameOrigin(NSPoint(x: 18 + CGFloat(index) * 20, y: (height - button.frame.height) / 2))
        }
    }
}

/// Drags the window from a toolbar or sidebar gap: hosted SwiftUI content takes those clicks from the title bar.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }

    func updateNSView(_ view: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            guard event.clickCount == 2 else {
                window?.performDrag(with: event)
                return
            }
            switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
            case "Minimize": window?.performMiniaturize(nil)
            case "None": break
            default: window?.performZoom(nil)
            }
        }
    }
}

private struct Notice: Identifiable {
    let text: String
    var id: String { text }
}

private struct ToolbarInsetKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// No docked sidebar sits under the traffic lights, so the toolbar has to clear them itself.
    var toolbarClearsLights: Bool {
        get { self[ToolbarInsetKey.self] }
        set { self[ToolbarInsetKey.self] = newValue }
    }
}

struct MainView: View {
    @EnvironmentObject private var navigation: Navigation
    @EnvironmentObject private var dialogs: DialogCenter
    @Environment(\.onAccent) private var onAccent

    var body: some View {
        GeometryReader { proxy in
            let narrow = proxy.size.width < 760
            let visible = narrow ? navigation.sidebarToggled : !navigation.sidebarToggled
            let docked = visible && !narrow
            let contentWidth = proxy.size.width - (docked ? Ui.sidebarWidth : 0) - Ui.pageInset * 2
            ZStack(alignment: .topLeading) {
                page
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.leading, docked ? Ui.sidebarWidth : 0)
                    .environment(\.compactContent, contentWidth <= 700)
                    .environment(\.toolbarClearsLights, !docked)
                    .allowsHitTesting(dialogs.stack.isEmpty)
                if narrow && visible {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { navigation.sidebarToggled = false }
                }
                sidebar(narrow: narrow)
                    .shadow(color: narrow && visible ? Color.black.opacity(0.22) : Color.clear, radius: 12, y: 8)
                    .offset(x: visible ? 0 : -Ui.sidebarWidth)
                    .allowsHitTesting(dialogs.stack.isEmpty)
                DialogLayer()
                MainModelBridge()
            }
            .motion(Motion.sidebar, value: visible)
        }
        .ignoresSafeArea()
        .background(Color.page)
        .onChange(of: navigation.page) { page in
            if page != .tools { navigation.tools = [] }
        }
    }

    private var page: some View {
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
        .id(navigation.page)
    }

    /// Choosing a page closes the sidebar only where it covers the content.
    private func sidebar(narrow: Bool) -> some View {
        VStack(spacing: 0) {
            WindowDragArea().frame(height: 48)
            Sidebar(
                page: Binding(
                    get: { navigation.page },
                    set: { page in
                        navigation.page = page
                        if narrow { navigation.sidebarToggled = false }
                    }
                ),
                accent: Color.accentColor,
                onAccent: onAccent,
                enabled: dialogs.stack.isEmpty
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .frame(width: Ui.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(Color.side)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.line).frame(width: 1)
        }
    }
}

private struct MainModelBridge: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var dialogs: DialogCenter

    var body: some View {
        Button {
            model.setConnected(!model.isOn)
        } label: {
            EmptyView()
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(model.busy || model.status == nil || !dialogs.stack.isEmpty)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
        .dialog(item: Binding(
            get: { model.notice.map { Notice(text: $0) } },
            set: { if $0 == nil { model.notice = nil } }
        )) { notice in
            NoticeDialog(text: notice.text)
        }
    }
}

/// A page: the toolbar row, then its content. The hairline under the row shows only once the content has scrolled.
struct PageScaffold<Actions: View, Content: View>: View {
    private let title: LocalizedStringKey
    private let capped: Bool
    private let back: (() -> Void)?
    private let actions: Actions
    private let content: Content
    @EnvironmentObject private var navigation: Navigation
    @Environment(\.toolbarClearsLights) private var clearsLights
    @State private var scrolled = false

    init(
        _ title: LocalizedStringKey,
        capped: Bool = true,
        back: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.capped = capped
        self.back = back
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
                .environment(\.pageScrolled, $scrolled)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            IconButton(symbol: "sidebar.left", help: "Sidebar") { navigation.sidebarToggled.toggle() }
            if let back {
                IconButton(symbol: "chevron.backward", help: "Back", action: back)
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .allowsHitTesting(false)
            Spacer(minLength: 8)
            HStack(spacing: 8) { actions }
        }
        .padding(.leading, clearsLights ? 88 : Ui.pageInset)
        .padding(.trailing, Ui.pageInset)
        .frame(minHeight: 48)
        .frame(maxWidth: capped ? Ui.maxWidth + Ui.pageInset * 2 : .infinity)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.line)
                .frame(height: 1)
                .opacity(scrolled ? 1 : 0)
                .motion(Motion.hairline, value: scrolled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WindowDragArea())
    }
}

extension PageScaffold where Actions == EmptyView {
    init(
        _ title: LocalizedStringKey,
        capped: Bool = true,
        back: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title, capped: capped, back: back, actions: { EmptyView() }, content: content)
    }
}
