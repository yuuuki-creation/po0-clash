import Po0FFI
import SwiftUI

extension Profile: Identifiable {}

extension ShareNode: Identifiable {
    public var id: String { name }
}

struct SubscriptionsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.compactContent) private var compact
    @State private var sheet: Sheet?
    @State private var pendingRemoval: Profile?

    private enum Sheet: Identifiable {
        case subscription, links
        case edit(Profile)
        case editor(Profile)
        case override(Profile)
        case nodes(Profile)
        case text(Profile, ProfileText)

        var id: String {
            switch self {
            case .subscription: return "subscription"
            case .links: return "links"
            case .edit(let profile): return "edit/\(profile.id)"
            case .editor(let profile): return "editor/\(profile.id)"
            case .override(let profile): return "override/\(profile.id)"
            case .nodes(let profile): return "nodes/\(profile.id)"
            case .text(let profile, let text): return "text/\(profile.id)/\(text)"
            }
        }
    }

    private var columns: [ColumnWidth] {
        compact
            ? [.flex(1), .flex(1.8), .fixed(60)]
            : [.flex(1.2), .flex(2), .fixed(92), .fixed(60)]
    }

    var body: some View {
        PageScaffold("Profiles") {
            Button("Update All") { model.updateAllProfiles() }
                .disabled(!model.profiles.contains { $0.kind == .subscription } || !model.updating.isEmpty)
            MenuButton(placement: .belowTrailing) {
                Text("Add")
            } entries: {
                addEntries
            }
            .buttonStyle(ActionButtonStyle(primary: true))
        } content: {
            if model.profiles.isEmpty {
                EmptyState(title: "No profiles", symbol: "tray")
            } else {
                PageScroll {
                    table
                }
            }
        }
        .dialog(item: $sheet) { sheet in
            switch sheet {
            case .subscription: AddSubscriptionDialog()
            case .links: ImportLinksDialog()
            case .edit(let profile): EditProfileDialog(profile: profile)
            case .editor(let profile): ProfileEditorDialog(profile: profile)
            case .override(let profile): ProfileOverrideDialog(profile: profile)
            case .nodes(let profile): ShareNodesDialog(profile: profile)
            case .text(let profile, let text): ProfileTextDialog(profile: profile, text: text)
            }
        }
        .dialog(item: $pendingRemoval, closesOnScrimClick: true) { profile in
            ConfirmDialog(title: String(localized: "Delete \(profile.title)?"), confirm: "Delete") {
                model.removeProfile(profile.id)
            }
        }
        .task(id: model.profiles.count) {
            if Showcase.showsOverride, sheet == nil, let profile = model.profiles.first(where: \.selected) {
                sheet = .override(profile)
            }
        }
    }

    private var addEntries: [MenuEntry] {
        [
            MenuEntry.action(String(localized: "Add Subscription…"), perform: { sheet = .subscription }),
            MenuEntry.action(String(localized: "Import Share Links…"), perform: { sheet = .links }),
            MenuEntry.action(String(localized: "Import File…"), perform: { model.importProfileFile() }),
            MenuEntry.action(String(localized: "Import QR Code Image…"), perform: { model.importQrCode() }),
        ]
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 0) {
            ColumnsLayout(columns: columns, spacing: 16) {
                Text("Name")
                Text("Usage")
                if !compact { Text("Expires") }
                Color.clear.frame(height: 0)
            }
            .tableHeader()
            ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, profile in
                ProfileRow(
                    profile: profile,
                    columns: columns,
                    zebra: index % 2 == 0,
                    canMoveUp: index > 0,
                    canMoveDown: index < model.profiles.count - 1
                ) { action in
                    switch action {
                    case .edit: sheet = .edit(profile)
                    case .editContent: sheet = .editor(profile)
                    case .override: sheet = .override(profile)
                    case .nodes: sheet = .nodes(profile)
                    case .show(let text): sheet = .text(profile, text)
                    case .remove: pendingRemoval = profile
                    }
                }
                .transition(.rowFold)
            }
        }
        .cardSurface()
        .rowListMotion(ids: model.profiles.map(\.id))
    }
}

