import Po0FFI
import SwiftUI

enum BackupSource: Hashable, Identifiable {
    case webDav
    case file(URL)

    var id: Self { self }
}

/// FlClash's backup page: a WebDAV account and local zip files, with the restore strategy both use.
struct BackupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing = false
    @State private var connection = Connection.unknown
    @State private var restoring: BackupSource?
    @State private var working = false

    private enum Connection: Equatable {
        case unknown, checking, connected
        case failed(String)
    }

    var body: some View {
        PageScroll {
            SettingsSection("WebDAV") {
                if let dav = model.appSettings?.webdav {
                    ValueRow(Text("Address")) { Text(verbatim: dav.url) }
                    ValueRow(Text("Account")) { Text(verbatim: dav.user) }
                    ValueRow(Text("File")) { Text(verbatim: dav.fileName.isEmpty ? "backup.zip" : dav.fileName) }
                    Row {
                        Text("Connection").frame(maxWidth: .infinity, alignment: .leading)
                        connectionLabel
                    }
                    Row {
                        Button("Edit…") { editing = true }
                        Spacer()
                        if working { Ring() }
                        Button("Back Up") { run { await model.backupToWebDav() } }
                        Button("Restore…") { restoring = .webDav }
                    }
                } else {
                    Row {
                        Text("Not set up").frame(maxWidth: .infinity, alignment: .leading)
                        Button("Set Up…") { editing = true }
                    }
                }
            }
            SettingsSection("Local") {
                Row {
                    Text("Back up to a file").frame(maxWidth: .infinity, alignment: .leading)
                    Button("Back Up…") { run { await model.backupToFile() } }
                }
                Row {
                    Text("Restore from a file").frame(maxWidth: .infinity, alignment: .leading)
                    Button("Restore…") { restoring = model.chooseBackupFile().map(BackupSource.file) }
                }
            }
            RowGroup {
                OptionRow("Restore strategy", selection: model.setting(\.restoreStrategy, or: .compatible), options: [
                    Option(RestoreStrategy.compatible, String(localized: "Compatible")),
                    Option(RestoreStrategy.override, String(localized: "Override")),
                ])
            }
        }
        .disabled(model.appSettings == nil || working)
        .dialog(isPresented: $editing) { WebDavEditor() }
        .dialog(item: $restoring, closesOnScrimClick: true) { source in
            RestoreDialog { scope in
                run { await model.restore(from: source, scope: scope) }
            }
        }
        .task(id: model.appSettings?.webdav) { await check() }
    }

    @ViewBuilder
    private var connectionLabel: some View {
        switch connection {
        case .unknown: Text(verbatim: "—").foregroundStyle(Color.ink2)
        case .checking:
            HStack(spacing: 6) {
                Ring()
                Text("Checking…").foregroundStyle(Color.ink2)
            }
        case .connected:
            Text("Connected").foregroundStyle(Color.accentColor)
        case .failed(let message):
            Text(verbatim: message)
                .foregroundStyle(Color.bad)
                .lineLimit(2)
        }
    }

    private func check() async {
        guard let dav = model.appSettings?.webdav else { return }
        connection = .checking
        let failure = await model.checkWebDav(dav)
        connection = failure.map(Connection.failed) ?? .connected
    }

    private func run(_ action: @escaping () async -> Void) {
        working = true
        Task {
            await action()
            working = false
        }
    }
}

private struct RestoreDialog: View {
    @Environment(\.dismissDialog) private var dismiss
    let restore: (RestoreScope) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "Restore")
            Text("Profiles always come back; restoring all data also brings back the settings.")
                .fixedSize(horizontal: false, vertical: true)
            DialogActions {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Restore Only Profiles") {
                    dismiss()
                    restore(.profiles)
                }
                Button("Restore All Data") {
                    dismiss()
                    restore(.all)
                }
                .buttonStyle(ActionButtonStyle(primary: true))
            }
        }
        .frame(maxWidth: 480)
    }
}

private struct WebDavEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    @State private var url = ""
    @State private var user = ""
    @State private var password = ""
    @State private var fileName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "WebDAV")
            RowGroup {
                FieldRow("Address") {
                    TextField("Address", text: $url, prompt: Text(verbatim: "https://dav.example.com/dav/"))
                }
                FieldRow("Account") { TextField("Account", text: $user) }
                FieldRow("Password") { SecureField("Password", text: $password) }
                FieldRow("File") { TextField("File", text: $fileName, prompt: Text(verbatim: "backup.zip")) }
            }
            HStack(spacing: 8) {
                if model.appSettings?.webdav != nil {
                    Button("Remove") { save(nil) }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save(WebDav(url: url.trimmed, user: user.trimmed, password: password, fileName: fileName.trimmed))
                }
                .buttonStyle(ActionButtonStyle(primary: true))
                .keyboardShortcut(.defaultAction)
                .disabled(url.trimmed.isEmpty)
            }
        }
        .frame(maxWidth: 480)
        .onAppear {
            guard let dav = model.appSettings?.webdav else { return }
            url = dav.url
            user = dav.user
            password = dav.password
            fileName = dav.fileName
        }
    }

    private func save(_ dav: WebDav?) {
        model.updateAppSettings { $0.webdav = dav }
        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
