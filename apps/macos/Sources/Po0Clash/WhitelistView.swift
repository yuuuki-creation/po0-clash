import Po0FFI
import SwiftUI

extension WhitelistEntry: Identifiable {}

struct WhitelistView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.compactContent) private var compact
    @State private var adding = false
    @State private var pendingRemoval: WhitelistEntry?

    private var entries: [WhitelistEntry] { model.whitelist?.entries ?? [] }

    private var columns: [ColumnWidth] {
        compact
            ? [.fixed(40), .flex(1), .fixed(120), .fixed(104), .fixed(Ui.control)]
            : [.fixed(40), .flex(1), .flex(1), .fixed(120), .fixed(104), .fixed(Ui.control)]
    }

    var body: some View {
        PageScaffold("Whitelist") {
            Button("Add") { adding = true }
                .buttonStyle(ActionButtonStyle(primary: true))
                .help("Add to Whitelist")
        } content: {
            PageScroll {
                RowGroup {
                    ToggleRow("Auto whitelist", isOn: Binding(
                        get: { model.whitelist?.enabled ?? false },
                        set: { model.setWhitelistEnabled($0) }
                    ))
                    .disabled(model.whitelist == nil)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tokens and links").font(Ui.boldFont)
                    if entries.isEmpty {
                        RowGroup {
                            Row {
                                Text("No tokens or links").foregroundStyle(Color.ink2)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                EntryRow(entry: entry, columns: columns, zebra: index % 2 == 1) {
                                    pendingRemoval = entry
                                }
                                .transition(.rowFold)
                            }
                        }
                        .cardSurface()
                        .rowListMotion(ids: entries.map(\.id))
                    }
                }
            }
        }
        .dialog(isPresented: $adding) {
            AddEntriesDialog()
        }
        .dialog(item: $pendingRemoval, closesOnScrimClick: true) { entry in
            ConfirmDialog(title: String(localized: "Delete \(entry.name.isEmpty ? entry.label : entry.name)?"), confirm: "Delete") {
                model.removeWhitelistEntry(entry.id)
            }
        }
    }
}

private struct EntryRow: View {
    @Environment(\.compactContent) private var compact
    @EnvironmentObject private var model: AppModel
    let entry: WhitelistEntry
    let columns: [ColumnWidth]
    let zebra: Bool
    let remove: () -> Void

    private var enabled: Bool { model.whitelist?.enabled == true }

    /// Rejections and errors carry the server's words, which is the only way to tell why an entry failed.
    private var failure: String? {
        guard let result = entry.result, result.outcome == .rejected || result.outcome == .error else { return nil }
        return result.message.flatMap { $0.isEmpty ? nil : $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ColumnsLayout(columns: columns) {
                Text(verbatim: entry.kind == .po0 ? "po0" : "ggy").foregroundStyle(Color.ink2)
                Text(verbatim: entry.name).lineLimit(1)
                if !compact {
                    Text(verbatim: entry.label).foregroundStyle(Color.ink2).lineLimit(1).truncationMode(.middle)
                }
                outcome
                Text(verbatim: entry.result?.ip ?? "").foregroundStyle(Color.ink2).lineLimit(1)
                IconButton(symbol: "trash", help: "Remove", action: remove)
            }
            if let failure {
                ErrorText(message: failure).padding(.bottom, 6)
            }
        }
        .tableRow(height: 38, zebra: zebra)
    }

    private var outcome: some View {
        HStack(spacing: 8) {
            StatusDot(color: dotColor, size: 8, pulsing: enabled && entry.result == nil)
            Text(verbatim: outcomeText).lineLimit(1)
        }
    }

    private var dotColor: Color {
        guard enabled else { return .ink3 }
        return entry.result?.outcome.tint ?? .warn
    }

    private var outcomeText: String {
        guard enabled else { return String(localized: "Disabled") }
        return entry.result?.outcome.title ?? String(localized: "Checking…")
    }
}

private struct AddEntriesDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    @State private var name = ""
    @State private var text = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "Add to Whitelist")
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(Ui.codeFont)
                    .scrollContentBackground(.hidden)
                    .frame(height: 120)
                    .padding(4)
                if text.isEmpty {
                    Text("Paste po0 tokens or ggy whitelist links, one per line.")
                        .foregroundStyle(Color.ink3)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .allowsHitTesting(false)
                }
            }
            .editorChrome()
            TextField("Name (optional)", text: $name).fieldChrome()
            if let error { ErrorText(message: error) }
            DialogActions {
                if working { Ring() }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
            }
        }
        .frame(maxWidth: 460)
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
