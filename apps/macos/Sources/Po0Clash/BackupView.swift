import Po0FFI
import SwiftUI

enum BackupSource: Hashable {
    case webDav
    case file(URL)
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
        Form {
            Section("WebDAV") {
                if let dav = model.appSettings?.webdav {
                    LabeledContent("Address", value: dav.url)
                    LabeledContent("Account", value: dav.user)
                    LabeledContent("File", value: dav.fileName.isEmpty ? "backup.zip" : dav.fileName)
                    LabeledContent("Connection") { connectionLabel }
                    HStack {
                        Button("Edit…") { editing = true }
                        Spacer()
                        if working { ProgressView().controlSize(.small) }
                        Button("Back Up") { run { await model.backupToWebDav() } }
                        Button("Restore…") { restoring = .webDav }
                    }
                } else {
                    LabeledContent {
                        Button("Set Up…") { editing = true }
                    } label: {
                        Text("Not set up")
                        Text("Back up to a WebDAV account such as Nextcloud or Jianguoyun.")
                    }
                }
            }
            Section("Local") {
                LabeledContent {
                    Button("Back Up…") { run { await model.backupToFile() } }
                } label: {
                    Text("Back up to a file")
                    Text("Saves the profiles and settings in a zip file.")
                }
                LabeledContent {
                    Button("Restore…") { restoring = model.chooseBackupFile().map(BackupSource.file) }
                } label: {
                    Text("Restore from a file")
                    Text("Brings back a zip file made here or on another device.")
                }
            }
            Section {
                Picker("Restore strategy", selection: model.setting(\.restoreStrategy, or: .compatible)) {
                    Text("Compatible").tag(RestoreStrategy.compatible)
                    Text("Override").tag(RestoreStrategy.override)
                }
            } footer: {
                Text("Compatible keeps the profiles already here; Override replaces them with the backup's.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(model.appSettings == nil || working)
        .sheet(isPresented: $editing) { WebDavEditor().environmentObject(model) }
        .confirmationDialog(
            "Restore",
            isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }),
            presenting: restoring
        ) { source in
            Button("Restore All Data") { run { await model.restore(from: source, scope: .all) } }
            Button("Restore Only Profiles") { run { await model.restore(from: source, scope: .profiles) } }
        } message: { _ in
            Text("Profiles always come back; restoring all data also brings back the settings.")
        }
        .task(id: model.appSettings?.webdav) { await check() }
    }

    @ViewBuilder
    private var connectionLabel: some View {
        switch connection {
        case .unknown: Text(verbatim: "—")
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…")
            }
        case .connected: Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(Color.goodText)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(Color.badText)
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

private struct WebDavEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var user = ""
    @State private var password = ""
    @State private var fileName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WebDAV").font(.headline)
            Form {
                TextField("Address", text: $url, prompt: Text(verbatim: "https://dav.example.com/dav/"))
                TextField("Account", text: $user)
                SecureField("Password", text: $password)
                TextField("File", text: $fileName, prompt: Text(verbatim: "backup.zip"))
            }
            HStack {
                if model.appSettings?.webdav != nil {
                    Button("Remove") { save(nil) }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save(WebDav(url: url.trimmed, user: user.trimmed, password: password, fileName: fileName.trimmed))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(url.trimmed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
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