/// The profile's own file, or the config mihomo runs for it after po0-clash's settings are applied.
enum ProfileText: Hashable {
    case content, preview
}

private enum ProfileAction {
    case edit, editContent, override, nodes, show(ProfileText), remove
}

private struct ProfileRow: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.compactContent) private var compact
    let profile: Profile
    let columns: [ColumnWidth]
    let zebra: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let act: (ProfileAction) -> Void

    private var updating: Bool { model.updating.contains(profile.id) }

    var body: some View {
        ColumnsLayout(columns: columns, spacing: 16) {
            HStack(spacing: 8) {
                CheckMark(visible: profile.selected)
                Text(verbatim: profile.title).lineLimit(1)
            }
            .allowsHitTesting(false)
            usage.allowsHitTesting(false)
            if !compact {
                expiry.foregroundStyle(Color.ink2).lineLimit(1).allowsHitTesting(false)
            }
            HStack(spacing: 4) {
                if profile.kind == .subscription {
                    IconButton(symbol: "arrow.clockwise", help: "Update", busy: updating) {
                        model.updateProfile(profile.id)
                    }
                }
                MenuButton(placement: .belowTrailing) {
                    Image(systemName: "ellipsis").font(.system(size: 15))
                } entries: {
                    entries
                }
                .buttonStyle(IconButtonStyle())
                .help("More")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .tableRow(zebra: zebra, hit: { model.selectProfile(profile.id) })
        .contextMenu { MenuEntries(entries: entries) }
        .help(details)
    }

    private var usage: some View {
        HStack(spacing: 12) {
            if let usage = profile.usage, usage.total > 0 {
                ProgressBar(fraction: usage.fraction).frame(minWidth: 40)
            } else {
                Spacer(minLength: 0)
            }
            Text(verbatim: Format.usage(profile.usage) ?? profile.kind.name)
                .foregroundStyle(Color.ink2)
                .lineLimit(1)
                .frame(minWidth: 100, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var expiry: some View {
        if let expire = profile.usage?.expire {
            Text(Format.date(expire), format: .dateTime.year().month(.twoDigits).day(.twoDigits))
        } else {
            Text(verbatim: "—")
        }
    }

    private var details: String {
        let updated = profile.updatedAt.map { String(localized: "Updated \(Format.ago($0))") }
        guard profile.kind == .subscription else { return updated ?? "" }
        let schedule = profile.autoUpdate
            ? String(localized: "Updates every \(Int(profile.updateHours)) h")
            : String(localized: "Updates manually")
        return updated.map { "\($0) · \(schedule)" } ?? schedule
    }

    private var entries: [MenuEntry] {
        var entries: [MenuEntry] = []
        if !profile.selected {
            entries.append(.action(String(localized: "Use"), perform: { model.selectProfile(profile.id) }))
        }
        if profile.kind == .subscription {
            entries.append(.action(String(localized: "Update"), enabled: !updating, perform: {
                model.updateProfile(profile.id)
            }))
        }
        if profile.kind == .links {
            entries.append(.action(String(localized: "Nodes…"), perform: { act(.nodes) }))
        } else {
            entries.append(.action(String(localized: "Edit…"), perform: { act(.edit) }))
        }
        entries.append(.separator)
        entries.append(.action(String(localized: "Edit Content…"), perform: { act(.editContent) }))
        entries.append(.action(String(localized: "Override…"), perform: { act(.override) }))
        entries.append(.action(String(localized: "Preview Config…"), perform: { act(.show(.preview)) }))
        entries.append(.action(String(localized: "Export…"), perform: { model.exportProfile(profile) }))
        if let url = profile.url {
            entries.append(.action(String(localized: "Copy Link"), perform: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            }))
        }
        entries.append(.separator)
        entries.append(.action(String(localized: "Move Up"), enabled: canMoveUp, perform: {
            model.moveProfile(profile.id, by: -1)
        }))
        entries.append(.action(String(localized: "Move Down"), enabled: canMoveDown, perform: {
            model.moveProfile(profile.id, by: 1)
        }))
        entries.append(.separator)
        entries.append(.action(String(localized: "Delete…"), destructive: true, perform: { act(.remove) }))
        return entries
    }
}

private extension ProfileKind {
    var name: String {
        switch self {
        case .subscription: return String(localized: "Subscription")
        case .links: return String(localized: "Share links")
        case .file: return String(localized: "File")
        }
    }
}

private struct AddSubscriptionDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    @State private var url = ""
    @State private var error: String?
    @State private var working = false

    private var trimmed: String { url.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "Add Subscription")
            TextField("Subscription URL", text: $url)
                .fieldChrome(autofocus: true)
                .onSubmit(add)
            if let error { ErrorText(message: error) }
            DialogActions {
                if working { Ring() }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty || working)
            }
        }
        .frame(maxWidth: 440)
    }

    private func add() {
        guard !trimmed.isEmpty, !working else { return }
        working = true
        error = nil
        Task {
            error = await model.addSubscription(trimmed)
            working = false
            if error == nil { dismiss() }
        }
    }
}

