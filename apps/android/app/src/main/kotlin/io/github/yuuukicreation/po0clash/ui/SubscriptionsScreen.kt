package io.github.yuuukicreation.po0clash.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.chrisbanes.haze.hazeSource
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Profile
import io.github.yuuukicreation.po0clash.core.ProfileEdit
import io.github.yuuukicreation.po0clash.core.ProfileKind
import io.github.yuuukicreation.po0clash.userMessage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
fun SubscriptionsScreen(vm: AppViewModel) {
    val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val add = stringResource(R.string.add)
    val importTitle = stringResource(R.string.import_links)
    val linksHint = stringResource(R.string.share_links)
    val addTitle = stringResource(R.string.add_subscription)
    val urlHint = stringResource(R.string.subscription_url)
    val adding = AppViewModel.BUSY_PROFILES in busy
    val pickFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> uri?.let(vm::importFile) }
    var exporting by rememberSaveable { mutableStateOf<String?>(null) }
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/yaml")) { uri ->
        val id = exporting
        if (uri != null && id != null) vm.exportProfile(id, uri)
        exporting = null
    }
    val actions = listOf(
        PageAction(LineIcons.FileImport, stringResource(R.string.import_file), enabled = !adding) { pickFile.launch(arrayOf("*/*")) },
        PageAction(LineIcons.Link, importTitle, enabled = !adding) {
            sheets.show { TextSheet(importTitle, linksHint, multiline = true, confirm = add) { text, _ -> vm.importLinks(text) } }
        },
        PageAction(LineIcons.Plus, addTitle, busy = adding) {
            sheets.show { TextSheet(addTitle, urlHint, multiline = false, confirm = add) { text, _ -> vm.addSubscription(text) } }
        },
    )

    val list = rememberLazyListState()
    PageScaffold(stringResource(R.string.profiles), list, actions) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize().hazeSource(checkNotNull(LocalHaze.current)),
            contentPadding = padding,
        ) {
            item { PageTitle(stringResource(R.string.profiles)) }
            if (profiles.isEmpty()) {
                item { EmptyCard(stringResource(R.string.empty_title), stringResource(R.string.empty_body)) }
            }
            itemsIndexed(profiles, key = { _, profile -> profile.id }) { index, profile ->
                ProfileRow(index, profiles.size, profile, AppViewModel.busyProfile(profile.id) in busy, vm) {
                    exporting = profile.id
                    export.launch("${profile.name}.yaml")
                }
            }
        }
    }
}

@Composable
private fun ProfileRow(index: Int, count: Int, profile: Profile, busy: Boolean, vm: AppViewModel, onExport: () -> Unit) {
    val sheets = LocalSheets.current
    val context = LocalContext.current
    val anchor = rememberAnchor()
    val name = profileName(profile.kind, profile.name)
    val subscription = profile.kind == ProfileKind.SUBSCRIPTION
    val delete = stringResource(R.string.delete)
    val confirm = stringResource(R.string.delete_title, name)
    val labels = ProfileMenu(
        update = stringResource(R.string.update),
        edit = stringResource(R.string.edit),
        preview = stringResource(R.string.preview_config),
        export = stringResource(R.string.export),
        copyLink = stringResource(R.string.copy_link),
        moveUp = stringResource(R.string.move_up),
        moveDown = stringResource(R.string.move_down),
    )
    GroupRow(index, count, onClick = { vm.selectProfile(profile.id) }) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Column {
                Text(name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                val source = when (profile.kind) {
                    ProfileKind.SUBSCRIPTION -> listOfNotNull(
                        profile.url?.let { Uri.parse(it).host },
                        stringResource(R.string.auto_update_every, profile.updateHours.toInt()).takeIf { profile.autoUpdate },
                    ).joinToString(" · ").ifEmpty { null }
                    ProfileKind.FILE -> stringResource(R.string.file_profile)
                    ProfileKind.LINKS -> null
                }
                source?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = apple.secondaryLabel, maxLines = 1) }
            }
            ProfileUsage(profile, showUpdated = true)
        }
        Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
            if (profile.selected) {
                Icon(LineIcons.Check, contentDescription = stringResource(R.string.selected), tint = apple.accent, modifier = Modifier.size(22.dp))
            }
        }
        Box(Modifier.size(36.dp).anchor(anchor), contentAlignment = Alignment.Center) {
            if (busy) {
                SmallProgress()
            } else {
                IconButton(
                    onClick = {
                        sheets.menu(
                            anchor,
                            name,
                            listOfNotNull(
                                SheetAction(labels.update) { vm.updateProfile(profile.id) }.takeIf { subscription },
                                SheetAction(labels.edit) { sheets.show { EditSheet(profile) { vm.editProfile(profile.id, it) } } }
                                    .takeIf { profile.kind != ProfileKind.LINKS },
                                SheetAction(labels.preview) { sheets.show { PreviewSheet(vm, profile.id) } },
                                SheetAction(labels.export, onClick = onExport),
                                SheetAction(labels.copyLink) { copy(context, profile.url.orEmpty()) }.takeIf { subscription },
                                SheetAction(labels.moveUp) { vm.moveProfile(profile.id, -1) }.takeIf { index > 0 },
                                SheetAction(labels.moveDown) { vm.moveProfile(profile.id, 1) }.takeIf { index < count - 1 },
                                SheetAction(delete, destructive = true) {
                                    sheets.menu(anchor, confirm, listOf(SheetAction(delete, destructive = true) { vm.removeProfile(profile.id) }))
                                },
                            ),
                        )
                    },
                ) {
                    Icon(LineIcons.More, contentDescription = stringResource(R.string.more), tint = apple.accent)
                }
            }
        }
    }
}

