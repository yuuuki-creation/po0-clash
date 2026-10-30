import AppKit
import Po0FFI
import SwiftUI

@main
struct Po0ClashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(model)
        } label: {
            MenuBarLabel().environmentObject(model)
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
        source.setEventHandler { onMainRunLoop { NSApp.terminate(nil) } }
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
        if !atLogin, !Showcase.keepsWindowClosed { MainWindow.shared.show() }
        Showcase.run()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindow.shared.show()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard AppModel.shared.hasCore else { return .terminateNow }
        AppModel.shared.shutdown { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

/// The Flutter app's menu bar look: the po0 template mark, with the current speed beside it while connected.
private struct MenuBarLabel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Image(nsImage: MenuBarIcon.image(speed: model.showsMenuBarSpeed && model.isRunning ? model.traffic : nil))
            .accessibilityLabel("po0-clash")
    }
}

@MainActor
enum MenuBarIcon {
    private static let mark: NSImage = {
        let image = Bundle.main.image(forResource: "MenuBarIcon") ?? NSImage(systemSymbolName: "p.circle", accessibilityDescription: nil)!
        image.isTemplate = true
        return image
    }()

    static func image(speed: Traffic?) -> NSImage {
        guard let speed else { return mark }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let label = HStack(spacing: 3) {
            Image(nsImage: mark)
            VStack(alignment: .trailing, spacing: -1) {
                Text(Format.shortRate(speed.up))
                Text(Format.shortRate(speed.down))
            }
            .font(.system(size: 9, weight: .medium).monospacedDigit())
            .frame(minWidth: 46, alignment: .trailing)
        }
        .frame(height: 22)
        let renderer = ImageRenderer(content: label)
        renderer.scale = scale
        guard let rendered = renderer.cgImage else { return mark }
        let image = NSImage(
            cgImage: rendered,
            size: NSSize(width: CGFloat(rendered.width) / scale, height: CGFloat(rendered.height) / scale)
        )
        image.isTemplate = true
        return image
    }
}