private struct EditProfileDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    let profile: Profile
    @State private var name: String
    @State private var url: String
    @State private var autoUpdate: Bool
    @State private var hours: UInt32
    @State private var error: String?
    @State private var working = false

    init(profile: Profile) {
        self.profile = profile
        _name = State(initialValue: profile.name)
        _url = State(initialValue: profile.url ?? "")
        _autoUpdate = State(initialValue: profile.autoUpdate)
        _hours = State(initialValue: max(profile.updateHours, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "Edit Profile")
            RowGroup {
                FieldRow("Name") { TextField("Name", text: $name) }
                if profile.kind == .subscription {
                    FieldRow("URL") { TextField("URL", text: $url) }
                    ToggleRow("Auto update", isOn: $autoUpdate)
                    FieldRow("Auto-update interval (hours)") {
                        TextField("Auto-update interval (hours)", value: $hours, format: .number)
                    }
                    .disabled(!autoUpdate)
                }
            }
            if let error { ErrorText(message: error) }
            DialogActions {
                if working { Ring() }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || working)
            }
        }
        .frame(maxWidth: 480)
    }

    private func save() {
        working = true
        error = nil
        let edit = ProfileEdit(
            name: name,
            url: profile.kind == .subscription ? url : nil,
            autoUpdate: autoUpdate,
            updateHours: max(hours, 1)
        )
        Task {
            error = await model.editProfile(profile.id, edit)
            working = false
            if error == nil { dismiss() }
        }
    }
}

private struct ProfileTextDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    let profile: Profile
    let text: ProfileText
    @State private var loaded: Result<String, MessageError>?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(
                title: text == .content ? LocalizedStringKey("Profile Content") : LocalizedStringKey("Config Preview"),
                detail: profile.title
            )
            Group {
                switch loaded {
                case nil:
                    Ring().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure(let failure):
                    ErrorText(message: failure.message).frame(maxHeight: .infinity)
                case .success(let body):
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(body.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                                Text(verbatim: line.isEmpty ? " " : line)
                            }
                        }
                        .font(Ui.codeFont)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .editorChrome()
                }
            }
            HStack(spacing: 8) {
                Button("Copy") {
                    guard case .success(let body) = loaded else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(body, forType: .string)
                }
                .disabled(!loaded.isSuccess)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 640, maxHeight: 520)
        .task { loaded = await model.profileText(profile.id, text) }
    }
}

private struct ProfileEditorDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    let profile: Profile
    @State private var text = ""
    @State private var original: String?
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "Edit Content", detail: profile.title)
            CodeEditor(text: $text)
                .editorChrome()
                .disabled(original == nil)
            if let error { ErrorText(message: error) }
            HStack(spacing: 8) {
                Button("Replace with File…", action: replaceWithFile)
                    .disabled(original == nil)
                Spacer()
                if saving { Ring() }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(original == nil || text == original || saving)
            }
        }
        .frame(maxWidth: 680, maxHeight: 560)
        .task {
            switch await model.profileText(profile.id, .content) {
            case .success(let body):
                text = body
                original = body
            case .failure(let failure):
                error = failure.message
            }
        }
    }

    private func replaceWithFile() {
        let panel = NSOpenPanel()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            self.error = describe(error)
        }
    }

    private func save() {
        saving = true
        error = nil
        Task {
            error = await model.saveProfileText(profile.id, text)
            saving = false
            if error == nil { dismiss() }
        }
    }
}

