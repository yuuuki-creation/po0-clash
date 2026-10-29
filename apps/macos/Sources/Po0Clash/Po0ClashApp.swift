import AppKit
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
            Image(systemName: model.menuBarSymbol)
                .accessibilityLabel("po0-clash")
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
        AppModel.shared.launch()
        Showcase.run()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard AppModel.shared.hasCore else { return .terminateNow }
        AppModel.shared.shutdown { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

extension AppModel {
    var menuBarSymbol: String {
        switch status?.engine {
        case .running?: return "bolt.horizontal.circle.fill"
        case .failed?: return "exclamationmark.triangle"
        default: return launchError == nil ? "bolt.horizontal.circle" : "exclamationmark.triangle"
        }
    }
}
