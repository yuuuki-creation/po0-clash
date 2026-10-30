import AppKit
import Po0FFI
import SwiftUI

/// FlClash's tools page: grouped entries that open their own pages. Entries whose core support is still missing
/// (docs/development/native-feature-parity.md) open a placeholder rather than being hidden.
enum ToolsPage: String, Hashable {
    case language, appearance, application, hotkeys, basic, advanced, resources, backup, developer, about

    var title: LocalizedStringKey {
        switch self {
        case .language: return "Language"
        case .appearance: return "Appearance"
        case .application: return "Application"
        case .hotkeys: return "Hotkeys"
        case .basic: return "Basic configuration"
        case .advanced: return "Advanced configuration"
        case .resources: return "Resources"
        case .backup: return "Backup and restore"
        case .developer: return "Developer mode"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .language: return "character.bubble"
        case .appearance: return "circle.lefthalf.filled"
        case .application: return "macwindow"
        case .hotkeys: return "command"
        case .basic: return "slider.horizontal.3"
        case .advanced: return "gearshape.2"
        case .resources: return "shippingbox"
        case .backup: return "externaldrive"
        case .developer: return "hammer"
        case .about: return "info.circle"
        }
    }

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .language: LanguageView()
        case .hotkeys: HotkeysView()
        case .appearance: AppearanceView()
        case .application: ApplicationView()
        case .basic: BasicConfigView()
        case .advanced: AdvancedConfigView()
        case .resources: ResourcesView()
        case .backup: BackupView()
        case .about: AboutView()
        default: ComingSoon(title: title)
        }
    }
}

struct ToolsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation

    var body: some View {
        NavigationStack(path: $navigation.tools) {
            PageScaffold("Tools") {
                Form {
                    Section("Settings") {
                        entry(.language)
                        entry(.appearance)
                        entry(.application)
                        entry(.hotkeys)
                    }
                    Section("Network and core") {
                        entry(.basic)
                        entry(.advanced)
                        entry(.resources)
                    }
                    Section("Other") {
                        entry(.backup)
                        LabeledContent {
                            Button("Export…") { model.exportDiagnostics() }
                                .disabled(model.launchError != nil)
                        } label: {
                            Label {
                                Text("Diagnostic log")
                                Text("Saves the app, core and engine logs to a text file for troubleshooting.")
                            } icon: {
                                ToolsIcon(symbol: "doc.text.magnifyingglass")
                            }
                        }
                        if model.appSettings?.developerMode == true { entry(.developer) }
                        entry(.about)
                    }
                }
                .formStyle(.grouped)
            }
            .navigationDestination(for: ToolsPage.self) { page in
                PageScaffold(page.title, back: { navigation.tools = Array(navigation.tools.dropLast()) }) {
                    page.destination
                }
            }
        }
    }

    private func entry(_ page: ToolsPage) -> some View {
        NavigationLink(value: page) {
            Label {
                Text(page.title)
            } icon: {
                ToolsIcon(symbol: page.symbol)
            }
        }
    }
}

/// SF Symbols differ in width, so each gets the same slot and the titles line up.
private struct ToolsIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol).frame(width: 20)
    }
}

struct ComingSoon: View {
    let title: LocalizedStringKey

    var body: some View {
        EmptyState(title: title, symbol: "hourglass", detail: "Coming soon.")
    }
}

