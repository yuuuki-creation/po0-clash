import Po0FFI
import SwiftUI

extension Script: Identifiable {}

/// FlClash's per-profile override: rules added in front of the profile's own, an override script, or proxy groups
/// and rules that replace the profile's.
struct ProfileOverrideDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
    let profile: Profile
    @State private var draft: ProfileOverride?
    @State private var scripts: [Script] = []
    @State private var editing: ScriptSheet?
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: "Profile Override", detail: profile.title)
            if let overrides = Binding($draft) {
                SegmentedControl(
                    selection: overrides.mode,
                    segments: [OverrideMode.standard, .script, .custom].map { Segment($0, $0.title) }
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: Ui.block) {
                        switch overrides.wrappedValue.mode {
                        case .standard:
                            StandardOverride(overrides: overrides)
                        case .script:
                            ScriptOverride(overrides: overrides, scripts: scripts) { editing = $0 }
                        case .custom:
                            CustomOverride(overrides: overrides, profile: profile, error: $error)
                        }
                    }
                }
            } else {
                Ring().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let error { ErrorText(message: error) }
            DialogActions {
                if saving { Ring() }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(draft == nil || saving)
            }
        }
        .frame(maxWidth: 640, maxHeight: 620)
        .dialog(item: $editing) { sheet in
            ScriptEditorDialog(script: sheet.script) { saved in
                scripts.removeAll { $0.id == saved.id }
                scripts.append(saved)
                draft?.scriptId = saved.id
            }
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
        SettingsSection("Added rules") {
            RulesField(rules: $overrides.addedRules)
                .frame(height: 130)
                .padding(Ui.padding)
            FieldRow("MATCH target") {
                TextField("MATCH target", text: Binding(
                    get: { overrides.matchTarget ?? "" },
                    set: { overrides.matchTarget = $0.isEmpty ? nil : $0 }
                ), prompt: Text("Where the profile's final rule goes"))
            }
        }
        let global = model.engineOptions?.addedRules ?? []
        if !global.isEmpty {
            SettingsSection("Global rules") {
                ForEach(global, id: \.self) { rule in
                    ToggleRow(verbatim: rule, isOn: enabled(rule)).font(Ui.codeFont)
                }
            }
        }
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
        RowGroup {
            OptionRow(
                "Script",
                selection: $overrides.scriptId,
                options: [Option<String?>(nil, String(localized: "None"))]
                    + scripts.map { Option<String?>($0.id, $0.name) }
            )
            Row {
                Spacer()
                Button("Edit Script…") {
                    if let script = scripts.first(where: { $0.id == overrides.scriptId }) { edit(.edit(script)) }
                }
                .disabled(overrides.scriptId == nil)
                Button("New Script…") { edit(.new) }
            }
        }
    }
}

private struct CustomOverride: View {
    @EnvironmentObject private var model: AppModel
    @Binding var overrides: ProfileOverride
    let profile: Profile
    @Binding var error: String?
    @State private var confirming = false

    var body: some View {
        SettingsSection("Proxy groups") {
            CodeField(text: $overrides.customGroups)
                .frame(height: 150)
                .padding(Ui.padding)
        }
        SettingsSection("Rules") {
            RulesField(rules: $overrides.customRules)
                .frame(height: 130)
                .padding(Ui.padding)
        }
        DialogActions {
            Button("Copy from Profile") {
                if overrides.customGroups.isBlank && overrides.customRules.allSatisfy(\.isBlank) {
                    fill()
                } else {
                    confirming = true
                }
            }
        }
        .dialog(isPresented: $confirming, closesOnScrimClick: true) {
            ConfirmDialog(title: String(localized: "Replace with the profile's own groups and rules?"), confirm: "Replace") {
                fill()
            }
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
        SettingsSection("Override scripts") {
            ForEach(scripts, id: \.id) { script in
                Row {
                    Text(verbatim: script.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(script.content.split(separator: "\n").count) lines").foregroundStyle(Color.ink2)
                    Button("Edit…") { edit(.edit(script)) }
                    Button("Delete…") { remove(script) }
                }
            }
            Row {
                if scripts.isEmpty {
                    Text("No scripts yet.").foregroundStyle(Color.ink2)
                }
                Spacer()
                Button("New Script…") { edit(.new) }
            }
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

struct ScriptEditorDialog: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissDialog) private var dismiss
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
        VStack(alignment: .leading, spacing: 14) {
            DialogTitle(title: script == nil ? LocalizedStringKey("New Script") : LocalizedStringKey("Edit Script"))
            TextField("Name", text: $name).fieldChrome(autofocus: true)
            CodeField(text: $content)
            if let error { ErrorText(message: error) }
            DialogActions {
                if saving { Ring() }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(name.isBlank || saving)
            }
        }
        .frame(maxWidth: 640, maxHeight: 520)
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
        CodeEditor(text: $text).editorChrome()
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
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
