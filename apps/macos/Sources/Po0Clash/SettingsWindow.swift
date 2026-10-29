import AppKit
import Po0FFI
import SwiftUI

enum SettingsTab: Int {
    case general, subscriptions, whitelist
}

/// An AppKit window rather than a SwiftUI `Settings` scene: an accessory app cannot open that scene reliably on
/// macOS 13 and 14, and this keeps the toolbar-tab preferences look on every version.
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?
    private var tabs: NSTabViewController?

    func show(_ tab: SettingsTab? = nil) {
        if window == nil { build() }
        if let tab { tabs?.selectedTabViewItemIndex = tab.rawValue }
        activateApp()
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(item(String(localized: "General"), symbol: "gearshape", GeneralView()))
        tabs.addTabViewItem(item(String(localized: "Subscriptions"), symbol: "tray.full", SubscriptionsView()))
        tabs.addTabViewItem(item(String(localized: "Whitelist"), symbol: "checkmark.shield", WhitelistView()))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        self.tabs = tabs
        self.window = window
    }

    private func item<Content: View>(_ title: String, symbol: String, _ content: Content) -> NSTabViewItem {
        let host = NSHostingController(rootView: content.environmentObject(AppModel.shared).frame(width: 600, height: 460))
        let item = NSTabViewItem(viewController: host)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}

struct GeneralView: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if needsApproval {
                    LabeledContent {
                        Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
                    } label: {
                        Text("Allow po0-clash in Login Items to finish turning this on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                LabeledContent {
                    Button("Export…") { model.exportDiagnostics() }
                        .disabled(model.launchError != nil)
                } label: {
                    Text("Diagnostic log")
                    Text("Saves the app, core and engine logs to a text file for troubleshooting.")
                }
            }
            if let notice = model.notice {
                Section {
                    NoticeBanner(text: notice) { model.notice = nil }
                }
            }
            Section {
                LabeledContent("Version", value: AppPaths.version)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reloadLaunchAtLogin)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
        } catch {
            model.notice = describe(error)
        }
        reloadLaunchAtLogin()
    }

    private func reloadLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval
        needsApproval = LaunchAtLogin.needsApproval
    }
}
