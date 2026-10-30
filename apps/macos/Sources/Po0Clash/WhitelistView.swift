import Po0FFI
import SwiftUI

struct WhitelistView: View {
    @EnvironmentObject private var model: AppModel
    @State private var adding = false

    private var entries: [WhitelistEntry] { model.whitelist?.entries ?? [] }

    var body: some View {
        PageScaffold("Whitelist", subtitle: model.whitelistSummary) {
            Button {
                adding = true
            } label: {
                Label("Add…", systemImage: "plus")
            }
            .help("Add to Whitelist")
        } content: {
            Form {
                Section {
                    Toggle(isOn: Binding(
                        get: { model.whitelist?.enabled ?? false },
                        set: { model.setWhitelistEnabled($0) }
                    )) {
                        Text("Auto whitelist")
                        Text("Keeps this Mac's real exit IP on the po0 and ggy whitelists while po0-clash is open, connected or not.")
                    }
                    .toggleStyle(.switch)
                    .disabled(model.whitelist == nil)
                }
                Section("Tokens and links") {
                    if entries.isEmpty {
                        EmptyRow(title: "No tokens or links", detail: "Add a po0 token or a ggy whitelist link.")
                    } else {
                        ForEach(entries, id: \.id) { entry in
                            EntryRow(entry: entry)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .sheet(isPresented: $adding) {
            AddEntriesSheet().environmentObject(model)
        }
    }
}

private struct EntryRow: View {
    @EnvironmentObject private var model: AppModel
    let entry: WhitelistEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(verbatim: entry.kind == .po0 ? "po0" : "ggy")
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if !entry.name.isEmpty { Text(entry.name).fontWeight(.medium) }
                    Text(entry.label).font(.callout.monospaced()).foregroundStyle(.secondary)
                }
                if let result = entry.result {
                    HStack(spacing: 6) {
                        Label(result.outcome.title, systemImage: result.outcome.symbol)
                            .foregroundStyle(result.outcome.tint)
                        if let ip = result.ip { Text(ip).monospacedDigit() }
                        Text(Format.date(result.at), format: .relative(presentation: .named))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    if let message = result.message, !message.isEmpty {
                        Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                } else {
                    Text("Waiting for the first check").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                model.removeWhitelistEntry(entry.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
        .padding(.vertical, 4)
    }
}

private struct AddEntriesSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var text = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to Whitelist").font(.headline)
            TextField("Name (optional)", text: $name)
                .textFieldStyle(.roundedBorder)
            Text("Paste po0 tokens or ggy whitelist links, one per line.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            HStack {
                if working { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func add() {
        working = true
        error = nil
        Task {
            error = await model.addWhitelist(text, name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            working = false
            if error == nil { dismiss() }
        }
    }
}
