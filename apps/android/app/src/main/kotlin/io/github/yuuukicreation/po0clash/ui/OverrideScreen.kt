package io.github.yuuukicreation.po0clash.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.OverrideMode
import io.github.yuuukicreation.po0clash.core.Profile
import io.github.yuuukicreation.po0clash.core.ProfileOverride
import io.github.yuuukicreation.po0clash.core.Script

private const val RULE_HINT = "DOMAIN-SUFFIX,example.com,DIRECT"
private const val GROUPS_HINT = "- name: Proxy\n  type: select\n  proxies: [DIRECT]"
private const val SCRIPT_TEMPLATE = "function main(config) {\n  return config;\n}\n"

private val OverrideMode.label
    get() = when (this) {
        OverrideMode.STANDARD -> R.string.override_standard
        OverrideMode.SCRIPT -> R.string.override_script
        OverrideMode.CUSTOM -> R.string.override_custom
    }

/** FlClash's per-profile override; every change is saved at once and undone if the core rejects it. */
@Composable
fun OverrideScreen(vm: AppViewModel, profile: Profile, onBack: () -> Unit) {
    var draft by remember(profile.id) { mutableStateOf<ProfileOverride?>(null) }
    LaunchedEffect(profile.id) {
        vm.loadScripts()
        draft = vm.profileOverride(profile.id)
    }
    val options by vm.options.collectAsStateWithLifecycle()
    val scripts by vm.scripts.collectAsStateWithLifecycle()
    val status by vm.engine.status.collectAsStateWithLifecycle()
    val groups by vm.engine.groups.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val save = { next: ProfileOverride ->
        draft = next
        vm.setProfileOverride(profile.id, next) { draft = it }
    }
    val targets = if (status.profileId == profile.id) groups.map { it.name } else emptyList()
    ToolPage(
        stringResource(R.string.override),
        onBack,
        actions = listOf(PageAction(LineIcons.Check, stringResource(R.string.saving), enabled = false, busy = true) {})
            .filter { AppViewModel.busyOverride(profile.id) in busy },
    ) {
        val current = draft
        if (current == null) {
            item { Box(Modifier.fillMaxWidth().padding(top = 48.dp), contentAlignment = Alignment.Center) { SmallProgress() } }
            return@ToolPage
        }
        item {
            SectionHeader(stringResource(R.string.override_mode))
            SegmentedPicker(
                OverrideMode.entries.map { it to stringResource(it.label) },
                current.mode,
                enabled = true,
            ) { save(current.copy(mode = it)) }
        }
        when (current.mode) {
            OverrideMode.STANDARD -> standardOverride(current, options.addedRules, targets, save)
            OverrideMode.SCRIPT -> scriptOverride(vm, current, scripts, save)
            OverrideMode.CUSTOM -> customOverride(vm, profile.id, current, save, latest = { draft })
        }
    }
}

private fun LazyListScope.standardOverride(
    current: ProfileOverride,
    global: List<String>,
    targets: List<String>,
    save: (ProfileOverride) -> Unit,
) {
    item {
        SectionHeader(stringResource(R.string.added_rules))
        ListRow(stringResource(R.string.added_rules), current.addedRules, RULE_HINT, code = true) {
            save(current.copy(addedRules = it))
        }
        val label = stringResource(R.string.match_target)
        val default = stringResource(R.string.match_target_default)
        if (targets.isEmpty()) {
            EditRow(label, current.matchTarget.orEmpty(), placeholder = default) {
                save(current.copy(matchTarget = it.ifEmpty { null }))
            }
        } else {
            val options = listOf<String?>(null, "DIRECT", "REJECT") + (targets - setOf("DIRECT", "REJECT")) +
                listOfNotNull(current.matchTarget?.takeIf { it !in targets && it != "DIRECT" && it != "REJECT" })
            ChoiceRow(label, options.map { it to (it ?: default) }, current.matchTarget) {
                save(current.copy(matchTarget = it))
            }
        }
    }
    item { SectionHeader(stringResource(R.string.global_rules)) }
    if (global.isEmpty()) {
        item {
            GroupRow {
                Text(stringResource(R.string.none), style = MaterialTheme.typography.bodyLarge, color = palette.ink2)
            }
        }
    }
    items(global) { rule ->
        GroupRow {
            Text(
                rule,
                style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                modifier = Modifier.weight(1f),
            )
            Po0Switch(rule !in current.disabledGlobalRules, { on ->
                val others = current.disabledGlobalRules - rule
                save(current.copy(disabledGlobalRules = if (on) others else others + rule))
            })
        }
    }
}

