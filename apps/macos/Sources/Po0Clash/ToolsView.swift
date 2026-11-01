import AppKit
import Po0FFI
import SwiftUI

/// FlClash's tools page: grouped entries that open their own pages.
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
        case .developer: DeveloperView()
        case .about: AboutView()
        }
    }
}

struct ToolsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var navigation: Navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Entering or leaving a sub page fades the new one in over the old, which goes at once.
    private var pageTransition: AnyTransition {
        guard !reduceMotion, model.appSettings?.pageAnimation ?? true else { return .identity }
        return .asymmetric(insertion: AnyTransition.opacity.animation(Motion.subpage), removal: .identity)
    }

    var body: some View {
        ZStack {
            if let page = navigation.tools.last {
                PageScaffold(page.title, back: { navigation.tools = Array(navigation.tools.dropLast()) }) {
                    page.destination
                }
                .id(page)
                .transition(pageTransition)
            } else {
                root.transition(pageTransition)
            }
        }
    }

    private var root: some View {
        PageScaffold("Tools") {
            PageScroll {
                TwoColumns() {
                    VStack(alignment: .leading, spacing: Ui.block) {
                        SettingsSection("Settings") {
                            languageEntry
                            entry(.appearance)
                            entry(.application)
                            entry(.hotkeys)
                        }
                        SettingsSection("Other") {
                            entry(.backup)
                            LinkRow(Text("Diagnostic log")) { model.exportDiagnostics() }
                                .disabled(model.launchError != nil)
                            LinkRow(Text("Disclaimer")) {
                                if !model.confirmDisclaimer() { NSApp.terminate(nil) }
                            }
                            if model.appSettings?.developerMode == true { entry(.developer) }
                            entry(.about)
                        }
                    }
                    SettingsSection("Network and core") {
                        entry(.basic)
                        entry(.advanced)
                        entry(.resources)
                    }
                }
            }
        }
    }

    private var languageEntry: some View {
        LinkRow(Text(ToolsPage.language.title)) {
            navigation.tools.append(.language)
        } value: {
            if let code = model.appSettings?.language,
               let choice = AppLanguage.choices.first(where: { $0.id == code }) {
                Text(verbatim: choice.name)
            } else {
                Text("Follow system")
            }
        }
    }

    private func entry(_ page: ToolsPage) -> some View {
        LinkRow(Text(page.title)) { navigation.tools.append(page) }
    }
}

private struct ApplicationView: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval

    var body: some View {
        PageScroll {
            SettingsSection("Startup") {
                ToggleRow("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if needsApproval {
                    Row {
                        Text("Allow po0-clash in Login Items to finish turning this on.")
                            .foregroundStyle(Color.warn)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
                    }
                }
                toggle(\.silentLaunch, or: false, "Silent launch")
                toggle(\.autoConnect, or: false, "Auto connect")
            }
            SettingsSection("Window") {
                toggle(\.minimizeOnClose, or: true, "Keep running when closed")
                toggle(\.pageAnimation, or: true, "Page animation")
                toggle(\.traySpeed, or: true, "Show speed in the menu bar")
            }
            SettingsSection("Connections") {
                toggle(\.closeConnectionsOnSwitch, or: true, "Close connections on switch")
                toggle(\.onlyProxyTraffic, or: false, "Only count proxy traffic")
                toggle(\.checkCertificate, or: true, "Verify TLS certificates")
            }
            SettingsSection("Other") {
                toggle(\.captureLogs, or: false, "Capture logs")
                toggle(\.autoCheckUpdate, or: true, "Check for updates automatically")
            }
        }
        .onAppear(perform: reloadLaunchAtLogin)
    }

    private func toggle(
        _ key: WritableKeyPath<AppSettings, Bool>,
        or fallback: Bool,
        _ title: LocalizedStringKey
    ) -> some View {
        ToggleRow(title, isOn: model.setting(key, or: fallback))
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
        PageScroll {
            RowGroup {
                CheckRow(Text("Follow system"), checked: model.appSettings?.language == nil) { choose(nil) }
                ForEach(AppLanguage.choices) { choice in
                    CheckRow(Text(verbatim: choice.name), checked: model.appSettings?.language == choice.id) {
                        choose(choice.id)
                    }
                }
            }
            .disabled(model.appSettings == nil)
        }
        .dialog(isPresented: $asksRestart) {
            RestartDialog()
        }
    }

    private func choose(_ code: String?) {
        guard code != model.appSettings?.language else { return }
        model.updateAppSettings { $0.language = code }
        AppLanguage.store(code)
        asksRestart = true
    }
}

private struct RestartDialog: View {
    @Environment(\.dismissDialog) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Restart po0-clash now to use the new language?").font(.system(size: 15, weight: .semibold))
            DialogActions {
                Button("Later") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Restart Now") { AppLanguage.relaunch() }
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 440)
    }
}

/// The core keeps FlClash's language codes; macOS reads an app's language from its own `AppleLanguages` default at
/// launch, so a choice takes effect on the next start.
enum AppLanguage {
    struct Choice: Identifiable {
        let id: String
        let name: String
    }

