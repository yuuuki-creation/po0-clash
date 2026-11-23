import AppKit
import Po0FFI
import SwiftUI

@main
struct Po0ClashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .modifier(AppTheme())
                .environmentObject(model)
        } label: {
            MenuBarLabel(traffic: model.menuTraffic)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminationSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A plain `kill` must still go through shutdown so the system proxy is not left pointing at a dead port.
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { onMainRunLoop { quitApp() } }
        source.resume()
        terminationSignal = source

        let others = NSRunningApplication.runningApplications(withBundleIdentifier: AppPaths.bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty {
            activateApp()
            let alert = NSAlert()
            alert.messageText = String(localized: "po0-clash is already running.")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        let atLogin = LaunchAtLogin.launchedAtLogin
        AppModel.shared.launch(atLogin: atLogin)
        Showcase.run()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppModel.shared.openLinks(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindow.shared.show()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        closeSheets()
        guard AppModel.shared.hasCore else { return .terminateNow }
        AppModel.shared.shutdown { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

/// A quit sent while the override sheet was open never finished in CI, so quitting closes sheets first.
@MainActor
func quitApp() {
    closeSheets()
    NSApp.terminate(nil)
}

@MainActor
private func closeSheets() {
    for window in NSApp.windows {
        if let sheet = window.attachedSheet { window.endSheet(sheet) }
    }
}

/// The Flutter app's menu bar look: the po0 template mark, with the current speed beside it while connected.
private struct MenuBarLabel: View {
    @ObservedObject var traffic: MenuTraffic

    var body: some View {
        Image(nsImage: traffic.icon)
            .accessibilityLabel("po0-clash")
    }
}

@MainActor
enum MenuBarIcon {
    static let mark: NSImage = {
        let image = Bundle.main.image(forResource: "MenuBarIcon") ?? NSImage(systemSymbolName: "p.circle", accessibilityDescription: nil)!
        image.isTemplate = true
        return image
    }()

    private static var cachedRates: [String] = []
    private static var cachedImage: NSImage?

    static func image(speed: Traffic?) -> NSImage {
        guard let speed else { return mark }
        let rates = [Format.shortRate(speed.up), Format.shortRate(speed.down)]
        if rates == cachedRates, let cachedImage { return cachedImage }
        let mark = Self.mark
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        let lines = rates.map { NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: NSColor.black]) }
        let width = mark.size.width + 3 + max(46, ceil(lines.map { $0.size().width }.max() ?? 0))
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { rect in
            mark.draw(at: NSPoint(x: 0, y: (rect.height - mark.size.height) / 2), from: .zero, operation: .sourceOver, fraction: 1)
            for (index, line) in lines.enumerated() {
                line.draw(at: NSPoint(x: rect.width - line.size().width, y: CGFloat(1 - index) * 10 + 1))
            }
            return true
        }
        image.isTemplate = true
        cachedRates = rates
        cachedImage = image
        return image
    }
}
