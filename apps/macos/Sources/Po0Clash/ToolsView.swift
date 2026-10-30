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
        case .appearance: AppearanceView()
        case .application: ApplicationView()
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
                Button {
                    model.exportDiagnostics()
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
                .help("Diagnostic log")
                .disabled(model.launchError != nil)
            } content: {
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
                                Image(systemName: "doc.text.magnifyingglass")
                            }
                        }
                        entry(.developer)
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
            Label(page.title, systemImage: page.symbol)
        }
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
            Section {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                    .toggleStyle(.switch)
                Toggle("Show speed in the menu bar", isOn: $model.showsMenuBarSpeed)
                    .toggleStyle(.switch)
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
    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: AppPaths.version)
            }
        }
        .formStyle(.grouped)
    }
}
