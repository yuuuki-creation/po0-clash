import AppKit
import Po0FFI
import WebKit

/// An AppKit-owned window so a login launch can stay in the menu bar and the Dock icon only shows while it is open.
/// Its content is the web interface shared with the Windows app, served from the bundle by `WebAssets`.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    static let shared = MainWindow()

    private(set) var window: NSWindow?
    private var webView: PageView?
    private let assets = WebAssets()
    private let bridge = Bridge()
    private var loaded = false
    private var pendingPage: String?
    private var lastMouseDown: NSEvent?
    private var mouseMonitor: Any?

    private static let minimumSize = NSSize(width: 900, height: 600)
    private static let logHandler = "po0log"
    private static let errorReporter = """
        (() => {
          const send = (text) => window.webkit.messageHandlers.\(logHandler).postMessage(String(text));
          window.addEventListener('error', (e) => send(`${e.message} ${e.filename || ''}:${e.lineno || 0}`));
          window.addEventListener('unhandledrejection', (e) => send(`unhandled: ${(e.reason && e.reason.message) || e.reason}`));
        })();
        """

    func show(page: String? = nil) {
        if window == nil { build() }
        if let page { navigate(to: page) }
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

    /// Calls the page's listeners the way Tauri's `emit` does on Windows; `payload` is anything JSON can hold.
    func emit(_ event: String, _ payload: Any) {
        guard loaded, let webView, let name = try? Wire.text(event), let body = try? Wire.text(payload) else { return }
        webView.evaluateJavaScript("window.__po0Emit && window.__po0Emit(\(name), \(body)); undefined", completionHandler: nil)
    }

    private func navigate(to page: String) {
        if loaded {
            emit("navigate", page)
        } else {
            pendingPage = page
        }
    }

    func drag() {
        guard let window, NSEvent.pressedMouseButtons & 1 != 0 else { return }
        let current = NSApp.currentEvent
        guard let event = current?.type == .leftMouseDown ? current : lastMouseDown else { return }
        window.performDrag(with: event)
    }

    /// What a double click on a title bar does, as chosen in System Settings.
    func zoom() {
        guard let window else { return }
        switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
        case "Minimize": window.miniaturize(nil)
        case "None": break
        default: window.zoom(nil)
        }
    }

    func setBackground(red: Int, green: Int, blue: Int) {
        let color = NSColor(
            srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1
        )
        window?.backgroundColor = color
        webView?.underPageBackgroundColor = color
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
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(assets, forURLScheme: WebAssets.scheme)
        let scripts = configuration.userContentController
        scripts.addScriptMessageHandler(bridge, contentWorld: .page, name: Bridge.name)
        scripts.add(self, name: Self.logHandler)
        scripts.addUserScript(
            WKUserScript(source: Self.errorReporter, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )

        let frame = NSRect(x: 0, y: 0, width: 1180, height: 760)
        let webView = PageView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // The window's colour shows until the page paints, instead of WebKit's white.
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 13.3, *) {
            webView.isInspectable = AppModel.shared.appSettings?.developerMode == true
        }

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "po0-clash"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentMinSize = Self.minimumSize
        window.contentView = webView
        window.center()
        window.setFrameAutosaveName("main")
        // A frame saved by an earlier version can be smaller than this interface allows.
        let size = window.contentRect(forFrameRect: window.frame).size
        if size.width < Self.minimumSize.width || size.height < Self.minimumSize.height {
            window.setContentSize(
                NSSize(width: max(size.width, Self.minimumSize.width), height: max(size.height, Self.minimumSize.height))
            )
        }
        window.delegate = self
        self.window = window
        self.webView = webView
        let page = Self.pageColor(AppModel.shared.appSettings, dark: window.effectiveAppearance.isDark)
        setBackground(red: page, green: page, blue: page)

        // `window_drag` arrives after the click that asked for it has stopped being the current event.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if let self, event.window === self.window { self.lastMouseDown = event }
            return event
        }
        webView.load(URLRequest(url: WebAssets.index))
    }

    private static func pageColor(_ settings: AppSettings?, dark: Bool) -> Int {
        guard dark else { return 0xF3 }
        return settings?.pureBlack == true ? 0x00 : 0x20
    }

    // MARK: WebKit

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let url = navigationAction.request.url
        let mainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        if url?.scheme == WebAssets.scheme || !mainFrame {
            decisionHandler(.allow)
            return
        }
        if let url, navigationAction.navigationType == .linkActivated { Self.openInBrowser(url) }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.notice("web interface loaded")
        loaded = true
        if let page = pendingPage { emit("navigate", page) }
        pendingPage = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("web interface failed to load: \(error.localizedDescription, privacy: .public)")
    }

    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
    ) {
        logger.error("web interface failed to load: \(error.localizedDescription, privacy: .public)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        logger.error("web content process ended; reloading")
        loaded = false
        webView.load(URLRequest(url: WebAssets.index))
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url { Self.openInBrowser(url) }
        return nil
    }

    /// WebKit on macOS shows no file chooser for `<input type="file">` unless its UI delegate does.
    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        guard let window else { return completionHandler(nil) }
        panel.beginSheetModal(for: window) { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let text = message.body as? String else { return }
        logger.error("web error: \(text, privacy: .public)")
    }

    private static func openInBrowser(_ url: URL) {
        guard url.scheme == "http" || url.scheme == "https" else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

final class PageView: WKWebView {
    private static let hiddenItems: Set<String> = [
        "WKMenuItemIdentifierReload", "WKMenuItemIdentifierGoBack", "WKMenuItemIdentifierGoForward",
        "WKMenuItemIdentifierOpenLinkInNewWindow", "WKMenuItemIdentifierDownloadLinkedFile",
        "WKMenuItemIdentifierOpenImageInNewWindow", "WKMenuItemIdentifierDownloadImage",
    ]

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        for item in menu.items where Self.hiddenItems.contains(item.identifier?.rawValue ?? "") {
            menu.removeItem(item)
        }
    }

    /// An accessory app's main menu is not sure to carry Edit, and without it WebKit gets no copy or paste keys.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags.contains(.command), flags.isSubset(of: [.command, .shift]) else { return false }
        let action: Selector
        switch (event.charactersIgnoringModifiers?.lowercased() ?? "", flags.contains(.shift)) {
        case ("c", false): action = #selector(NSText.copy(_:))
        case ("v", false): action = #selector(NSText.paste(_:))
        case ("x", false): action = #selector(NSText.cut(_:))
        case ("a", false): action = #selector(NSResponder.selectAll(_:))
        case ("z", false): action = Selector(("undo:"))
        case ("z", true): action = Selector(("redo:"))
        default: return false
        }
        return NSApp.sendAction(action, to: nil, from: self)
    }
}

