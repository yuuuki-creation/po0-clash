import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval

    var body: some View {
        PageScaffold("Settings") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Launch at login")
                    Spacer()
                    Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                if needsApproval {
                    HStack {
                        Text("Allow po0-clash in Login Items to finish turning this on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
                    }
                }
            }
            .groupedSection()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diagnostic log")
                    Text("Saves the app, core and engine logs to a text file for troubleshooting.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Export…") { model.exportDiagnostics() }
                    .disabled(model.launchError != nil)
            }
            .groupedSection()
            HStack {
                Text("Version")
                Spacer()
                Text(AppPaths.version).foregroundStyle(.secondary).textSelection(.enabled)
            }
            .groupedSection()
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
