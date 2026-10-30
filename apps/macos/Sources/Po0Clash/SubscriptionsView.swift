import Po0FFI
import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var sheet: Sheet?
    @State private var pendingRemoval: Profile?

    private enum Sheet: Identifiable {
        case subscription, links
        var id: Self { self }
    }

    var body: some View {
        PageScaffold("Subscriptions") {
            Button {
                sheet = .links
            } label: {
                Label("Import Share Links…", systemImage: "link")
            }
            Button {
                sheet = .subscription
            } label: {
                Label("Add Subscription…", systemImage: "plus")
            }
        } content: {
            if model.profiles.isEmpty {
                EmptyRow(title: "No subscriptions", detail: "Add a subscription URL or import share links.").groupedSection()
            } else {
                VStack(spacing: 12) {
                    ForEach(model.profiles, id: \.id) { profile in
                        ProfileRow(profile: profile) { pendingRemoval = profile }
                    }
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .subscription: AddSubscriptionSheet().environmentObject(model)
            case .links: ImportLinksSheet().environmentObject(model)
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

private struct ProfileRow: View {
    @EnvironmentObject private var model: AppModel
    let profile: Profile
    let remove: () -> Void

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
            .help("Use this subscription")

            VStack(alignment: .leading, spacing: 6) {
                Text(profile.title).fontWeight(.semibold).lineLimit(1)
                if let usage = profile.usage, usage.total > 0 {
                    UsageBar(usage: usage)
                } else if let expire = profile.usage?.expire {
                    Text("Expires \(Format.date(expire), format: .dateTime.year().month().day())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let updated = profile.updatedAt {
                    Text("Updated \(Format.date(updated), format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                .frame(width: 20)
                .disabled(model.updating.contains(profile.id))
                .help("Update")
            }
            Button(action: remove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete")
        }
        .groupedSection()
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(profile.selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
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