/// Serves `Contents/Resources/web` (the build of `apps/windows`) as `po0://app/…`; a path that is no file gets
/// index.html, so the page's own routes survive a reload.
final class WebAssets: NSObject, WKURLSchemeHandler {
    static let scheme = "po0"
    static let index = URL(string: "po0://app/index.html")!

    private static let types = [
        "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8",
        "mjs": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
        "json": "application/json; charset=utf-8", "map": "application/json; charset=utf-8",
        "txt": "text/plain; charset=utf-8", "svg": "image/svg+xml", "png": "image/png", "jpg": "image/jpeg",
        "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp", "ico": "image/x-icon",
        "woff": "font/woff", "woff2": "font/woff2", "ttf": "font/ttf", "otf": "font/otf",
        "wasm": "application/wasm",
    ]

    private let root = Bundle.main.resourceURL?.appendingPathComponent("web", isDirectory: true)

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let found = file(for: url.path)
        let data = found.flatMap { try? Data(contentsOf: $0) }
        let type = found.flatMap { Self.types[$0.pathExtension.lowercased()] } ?? "application/octet-stream"
        let headers = [
            "Content-Type": type,
            "Content-Length": String(data?.count ?? 0),
            "Cache-Control": "no-store",
            "Access-Control-Allow-Origin": "*",
        ]
        guard let response = HTTPURLResponse(
            url: url, statusCode: data == nil ? 404 : 200, httpVersion: "HTTP/1.1", headerFields: headers
        ) else {
            urlSchemeTask.didFailWithError(URLError(.badServerResponse))
            return
        }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data ?? Data())
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func file(for path: String) -> URL? {
        guard let root else { return nil }
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.contains("..") else { return nil }
        let candidate = parts.reduce(root) { $0.appendingPathComponent($1) }
        var isDirectory: ObjCBool = false
        if !parts.isEmpty, FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            return candidate
        }
        return parts.last?.contains(".") == true ? nil : root.appendingPathComponent("index.html")
    }
}
