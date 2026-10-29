import AppKit

/// Launch arguments that put the UI on screen without a click, for CI screenshots.
@MainActor
enum Showcase {
    static func run() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "appearance") == "dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        Task {
            if defaults.bool(forKey: "testDelays") { await testDelays() }
            if let name = defaults.string(forKey: "showSettings") {
                let tabs: [String: SettingsTab] = ["general": .general, "subscriptions": .subscriptions, "whitelist": .whitelist]
                SettingsWindow.shared.show(tabs[name] ?? .general)
            }
            if defaults.bool(forKey: "showMenu") {
                let clicks = defaults.bool(forKey: "reopenMenu") ? 3 : 1
                for _ in 0..<clicks {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    statusItem()?.button?.performClick(nil)
                }
            }
        }
    }

    private static func testDelays() async {
        let model = AppModel.shared
        await wait(seconds: 20) { model.isRunning && !model.groups.isEmpty }
        for group in model.groups where group.selectable { model.testDelay(group.name) }
        await wait(seconds: 15) { model.testing.isEmpty }
    }

    private static func wait(seconds: Double, until done: () -> Bool) async {
        let deadline = Date().addingTimeInterval(seconds)
        while !done(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private static func statusItem() -> NSStatusItem? {
        let key = "statusItem"
        for window in NSApp.windows where window.responds(to: NSSelectorFromString(key)) {
            if let item = window.value(forKey: key) as? NSStatusItem { return item }
        }
        return nil
    }
}