    static let choices = [
        Choice(id: "zh_CN", name: "简体中文"),
        Choice(id: "en", name: "English"),
        Choice(id: "ja", name: "日本語"),
        Choice(id: "ru", name: "Русский"),
    ]

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
        PageScroll {
            RowGroup {
                ControlRow(Text("Theme")) {
                    SegmentedControl(
                        selection: model.setting(\.themeMode, or: .system),
                        segments: [
                            Segment(ThemeMode.system, "System"), Segment(ThemeMode.light, "Light"),
                            Segment(ThemeMode.dark, "Dark"),
                        ]
                    )
                }
                ToggleRow("Pure black", isOn: model.setting(\.pureBlack, or: false))
            }
            SettingsSection("Theme color") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(model.appSettings?.themeColors ?? Theme.presets, id: \.self) { argb in
                        swatch(argb)
                    }
                }
                .padding(Ui.padding)
                Row {
                    Text("Add a color").frame(maxWidth: .infinity, alignment: .leading)
                    ColorPicker("Color", selection: $custom, supportsOpacity: false).labelsHidden()
                    Button("Add", action: add)
                }
            }
        }
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
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.onAccent(argb))
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
    @State private var showsLicenses = false

    var body: some View {
        PageScroll {
            RowGroup {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "po0-clash").font(.system(size: 16, weight: .semibold))
                        Text(verbatim: AppPaths.version)
                            .foregroundStyle(Color.ink2)
                            .onTapGesture(perform: countVersionClick)
                    }
                }
                .padding(Ui.padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("po0-clash is a cross-platform ClashMeta client with automatic po0 and ggy whitelisting, share-link node import, and subscription management.")
                    .foregroundStyle(Color.ink2)
                    .padding(Ui.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hairlineAbove()
            }
            SettingsSection("More") {
                Row {
                    Text("Check for updates").frame(maxWidth: .infinity, alignment: .leading)
                    Button("Check Now") { model.checkForUpdates(userInitiated: true) }
                        .disabled(model.core == nil)
                }
                link("Project", detail: "yuuuki-creation/po0-clash", to: "https://github.com/yuuuki-creation/po0-clash")
            }
            SettingsSection("Open-source credits") {
                link("Upstream client", detail: "chen08209/FlClash", to: "https://github.com/chen08209/FlClash")
                link("Core", detail: "mihomo", to: "https://github.com/MetaCubeX/mihomo")
                ValueRow(Text("Upstream contributors")) { Text(verbatim: "June2 · Arue") }
                Row {
                    Text("Open-source licenses").frame(maxWidth: .infinity, alignment: .leading)
                    Button("Show…") { showsLicenses = true }
                }
            }
        }
        .dialog(isPresented: $showsLicenses) { LicensesDialog() }
    }

    private func link(_ title: LocalizedStringKey, detail: String, to address: String) -> some View {
        Row {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
            Link(destination: URL(string: address)!) {
                HStack(spacing: 4) {
                    Text(verbatim: detail)
                    Image(systemName: "arrow.up.right.square")
                }
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
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

private struct LicensesDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    @State private var licenses: [License] = []
    @State private var query = ""

    private var shown: [License] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return licenses }
        return licenses.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                DialogTitle(title: "Open-Source Licenses")
                SearchField(text: $query)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, license in
                        HStack(spacing: 12) {
                            Text(verbatim: license.version.isEmpty ? license.name : "\(license.name) \(license.version)")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(verbatim: license.license).foregroundStyle(Color.ink2).lineLimit(1)
                            if !license.url.isEmpty, let url = URL(string: license.url) {
                                Link(destination: url) {
                                    Image(systemName: "arrow.up.right.square").foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .help(license.url)
                            }
                        }
                        .tableRow(zebra: index % 2 == 1)
                    }
                }
            }
            .cardSurface()
            DialogActions {
                Button("Done") { dismiss() }
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 520, maxHeight: 560)
        .task { licenses = await model.licenses() }
    }
}

extension License: Identifiable {
    public var id: String { "\(name) \(version)" }
}

/// FlClash's developer mode, which About turns on after five clicks on the version.
private struct DeveloperView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmingCrash = false
    @State private var confirmingClear = false

    private var captureLogs: Bool { model.appSettings?.captureLogs == true }

    var body: some View {
        PageScroll {
            RowGroup {
                ToggleRow("Developer mode", isOn: model.setting(\.developerMode, or: false))
                    .disabled(model.appSettings == nil)
            }
            SettingsSection("Options") {
                row("Message test", button: "Show") {
                    model.notice = String(localized: "This is a message.")
                }
                row("Logs test", button: "Add") { model.addTestLogs() }
                    .disabled(!captureLogs)
                row("Crash test", button: "Crash…") { confirmingCrash = true }
                    .disabled(!model.isRunning)
                row("Clear data", button: "Clear…") { confirmingClear = true }
                row("Prune cache", button: "Prune") { model.pruneCache() }
            }
            .disabled(model.core == nil)
        }
        .dialog(isPresented: $confirmingCrash, closesOnScrimClick: true) {
            ConfirmDialog(
                title: String(localized: "Crash the engine?"),
                message: "The connection drops until you connect again.",
                confirm: "Crash"
            ) { model.crashEngine() }
        }
        .dialog(isPresented: $confirmingClear, closesOnScrimClick: true) {
            ConfirmDialog(
                title: String(localized: "Clear all data?"),
                message: "Every profile, whitelist entry and setting is removed and po0-clash restarts. This cannot be undone.",
                confirm: "Clear Data"
            ) { model.clearData() }
        }
    }

    private func row(
        _ title: LocalizedStringKey,
        button: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Row {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
            Button(button, action: action)
        }
    }
}