private struct ApplicationView: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval

    var body: some View {
        Form {
            Section("Startup") {
                Toggle(isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin)) {
                    Text("Launch at login")
                    Text("Opens po0-clash when you log in, and reconnects if it was connected before.")
                }
                if needsApproval {
                    LabeledContent {
                        Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
                    } label: {
                        Text("Allow po0-clash in Login Items to finish turning this on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                toggle(\.silentLaunch, or: false, "Silent launch", "Opens only in the menu bar, without the main window.")
                toggle(\.autoConnect, or: false, "Auto connect", "Connects whenever po0-clash opens.")
            }
            Section("Window") {
                toggle(
                    \.minimizeOnClose, or: true, "Keep running when closed",
                    "Closing the window leaves po0-clash in the menu bar. Turn this off to quit instead."
                )
                toggle(\.pageAnimation, or: true, "Page animation", "Fades each page in as you switch to it.")
                toggle(
                    \.traySpeed, or: true, "Show speed in the menu bar",
                    "Shows the upload and download rates beside the menu bar icon while connected."
                )
            }
            Section("Connections") {
                toggle(
                    \.closeConnectionsOnSwitch, or: true, "Close connections on switch",
                    "Closes open connections after you switch nodes, so they reconnect through the new one."
                )
                toggle(
                    \.onlyProxyTraffic, or: false, "Only count proxy traffic",
                    "Leaves direct connections out of the traffic statistics."
                )
                toggle(
                    \.checkCertificate, or: true, "Verify TLS certificates",
                    "Rejects untrusted certificates. Turning this off exposes subscriptions and backups to man-in-the-middle attacks."
                )
            }
            Section("Other") {
                toggle(\.captureLogs, or: false, "Capture logs", "Shows the engine log in Activity. Turning this off hides the Logs tab.")
                toggle(
                    \.autoCheckUpdate, or: true, "Check for updates automatically",
                    "Looks for a new version when po0-clash opens."
                )
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .onAppear(perform: reloadLaunchAtLogin)
    }

    private func toggle(
        _ key: WritableKeyPath<AppSettings, Bool>,
        or fallback: Bool,
        _ title: LocalizedStringKey,
        _ detail: LocalizedStringKey
    ) -> some View {
        Toggle(isOn: model.setting(key, or: fallback)) {
            Text(title)
            Text(detail)
        }
        .disabled(model.appSettings == nil)
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

private struct LanguageView: View {
    @EnvironmentObject private var model: AppModel
    @State private var asksRestart = false

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: Binding(get: { model.appSettings?.language }, set: choose)) {
                    Text("Follow system").tag(String?.none)
                    ForEach(AppLanguage.choices) { choice in
                        Text(verbatim: choice.name).tag(String?.some(choice.id))
                    }
                }
                .pickerStyle(.radioGroup)
            } footer: {
                Text("The new language applies after po0-clash restarts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(model.appSettings == nil)
        .alert("Restart po0-clash now to use the new language?", isPresented: $asksRestart) {
            Button("Restart Now") { AppLanguage.relaunch() }
            Button("Later", role: .cancel) {}
        }
    }

    private func choose(_ code: String?) {
        guard code != model.appSettings?.language else { return }
        model.updateAppSettings { $0.language = code }
        AppLanguage.store(code)
        asksRestart = true
    }
}

/// The core keeps FlClash's language codes; macOS reads an app's language from its own `AppleLanguages` default at
/// launch, so a choice takes effect on the next start.
enum AppLanguage {
    struct Choice: Identifiable {
        let id: String
        let name: String
    }

    static let choices = [Choice(id: "zh_CN", name: "简体中文"), Choice(id: "en", name: "English")]

    static func store(_ code: String?) {
        if let code {
            UserDefaults.standard.set([code == "zh_CN" ? "zh-Hans" : code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    /// The new copy waits for this one to exit, since the core and the engine port allow one instance.
    static func relaunch() {
        let waiter = Process()
        waiter.executableURL = URL(fileURLWithPath: "/bin/sh")
        waiter.arguments = [
            "-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
            Bundle.main.bundlePath, String(ProcessInfo.processInfo.processIdentifier),
        ]
        try? waiter.run()
        NSApp.terminate(nil)
    }
}

private struct AppearanceView: View {
    @EnvironmentObject private var model: AppModel
    @State private var custom = Color.accentColor

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: model.setting(\.themeMode, or: .system)) {
                    Text("System").tag(ThemeMode.system)
                    Text("Light").tag(ThemeMode.light)
                    Text("Dark").tag(ThemeMode.dark)
                }
                .pickerStyle(.segmented)
                Toggle(isOn: model.setting(\.pureBlack, or: false)) {
                    Text("Pure black")
                    Text("Uses black instead of dark grey behind the content in dark mode.")
                }
                .toggleStyle(.switch)
            }
            Section("Theme color") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(model.appSettings?.themeColors ?? Theme.presets, id: \.self) { argb in
                        swatch(argb)
                    }
                }
                .padding(.vertical, 4)
                LabeledContent("Add a color") {
                    HStack {
                        ColorPicker("Color", selection: $custom, supportsOpacity: false).labelsHidden()
                        Button("Add", action: add)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .disabled(model.appSettings == nil)
    }

    private func swatch(_ argb: UInt32) -> some View {
        let selected = argb == (model.appSettings?.themeColor ?? Theme.defaultColor)
        return Button {
            model.updateAppSettings { $0.themeColor = argb }
        } label: {
            Circle()
                .fill(Theme.accent(argb))
                .frame(width: 26, height: 26)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? Theme.accent(argb) : Color.clear, lineWidth: 2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !Theme.presets.contains(argb) {
                Button("Remove Color") { remove(argb) }
            }
        }
    }

    private func add() {
        guard let argb = custom.argb else { return }
        model.updateAppSettings { settings in
            if !settings.themeColors.contains(argb) { settings.themeColors.append(argb) }
            settings.themeColor = argb
        }
    }

    private func remove(_ argb: UInt32) {
        model.updateAppSettings { settings in
            settings.themeColors.removeAll { $0 == argb }
            if settings.themeColor == argb { settings.themeColor = Theme.defaultColor }
        }
    }
}

private struct AboutView: View {
    @EnvironmentObject private var model: AppModel
    @State private var versionClicks = 0

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "po0-clash").font(.title2.weight(.semibold))
                        Text(verbatim: AppPaths.version)
                            .foregroundStyle(.secondary)
                            .onTapGesture(perform: countVersionClick)
                    }
                }
                .padding(.vertical, 4)
                Text("po0-clash is a cross-platform ClashMeta client with automatic po0 and ggy whitelisting, share-link node import, and subscription management.")
                    .foregroundStyle(.secondary)
            }
            Section("More") {
                LabeledContent("Check for updates") {
                    Button("Check Now") { model.checkForUpdates(userInitiated: true) }
                        .disabled(model.core == nil)
                }
                link("Project", detail: "yuuuki-creation/po0-clash", to: "https://github.com/yuuuki-creation/po0-clash")
            }
            Section("Open-source credits") {
                link("Upstream client", detail: "chen08209/FlClash", to: "https://github.com/chen08209/FlClash")
                link("Core", detail: "mihomo", to: "https://github.com/MetaCubeX/mihomo")
                LabeledContent("Upstream contributors") { Text(verbatim: "June2 · Arue") }
            }
        }
        .formStyle(.grouped)
    }

    private func link(_ title: LocalizedStringKey, detail: String, to address: String) -> some View {
        LabeledContent(title) {
            Link(destination: URL(string: address)!) {
                Label {
                    Text(verbatim: detail)
                } icon: {
                    Image(systemName: "arrow.up.right.square")
                }
                .labelStyle(.titleAndIcon)
            }
        }
    }

    /// FlClash turns developer mode on after a few clicks on the version.
    private func countVersionClick() {
        versionClicks += 1
        guard versionClicks == 5, model.appSettings?.developerMode == false else { return }
        model.updateAppSettings { $0.developerMode = true }
        model.notice = String(localized: "Developer mode is enabled.")
    }
}