private class ProfileMenu(
    val update: String,
    val edit: String,
    val preview: String,
    val export: String,
    val copyLink: String,
    val moveUp: String,
    val moveDown: String,
)

private fun copy(context: Context, text: String) {
    context.getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("po0-clash", text))
}

@Composable
private fun EditSheet(profile: Profile, onSave: (ProfileEdit) -> Unit) {
    val sheets = LocalSheets.current
    val subscription = profile.kind == ProfileKind.SUBSCRIPTION
    var name by rememberSaveable { mutableStateOf(profile.name) }
    var url by rememberSaveable { mutableStateOf(profile.url.orEmpty()) }
    var auto by rememberSaveable { mutableStateOf(profile.autoUpdate) }
    var hours by rememberSaveable { mutableStateOf(profile.updateHours.coerceAtLeast(1u).toString()) }
    val interval = hours.toUIntOrNull()?.takeIf { it > 0u }
    SheetTitle(stringResource(R.string.edit_profile))
    SheetField(name, { name = it }, stringResource(R.string.whitelist_name), multiline = false, keyboardType = KeyboardType.Text)
    if (subscription) {
        SheetField(url, { url = it }, stringResource(R.string.subscription_url), multiline = false)
        Column(Modifier.clip(RoundedCornerShape(12.dp)).background(apple.card)) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.auto_update), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                AppleSwitch(auto, { auto = it })
            }
            if (auto) {
                Hairline(Modifier.padding(start = 16.dp))
                Row(Modifier.fillMaxWidth().padding(start = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.update_interval), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                    Box(Modifier.width(96.dp)) {
                        SheetField(hours, { hours = it.filter(Char::isDigit).take(4) }, "24", multiline = false, keyboardType = KeyboardType.Number)
                    }
                }
            }
        }
    }
    SheetButtons(
        stringResource(R.string.save),
        enabled = name.isNotBlank() && (!subscription || url.isNotBlank()) && interval != null,
        onCancel = sheets::dismiss,
    ) {
        sheets.dismiss()
        onSave(ProfileEdit(name, url.takeIf { subscription }, auto, interval ?: profile.updateHours))
    }
}

/** The config the engine would run for this profile, secrets already hidden by the core. */
@Composable
private fun PreviewSheet(vm: AppViewModel, id: String) {
    val sheets = LocalSheets.current
    val context = LocalContext.current
    val text by produceState<String?>(null, id) {
        value = withContext(Dispatchers.IO) { runCatching { vm.engine.core.previewConfig(id) }.getOrElse { it.userMessage() } }
    }
    SheetTitle(stringResource(R.string.preview_config))
    Box(
        Modifier.fillMaxWidth().heightIn(min = 120.dp, max = 460.dp).clip(RoundedCornerShape(12.dp)).background(apple.card)
            .verticalScroll(rememberScrollState()).horizontalScroll(rememberScrollState()).padding(12.dp),
    ) {
        val content = text
        if (content == null) {
            SmallProgress()
        } else {
            Text(content, style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace), softWrap = false)
        }
    }
    SheetButtons(stringResource(R.string.copy), enabled = text != null, onCancel = sheets::dismiss) {
        copy(context, text.orEmpty())
        sheets.dismiss()
    }
}

/** The usage bar with used / total and expiry, then optionally when the profile was last updated. */
@Composable
fun ProfileUsage(profile: Profile, showUpdated: Boolean = false) {
    val colors = apple
    val usage = profile.usage
    if (usage != null && usage.total > 0u) {
        val used = usage.upload + usage.download
        val fraction = (used.toDouble() / usage.total.toDouble()).coerceIn(0.0, 1.0).toFloat()
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.fillMaxWidth().height(6.dp).background(colors.track, CircleShape)) {
                Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().background(colors.accent, CircleShape))
            }
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    stringResource(R.string.usage, bytes(used), bytes(usage.total)),
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.secondaryLabel,
                    modifier = Modifier.padding(end = 12.dp),
                )
                usage.expire?.takeIf { it > 0 }?.let {
                    Text(stringResource(R.string.expires, date(it)), style = MaterialTheme.typography.bodySmall, color = colors.secondaryLabel)
                }
            }
        }
    }
    if (showUpdated) {
        profile.updatedAt?.let {
            Text(stringResource(R.string.updated, relativeTime(it)), style = MaterialTheme.typography.bodySmall, color = colors.secondaryLabel)
        }
    }
}

@Composable
fun profileName(kind: ProfileKind, name: String): String =
    if (kind == ProfileKind.LINKS) stringResource(R.string.links_profile) else name
