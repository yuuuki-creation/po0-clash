import AppKit

/// Launch arguments that put the UI on screen without a click, for CI screenshots.
@MainActor
enum Showcase {
    static func run() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "appearance") == "dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        Task {
            if let names = defaults.string(forKey: "dashboardCards")?.split(separator: ",").map(String.init) {
                await wait(seconds: 10) { AppModel.shared.appSettings != nil }
                AppModel.shared.updateAppSettings { settings in
                    settings.dashboardCards = DashboardCard.all.filter { names.contains(String(describing: $0)) }
                }
            }
            if let name = defaults.string(forKey: "showWindow") {
                MainWindow.shared.show(Page(rawValue: name) ?? .dashboard)
            }
            if let name = defaults.string(forKey: "toolsPage"), let page = ToolsPage(rawValue: name) {
                MainWindow.shared.navigation.tools = [page]
            }
            if defaults.string(forKey: "activityTab") == "logs" {
                await wait(seconds: 10) { AppModel.shared.appSettings != nil }
                AppModel.shared.updateAppSettings { $0.captureLogs = true }
            }
            if defaults.bool(forKey: "testDelays") { await testDelays() }
            if let layout = defaults.string(forKey: "proxiesLayout") {
                await wait(seconds: 10) { AppModel.shared.appSettings != nil }
                AppModel.shared.updateAppSettings { $0.proxiesLayout = layout == "list" ? .list : .tabs }
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

    /// CI starts the app with launch arguments, and an update alert would cover its screenshots.
    static var isScripted: Bool {
        !UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain).isEmpty
    }

    static var forcesAppearance: Bool {
        UserDefaults.standard.string(forKey: "appearance") != nil
    }

    /// Menu screenshots need the screen to themselves, and a requested page should be the first one drawn.
    static var keepsWindowClosed: Bool {
        UserDefaults.standard.bool(forKey: "showMenu") || UserDefaults.standard.string(forKey: "showWindow") != nil
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