/// Renames and deletes single nodes of the share-link profile.
private struct ShareNodesDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    let profile: Profile
    @State private var nodes: [ShareNode] = []
    @State private var renaming: ShareNode?
    @State private var pendingRemoval: ShareNode?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "Nodes", detail: profile.title)
            ScrollView {
                RowGroup {
                    ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                        Row {
                            Text(verbatim: node.name.isEmpty ? "—" : node.name)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(verbatim: node.kind).foregroundStyle(Color.ink2).lineLimit(1)
                            Button("Rename…") { renaming = node }
                            Button("Delete…") { pendingRemoval = node }
                                .disabled(nodes.count == 1)
                        }
                    }
                }
            }
            if let error { ErrorText(message: error) }
            DialogActions {
                Button("Done") { dismiss() }
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 520, maxHeight: 480)
        .dialog(item: $renaming) { node in
            RenameNodeDialog(name: node.name) { newName in
                change { await model.renameShareNode(profile.id, node.name, to: newName) }
            }
        }
        .dialog(item: $pendingRemoval, closesOnScrimClick: true) { node in
            ConfirmDialog(title: String(localized: "Delete \(node.name)?"), confirm: "Delete") {
                change { await model.removeShareNode(profile.id, node.name) }
            }
        }
        .task { await reload() }
    }

    private func change(_ body: @escaping () async -> String?) {
        Task {
            error = await body()
            await reload()
        }
    }

    private func reload() async {
        switch await model.shareNodes(profile.id) {
        case .success(let next): nodes = next
        case .failure(let failure): error = failure.message
        }
    }
}

private struct RenameNodeDialog: View {
    @Environment(\.dismissDialog) private var dismiss
    @State private var name: String
    let rename: (String) -> Void

    init(name: String, rename: @escaping (String) -> Void) {
        _name = State(initialValue: name)
        self.rename = rename
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "Rename Node")
            TextField("Name", text: $name).fieldChrome(autofocus: true)
            DialogActions {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename") {
                    dismiss()
                    rename(name)
                }
                .buttonStyle(ActionButtonStyle(primary: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 400)
    }
}

/// SwiftUI's TextEditor turns straight quotes and dashes into typographic ones, which breaks YAML.
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        let view = scroll.documentView as! NSTextView
        view.isRichText = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        view.textColor = .inkText
        view.insertionPointColor = .inkText
        view.textContainerInset = NSSize(width: 6, height: 8)
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.string = text
        view.delegate = context.coordinator
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        view.isEditable = context.environment.isEnabled
        if view.string != text { view.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            text.wrappedValue = view.string
        }
    }
}

private extension Optional where Wrapped == Result<String, MessageError> {
    var isSuccess: Bool {
        if case .success? = self { return true }
        return false
    }
}

private struct ImportLinksDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    @State private var text = ""
    @State private var error: String?
    @State private var imported: Int?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "Import Share Links")
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(Ui.codeFont)
                    .scrollContentBackground(.hidden)
                    .frame(height: 160)
                    .padding(4)
                if text.isEmpty {
                    Text("Paste one or more links such as vless://, vmess://, ss://, trojan:// or hysteria2://, one per line.")
                        .foregroundStyle(Color.ink3)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .allowsHitTesting(false)
                }
            }
            .editorChrome()
            if let error { ErrorText(message: error) }
            if let imported {
                Text("Imported \(imported) nodes.").foregroundStyle(Color.ink2)
            }
            DialogActions {
                if working { Ring() }
                Button(imported == nil ? LocalizedStringKey("Cancel") : LocalizedStringKey("Done")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Import", action: run)
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
            }
        }
        .frame(maxWidth: 480)
    }

    private func run() {
        working = true
        error = nil
        Task {
            switch await model.importLinks(text) {
            case .success(let count):
                imported = count
                text = ""
            case .failure(let failure):
                error = failure.message
            }
            working = false
        }
    }
}
