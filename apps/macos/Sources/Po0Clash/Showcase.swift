import AppKit

/// Launch arguments (`-showSettings <tab>`, `-showMenu YES`) that open the UI without a click, for CI screenshots.
@MainActor
enum Showcase {
    static func run() {
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: "showSettings") {
            let tabs: [String: SettingsTab] = ["general": .general, "subscriptions": .subscriptions, "whitelist": .whitelist]
            SettingsWindow.shared.show(tabs[name] ?? .general)
        }
        if defaults.bool(forKey: "showMenu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { statusItem()?.button?.performClick(nil) }
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