private fun LazyListScope.scriptOverride(
    vm: AppViewModel,
    current: ProfileOverride,
    scripts: List<Script>,
    save: (ProfileOverride) -> Unit,
) {
    item {
        val sheets = LocalSheets.current
        val chosen = scripts.firstOrNull { it.id == current.scriptId }
        val rows = listOf<Script?>(null) + scripts
        SectionHeader(stringResource(R.string.script))
        rows.forEach { script ->
            GroupRow(onClick = { save(current.copy(scriptId = script?.id)) }) {
                Po0Radio(script?.id == current.scriptId)
                Text(
                    script?.name ?: stringResource(R.string.none),
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        if (chosen != null) {
            ActionRow(stringResource(R.string.edit_script)) { sheets.show { ScriptSheet(vm, chosen) } }
        }
        ActionRow(stringResource(R.string.new_script)) {
            sheets.show { ScriptSheet(vm, null) { save(current.copy(scriptId = it.id)) } }
        }
    }
}

private fun LazyListScope.customOverride(
    vm: AppViewModel,
    id: String,
    current: ProfileOverride,
    save: (ProfileOverride) -> Unit,
    latest: () -> ProfileOverride?,
) {
    item {
        val sheets = LocalSheets.current
        val title = stringResource(R.string.proxy_groups)
        val lines = current.customGroups.lines().count(String::isNotBlank)
        SectionHeader(title)
        NavRow(title, if (lines == 0) stringResource(R.string.not_set) else pluralStringResource(R.plurals.line_count, lines, lines)) {
            sheets.show {
                ValueSheet(title, current.customGroups, multiline = true, hint = GROUPS_HINT, code = true) {
                    save(current.copy(customGroups = it))
                }
            }
        }
        SectionHeader(stringResource(R.string.rules))
        ListRow(stringResource(R.string.rules), current.customRules, RULE_HINT, code = true) {
            save(current.copy(customRules = it))
        }
    }
    item {
        val sheets = LocalSheets.current
        val copy = { vm.copyProfileParts(id) { groups, rules -> latest()?.let { save(it.copy(customGroups = groups, customRules = rules)) } } }
        val replace = stringResource(R.string.replace)
        val confirm = stringResource(R.string.copy_from_profile_confirm)
        Column(Modifier.padding(top = 12.dp)) {
            ActionRow(stringResource(R.string.copy_from_profile)) {
                if (current.customGroups.isBlank() && current.customRules.isEmpty()) {
                    copy()
                } else {
                    sheets.confirm(confirm, replace) { copy() }
                }
            }
        }
    }
}

/** A new script when [script] is null; the sheet stays open until the core accepts the script. */
@Composable
fun ScriptSheet(vm: AppViewModel, script: Script?, onSaved: (Script) -> Unit = {}) {
    val sheets = LocalSheets.current
    var name by rememberSaveable { mutableStateOf(script?.name.orEmpty()) }
    var content by rememberSaveable { mutableStateOf(script?.content ?: SCRIPT_TEMPLATE) }
    val busy by vm.busy.collectAsStateWithLifecycle()
    SheetTitle(stringResource(if (script == null) R.string.new_script else R.string.edit_script))
    SheetField(name, { name = it }, stringResource(R.string.script_name), multiline = false, keyboardType = KeyboardType.Text)
    SheetField(content, { content = it }, SCRIPT_TEMPLATE, multiline = true, code = true)
    SheetButtons(
        stringResource(R.string.save),
        enabled = name.isNotBlank() && AppViewModel.BUSY_SCRIPT !in busy,
        onCancel = sheets::dismiss,
    ) {
        vm.saveScript(Script(script?.id.orEmpty(), name, content)) {
            sheets.dismiss()
            onSaved(it)
        }
    }
}

/** FlClash's script library under Advanced; a profile's override picks one of these. */
@Composable
fun ScriptLibrary(vm: AppViewModel) {
    val sheets = LocalSheets.current
    val scripts by vm.scripts.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { vm.loadScripts() }
    SectionHeader(stringResource(R.string.override_scripts))
    scripts.forEach { script -> ScriptRow(script, vm) }
    ActionRow(stringResource(R.string.new_script)) { sheets.show { ScriptSheet(vm, null) } }
}

@Composable
private fun ScriptRow(script: Script, vm: AppViewModel) {
    val sheets = LocalSheets.current
    val anchor = rememberAnchor()
    val lines = script.content.lines().count(String::isNotBlank)
    val edit = stringResource(R.string.edit)
    val delete = stringResource(R.string.delete)
    val confirm = stringResource(R.string.delete_title, script.name)
    Column(Modifier.anchor(anchor)) {
        NavRow(script.name, pluralStringResource(R.plurals.line_count, lines, lines)) {
            sheets.menu(
                anchor,
                listOf(
                    SheetAction(edit) { sheets.show { ScriptSheet(vm, script) } },
                    SheetAction(delete, destructive = true) {
                        sheets.confirm(confirm, delete) { vm.removeScript(script.id) }
                    },
                ),
            )
        }
    }
}

/** The nodes of the share-link profile, renamed and removed one at a time; the last one goes with the profile. */
@Composable
fun ShareNodesScreen(vm: AppViewModel, profile: Profile, onBack: () -> Unit) {
    val sheets = LocalSheets.current
    val nodes by vm.shareNodes.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    LaunchedEffect(profile.id, profile.updatedAt) { vm.loadShareNodes(profile.id) }
    val importTitle = stringResource(R.string.import_links)
    val linksHint = stringResource(R.string.share_links)
    val add = stringResource(R.string.add)
    ToolPage(
        stringResource(R.string.nodes),
        onBack,
        actions = listOf(
            PageAction(LineIcons.Plus, importTitle, busy = AppViewModel.busyProfile(profile.id) in busy) {
                sheets.show { TextSheet(importTitle, linksHint, multiline = true, confirm = add) { text, _ -> vm.importLinks(text) } }
            },
        ),
    ) {
        items(nodes, key = { node -> node.name }) { node ->
            Box(itemMotion()) {
                ShareNodeRow(node.name, node.kind, nodes.size > 1, vm, profile.id)
            }
        }
    }
}

@Composable
private fun ShareNodeRow(name: String, kind: String, deletable: Boolean, vm: AppViewModel, id: String) {
    val sheets = LocalSheets.current
    val anchor = rememberAnchor()
    val rename = stringResource(R.string.rename)
    val delete = stringResource(R.string.delete)
    val confirm = stringResource(R.string.delete_title, name)
    Column(Modifier.anchor(anchor)) {
        GroupRow(onClick = {
                sheets.menu(
                    anchor,
                    listOfNotNull(
                        SheetAction(rename) {
                            sheets.show {
                                ValueSheet(rename, name, multiline = false, validate = String::isNotEmpty) { vm.renameShareNode(id, name, it) }
                            }
                        },
                        SheetAction(delete, destructive = true) {
                            sheets.confirm(confirm, delete) { vm.removeShareNode(id, name) }
                        }.takeIf { deletable },
                    ),
                )
            },
        ) {
            RowText(name)
            Text(kind.uppercase(), style = MaterialTheme.typography.bodyMedium, color = palette.ink2)
        }
    }
}
