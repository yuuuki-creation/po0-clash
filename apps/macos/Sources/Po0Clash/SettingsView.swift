import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval

    var body: some View {
        PageScaffold("Settings") {
            Form {
                Section {
                    Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
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
                Section {
                    LabeledContent {
                        Button("Export…") { model.exportDiagnostics() }
                            .disabled(model.launchError != nil)
                    } label: {
                        Text("Diagnostic log")
                        Text("Saves the app, core and engine logs to a text file for troubleshooting.")
                    }
                }
                Section {
                    LabeledContent("Version", value: AppPaths.version)
                }
            }
            .formStyle(.grouped)
        }
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
