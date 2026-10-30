import Po0FFI
import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var sheet: Sheet?
    @State private var pendingRemoval: Profile?

    private enum Sheet: Identifiable {
        case subscription, links
        case edit(Profile)
        case text(Profile, ProfileText)

        var id: String {
            switch self {
            case .subscription: return "subscription"
            case .links: return "links"
            case .edit(let profile): return "edit/\(profile.id)"
            case .text(let profile, let text): return "text/\(profile.id)/\(text)"
            }
        }
    }

    var body: some View {
        PageScaffold("Profiles") {
            Button {
                model.updateAllProfiles()
            } label: {
                Label("Update All", systemImage: "arrow.clockwise")
            }
            .help("Update All")
            .disabled(!model.profiles.contains { $0.kind == .subscription })
            Menu {
                Button("Add Subscription…") { sheet = .subscription }
                Button("Import Share Links…") { sheet = .links }
                Button("Import File…") { model.importProfileFile() }
                Button("Import QR Code Image…") { model.importQrCode() }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .menuIndicator(.hidden)
            .help("Add")
        } content: {
            if model.profiles.isEmpty {
                EmptyState(
                    title: "No profiles",
                    symbol: "tray",
                    detail: "Add a subscription URL, import share links or a config file."
                )
            } else {
                Form {
                    Section {
                        ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, profile in
                            ProfileRow(
                                profile: profile,
                                canMoveUp: index > 0,
                                canMoveDown: index < model.profiles.count - 1
                            ) { action in
                                switch action {
                                case .edit: sheet = .edit(profile)
                                case .show(let text): sheet = .text(profile, text)
                                case .remove: pendingRemoval = profile
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .subscription: AddSubscriptionSheet().environmentObject(model)
            case .links: ImportLinksSheet().environmentObject(model)
            case .edit(let profile): EditProfileSheet(profile: profile).environmentObject(model)
            case .text(let profile, let text): ProfileTextSheet(profile: profile, text: text).environmentObject(model)
            }
        }
        .alert(
            String(localized: "Delete \(pendingRemoval?.title ?? "")?"),
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            presenting: pendingRemoval
        ) { profile in
            Button("Delete", role: .destructive) { model.removeProfile(profile.id) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// The profile's own file, or the config mihomo runs for it after po0-clash's settings are applied.
enum ProfileText: Hashable {
    case content, preview
}

private enum ProfileAction {
    case edit, show(ProfileText), remove
}

private struct ProfileRow: View {
    @EnvironmentObject private var model: AppModel
    let profile: Profile
    let canMoveUp: Bool
    let canMoveDown: Bool
    let act: (ProfileAction) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                model.selectProfile(profile.id)
            } label: {
                Image(systemName: profile.selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(profile.selected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help("Use this profile")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(profile.title).fontWeight(.semibold).lineLimit(1)
                    Text(profile.kind.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(Color.controlFill, in: Capsule())
                }
                if let usage = profile.usage, usage.total > 0 {
                    UsageBar(usage: usage)
                } else if let expire = profile.usage?.expire {
                    Text("Expires \(Format.date(expire), format: .dateTime.year().month().day())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                details.font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if profile.kind == .subscription {
                Button {
                    model.updateProfile(profile.id)
                } label: {
                    if model.updating.contains(profile.id) {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .tint(Color.secondary)
                .frame(width: 20)
                .disabled(model.updating.contains(profile.id))
                .help("Update")
            }
            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .tint(Color.secondary)
            .fixedSize()
            .help("More")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu { actions }
    }

    private var details: Text {
        let updated = profile.updatedAt.map { Text("Updated \(Format.date($0), format: .relative(presentation: .named))") }
        guard profile.kind == .subscription else { return updated ?? Text(verbatim: "") }
        let schedule = profile.autoUpdate
            ? Text("Updates every \(Int(profile.updateHours)) h")
            : Text("Updates manually")
        return updated.map { $0 + Text(verbatim: " · ") + schedule } ?? schedule
    }

    @ViewBuilder
    private var actions: some View {
        if !profile.selected {
            Button("Use") { model.selectProfile(profile.id) }
        }
        if profile.kind == .subscription {
            Button("Update") { model.updateProfile(profile.id) }
                .disabled(model.updating.contains(profile.id))
        }
        if profile.kind != .links {
            Button("Edit…") { act(.edit) }
        }
        Divider()
        Button("View Content…") { act(.show(.content)) }
        Button("Preview Config…") { act(.show(.preview)) }
        Button("Export…") { model.exportProfile(profile) }
        if let url = profile.url {
            Button("Copy Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            }
        }
        Divider()
        Button("Move Up") { model.moveProfile(profile.id, by: -1) }
            .disabled(!canMoveUp)
        Button("Move Down") { model.moveProfile(profile.id, by: 1) }
            .disabled(!canMoveDown)
        Divider()
        Button("Delete…", role: .destructive) { act(.remove) }
    }
}

private extension ProfileKind {
    var title: LocalizedStringKey {
        switch self {
        case .subscription: return "Subscription"
        case .links: return "Share links"
        case .file: return "File"
        }
    }
}

private struct AddSubscriptionSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var error: String?
    @State private var working = false

    private var trimmed: String { url.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Subscription").font(.headline)
            TextField("Subscription URL", text: $url)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
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
                    .disabled(trimmed.isEmpty || working)
            }
        }
        .padding(20)
        .frame(width: 440)
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

private struct EditProfileSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Profile").font(.headline)
            Form {
                TextField("Name", text: $name)
                if profile.kind == .subscription {
                    TextField("URL", text: $url)
                    Toggle("Auto update", isOn: $autoUpdate)
                    TextField("Auto-update interval (hours)", value: $hours, format: .number)
                        .disabled(!autoUpdate)
                }
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            HStack {
                if working { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || working)
            }
        }
        .padding(20)
        .frame(width: 440)
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

private struct ProfileTextSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    let text: ProfileText
    @State private var loaded: Result<String, MessageError>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(text == .content ? LocalizedStringKey("Profile Content") : LocalizedStringKey("Config Preview"))
                    .font(.headline)
                Text(verbatim: profile.title).font(.caption).foregroundStyle(.secondary)
            }
            Group {
                switch loaded {
                case nil:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure(let failure):
                    Text(failure.message).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let body):
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(body.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                                Text(verbatim: line.isEmpty ? " " : line)
                            }
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .background(Color.tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.cardEdge))
                }
            }
            HStack {
                Button("Copy") {
                    guard case .success(let body) = loaded else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(body, forType: .string)
                }
                .disabled(!loaded.isSuccess)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 640, height: 520)
        .task { loaded = await model.profileText(profile.id, text) }
    }
}

private extension Optional where Wrapped == Result<String, MessageError> {
    var isSuccess: Bool {
        if case .success? = self { return true }
        return false
    }
}

private struct ImportLinksSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?
    @State private var imported: Int?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Share Links").font(.headline)
            Text("Paste one or more links such as vless://, vmess://, ss://, trojan:// or hysteria2://, one per line.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            if let imported {
                Text("Imported \(imported) nodes.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                if working { ProgressView().controlSize(.small) }
                Spacer()
                Button(imported == nil ? LocalizedStringKey("Cancel") : LocalizedStringKey("Done")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Import", action: run)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
            }
        }
        .padding(20)
        .frame(width: 480)
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
