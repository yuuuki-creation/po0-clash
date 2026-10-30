import SwiftUI

/// FlClash's tools page: grouped entries that open their own pages. Entries whose core support is still missing
/// (docs/development/native-feature-parity.md) open a placeholder rather than being hidden.
struct ToolsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
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
                        entry("Language", symbol: "character.bubble") { ComingSoon(title: "Language") }
                        entry("Appearance", symbol: "circle.lefthalf.filled") { ComingSoon(title: "Appearance") }
                        entry("Application", symbol: "macwindow") { ApplicationView() }
                        entry("Hotkeys", symbol: "command") { ComingSoon(title: "Hotkeys") }
                    }
                    Section("Network and core") {
                        entry("Basic configuration", symbol: "slider.horizontal.3") {
                            ComingSoon(title: "Basic configuration")
                        }
                        entry("Advanced configuration", symbol: "gearshape.2") {
                            ComingSoon(title: "Advanced configuration")
                        }
                        entry("Resources", symbol: "shippingbox") { ComingSoon(title: "Resources") }
                    }
                    Section("Other") {
                        entry("Backup and restore", symbol: "externaldrive") { ComingSoon(title: "Backup and restore") }
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
                        entry("Developer mode", symbol: "hammer") { ComingSoon(title: "Developer mode") }
                        entry("About", symbol: "info.circle") { AboutView() }
                    }
                }
                .formStyle(.grouped)
            }
        }
    }

    private func entry<Destination: View>(
        _ title: LocalizedStringKey,
        symbol: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination().navigationTitle(title)
        } label: {
            Label(title, systemImage: symbol)
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
