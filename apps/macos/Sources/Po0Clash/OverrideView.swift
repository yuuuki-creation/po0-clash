import Po0FFI
import SwiftUI

/// FlClash's per-profile override: rules added in front of the profile's own, an override script, or proxy groups
/// and rules that replace the profile's.
struct ProfileOverrideSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    @State private var draft: ProfileOverride?
    @State private var scripts: [Script] = []
    @State private var editing: ScriptSheet?
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Profile Override").font(.headline)
                Text(verbatim: profile.title).font(.caption).foregroundStyle(.secondary)
            }
            if let overrides = Binding($draft) {
                Picker("Mode", selection: overrides.mode) {
                    ForEach([OverrideMode.standard, .script, .custom], id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .themedSegments()
                .labelsHidden()
                Text(overrides.wrappedValue.mode.detail).font(.caption).foregroundStyle(.secondary)
                switch overrides.wrappedValue.mode {
                case .standard:
                    StandardOverride(overrides: overrides)
                case .script:
                    ScriptOverride(overrides: overrides, scripts: scripts) { editing = $0 }
                case .custom:
                    CustomOverride(overrides: overrides, profile: profile, error: $error)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            HStack {
                Spacer()
                if saving { ProgressView().controlSize(.small) }
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(draft == nil || saving)
            }
        }
        .padding(20)
        .frame(width: 640, height: 620)
        .sheet(item: $editing) { sheet in
            ScriptEditorSheet(script: sheet.script) { saved in
                scripts.removeAll { $0.id == saved.id }
                scripts.append(saved)
                draft?.scriptId = saved.id
            }
            .environmentObject(model)
        }
        .task {
            scripts = await model.scripts()
            switch await model.profileOverride(profile.id) {
            case .success(let saved): draft = saved
            case .failure(let failure): error = failure.message
            }
        }
    }

    private func save() {
        guard let draft else { return }
        saving = true
        error = nil
        Task {
            error = await model.saveProfileOverride(profile.id, draft)
            saving = false
            if error == nil { dismiss() }
        }
    }
}

private struct StandardOverride: View {
    @EnvironmentObject private var model: AppModel
    @Binding var overrides: ProfileOverride

    var body: some View {
        Form {
            Section {
                RulesField(rules: $overrides.addedRules).frame(height: 130)
                TextField("MATCH target", text: Binding(
                    get: { overrides.matchTarget ?? "" },
                    set: { overrides.matchTarget = $0.isEmpty ? nil : $0 }
                ), prompt: Text("Where the profile's final rule goes"))
            } header: {
                Text("Added rules")
            } footer: {
                Text("One per line, matched before the global rules and the profile's own. A rule whose target is MATCH goes to the MATCH target.")
                    .foregroundStyle(.secondary)
            }
            Section("Global rules") {
                let global = model.engineOptions?.addedRules ?? []
                if global.isEmpty {
                    Text("No global rules. Add them in Tools › Advanced.").foregroundStyle(.secondary)
                }
                ForEach(global, id: \.self) { rule in
                    Toggle(isOn: enabled(rule)) {
                        Text(verbatim: rule).font(.system(size: 12, design: .monospaced))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func enabled(_ rule: String) -> Binding<Bool> {
        Binding(
            get: { !overrides.disabledGlobalRules.contains(rule) },
            set: { on in
                overrides.disabledGlobalRules.removeAll { $0 == rule }
                if !on { overrides.disabledGlobalRules.append(rule) }
            }
        )
    }
}

private struct ScriptOverride: View {
    @Binding var overrides: ProfileOverride
    let scripts: [Script]
    let edit: (ScriptSheet) -> Void

    var body: some View {
        Form {
            Section {
                Picker("Script", selection: $overrides.scriptId) {
                    Text("None").tag(String?.none)
                    ForEach(scripts, id: \.id) { script in
                        Text(verbatim: script.name).tag(Optional(script.id))
                    }
                }
                HStack {
                    Spacer()
                    Button("Edit Script…") {
                        if let script = scripts.first(where: { $0.id == overrides.scriptId }) { edit(.edit(script)) }
                    }
                    .disabled(overrides.scriptId == nil)
                    Button("New Script…") { edit(.new) }
                }
            } footer: {
                Text("The script's main(config) gets the profile's config before po0-clash's settings and returns the config to use. Scripts are kept in Tools › Advanced.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct CustomOverride: View {
    @EnvironmentObject private var model: AppModel
    @Binding var overrides: ProfileOverride
    let profile: Profile
    @Binding var error: String?
    @State private var confirming = false

    var body: some View {
        Form {
            Section("Proxy groups") {
                CodeField(text: $overrides.customGroups).frame(height: 150)
            }
            Section {
                RulesField(rules: $overrides.customRules).frame(height: 130)
            } header: {
                Text("Rules")
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Proxy groups are a YAML list. Left empty, the profile keeps its own groups or rules.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy from Profile") {
                        if overrides.customGroups.isBlank && overrides.customRules.allSatisfy(\.isBlank) {
                            fill()
                        } else {
                            confirming = true
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .alert("Replace with the profile's own groups and rules?", isPresented: $confirming) {
            Button("Replace", role: .destructive, action: fill)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func fill() {
        Task {
            switch await model.profileGroupsAndRules(profile.id) {
            case .success(let parts):
                overrides.customGroups = parts.groups
                overrides.customRules = parts.rules
            case .failure(let failure):
                error = failure.message
            }
        }
    }
}

/// FlClash's script library in Advanced; a profile's override picks one of these.
struct ScriptsSection: View {
    let scripts: [Script]
    let edit: (ScriptSheet) -> Void
    let remove: (Script) -> Void

    var body: some View {
        Section {
            ForEach(scripts, id: \.id) { script in
                LabeledContent {
                    HStack {
                        Button("Edit…") { edit(.edit(script)) }
                        Button("Delete…") { remove(script) }
                    }
                } label: {
                    Text(verbatim: script.name)
                    Text("\(script.content.split(separator: "\n").count) lines")
                }
            }
            HStack {
                if scripts.isEmpty {
                    Text("No scripts yet.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("New Script…") { edit(.new) }
            }
        } header: {
            Text("Override scripts")
        } footer: {
            Text("A profile runs a script once you choose it in the profile's Override settings.")
                .foregroundStyle(.secondary)
        }
    }
}

enum ScriptSheet: Identifiable {
    case new, edit(Script)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let script): return script.id
        }
    }

    var script: Script? {
        if case .edit(let script) = self { return script }
        return nil
    }
}

struct ScriptEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let script: Script?
    let saved: (Script) -> Void
    @State private var name: String
    @State private var content: String
    @State private var error: String?
    @State private var saving = false

    init(script: Script?, saved: @escaping (Script) -> Void) {
        self.script = script
        self.saved = saved
        _name = State(initialValue: script?.name ?? "")
        _content = State(initialValue: script?.content ?? "function main(config) {\n  return config;\n}\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(script == nil ? LocalizedStringKey("New Script") : LocalizedStringKey("Edit Script")).font(.headline)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            CodeField(text: $content)
            Text("main(config) receives the profile's config as an object and returns the config to use.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            HStack {
                Spacer()
                if saving { ProgressView().controlSize(.small) }
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(name.isBlank || saving)
            }
        }
        .padding(20)
        .frame(width: 640, height: 520)
    }

    private func save() {
        saving = true
        error = nil
        Task {
            switch await model.saveScript(Script(id: script?.id ?? "", name: name, content: content)) {
            case .success(let script):
                saved(script)
                dismiss()
            case .failure(let failure):
                error = failure.message
            }
            saving = false
        }
    }
}

private struct RulesField: View {
    @Binding var rules: [String]

    var body: some View {
        CodeField(text: Binding(
            get: { rules.joined(separator: "\n") },
            set: { rules = $0.components(separatedBy: "\n") }
        ))
    }
}

private struct CodeField: View {
    @Binding var text: String

    var body: some View {
        CodeEditor(text: $text)
            .background(Color.tileBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.cardEdge))
    }
}

private extension OverrideMode {
    var title: LocalizedStringKey {
        switch self {
        case .standard: return "Standard"
        case .script: return "Script"
        case .custom: return "Custom"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .standard: return "Adds rules in front of the profile's own."
        case .script: return "Rewrites the profile's config with a script."
        case .custom: return "Replaces the profile's proxy groups and rules with your own."
        }
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
