package io.github.yuuukicreation.po0clash.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.Profile
import io.github.yuuukicreation.po0clash.core.ProfileEdit
import io.github.yuuukicreation.po0clash.core.ProfileKind
import io.github.yuuukicreation.po0clash.userMessage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private enum class ProfilePage { OVERRIDE, NODES }

@Composable
fun SubscriptionsScreen(vm: AppViewModel) {
    val profiles by vm.engine.profiles.collectAsStateWithLifecycle()
    val animate = vm.appSettings.collectAsStateWithLifecycle().value.pageAnimation
    var open by rememberSaveable { mutableStateOf<Pair<ProfilePage, String>?>(null) }
    val page = open?.takeIf { (_, id) -> profiles.any { it.id == id } }
    PushHost(page, animate, onBack = { open = null }, label = "profiles") { target ->
        val profile = target?.let { (_, id) -> profiles.firstOrNull { it.id == id } }
        val back = { open = null }
        when {
            target == null || profile == null -> ProfileList(vm, profiles) { kind, id -> open = kind to id }
            target.first == ProfilePage.OVERRIDE -> OverrideScreen(vm, profile, back)
            else -> ShareNodesScreen(vm, profile, back)
        }
    }
}

@Composable
private fun ProfileList(vm: AppViewModel, profiles: List<Profile>, onOpen: (ProfilePage, String) -> Unit) {
    val busy by vm.busy.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val add = stringResource(R.string.add)
    val importLabel = stringResource(R.string.import_file)
    val importTitle = stringResource(R.string.import_links)
    val linksHint = stringResource(R.string.share_links)
    val addTitle = stringResource(R.string.add_subscription)
    val urlHint = stringResource(R.string.subscription_url)
    val nameHint = stringResource(R.string.whitelist_name)
    val adding = AppViewModel.BUSY_PROFILES in busy
    val pickFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> uri?.let(vm::importFile) }
    var exporting by rememberSaveable { mutableStateOf<String?>(null) }
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/yaml")) { uri ->
        val id = exporting
        if (uri != null && id != null) vm.exportProfile(id, uri)
        exporting = null
    }
    val subscriptions = profiles.filter { it.kind == ProfileKind.SUBSCRIPTION }
    val anchor = rememberAnchor()
    val actions = listOf(
        PageAction(
            LineIcons.Refresh,
            stringResource(R.string.update_all),
            enabled = subscriptions.isNotEmpty(),
            busy = subscriptions.any { AppViewModel.busyProfile(it.id) in busy },
        ) { subscriptions.forEach { vm.updateProfile(it.id) } },
        PageAction(LineIcons.More, stringResource(R.string.more), enabled = !adding, anchor = anchor) {
            sheets.menu(
                anchor,
                listOf(
                    SheetAction(importLabel) { pickFile.launch(arrayOf("*/*")) },
                    SheetAction(importTitle) {
                        sheets.show { TextSheet(importTitle, linksHint, multiline = true, confirm = add) { text, _ -> vm.importLinks(text) } }
                    },
                ),
            )
        },
    )
    val fab = FabAction(LineIcons.Plus, addTitle, busy = adding) {
        sheets.show {
            TextSheet(addTitle, urlHint, multiline = false, confirm = add, namePlaceholder = nameHint) { text, name -> vm.addSubscription(text, name) }
        }
    }
    val list = rememberLazyListState()
    PageScaffold(stringResource(R.string.profiles), list, actions, fab = fab) { padding ->
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize(),
            contentPadding = padding,
        ) {
            if (profiles.isEmpty()) {
                item(key = "empty") { EmptyState(stringResource(R.string.empty_title), LineIcons.Layers) }
            }
            itemsIndexed(profiles, key = { _, profile -> profile.id }) { index, profile ->
                Box(itemMotion()) {
                    ProfileCard(
                        index,
                        profiles.size,
                        profile,
                        AppViewModel.busyProfile(profile.id) in busy,
                        vm,
                        onOpen = { onOpen(it, profile.id) },
                    ) {
                        exporting = profile.id
                        export.launch("${profile.name}.yaml")
                    }
                }
            }
        }
    }
}

private class ProfileMenu(
    val update: String,
    val edit: String,
    val nodes: String,
    val override: String,
    val preview: String,
    val export: String,
    val copyLink: String,
    val moveUp: String,
    val moveDown: String,
)

@Composable
private fun ProfileCard(
    index: Int,
    count: Int,
    profile: Profile,
    busy: Boolean,
    vm: AppViewModel,
    onOpen: (ProfilePage) -> Unit,
    onExport: () -> Unit,
) {
    val colors = palette
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
        nodes = stringResource(R.string.nodes),
        override = stringResource(R.string.override),
        preview = stringResource(R.string.preview_config),
        export = stringResource(R.string.export),
        copyLink = stringResource(R.string.copy_link),
        moveUp = stringResource(R.string.move_up),
        moveDown = stringResource(R.string.move_down),
    )
    Column(
        Modifier.fillMaxWidth().padding(top = if (index > 0) 12.dp else 0.dp).clip(RoundedCornerShape(12.dp)).background(colors.card)
            .clickable { vm.selectProfile(profile.id) }
            .padding(start = 16.dp, end = 8.dp, top = 12.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(Modifier.heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Po0Radio(profile.selected)
            Text(name, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            AppIconButton(
                if (busy) LineIcons.Refresh else LineIcons.More,
                stringResource(R.string.more),
                busy = busy,
                modifier = Modifier.anchor(anchor),
            ) {
                sheets.menu(
                    anchor,
                    listOfNotNull(
                        SheetAction(labels.update) { vm.updateProfile(profile.id) }.takeIf { subscription },
                        SheetAction(labels.edit) { sheets.show { EditSheet(profile) { vm.editProfile(profile.id, it) } } }
                            .takeIf { profile.kind != ProfileKind.LINKS },
                        SheetAction(labels.nodes) { onOpen(ProfilePage.NODES) }.takeIf { profile.kind == ProfileKind.LINKS },
                        SheetAction(labels.override) { onOpen(ProfilePage.OVERRIDE) },
                        SheetAction(labels.preview) { sheets.show { PreviewSheet(vm, profile.id) } },
                        SheetAction(labels.export, onClick = onExport),
                        SheetAction(labels.copyLink) { copy(context, profile.url.orEmpty()) }.takeIf { subscription },
                        SheetAction(labels.moveUp) { vm.moveProfile(profile.id, -1) }.takeIf { index > 0 },
                        SheetAction(labels.moveDown) { vm.moveProfile(profile.id, 1) }.takeIf { index < count - 1 },
                        SheetAction(delete, destructive = true) {
                            sheets.confirm(confirm, delete) { vm.removeProfile(profile.id) }
                        },
                    ),
                )
            }
        }
        ProfileMeta(profile)
    }
}

private fun copy(context: Context, text: String) {
    context.getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("po0-clash", text))
}

/** The usage bar when the subscription reports one, then used on the left and expiry or last update on the right. */
@Composable
private fun ProfileMeta(profile: Profile) {
    val colors = palette
    val usage = profile.usage?.takeIf { it.total > 0u }
    if (usage != null) {
        val used = usage.upload + usage.download
        val target = (used.toDouble() / usage.total.toDouble()).coerceIn(0.0, 1.0).toFloat()
        val fraction by animateFloatAsState(target, tween(300, easing = StandardEasing), label = "usage")
        Canvas(Modifier.padding(end = 8.dp).fillMaxWidth().height(4.dp)) {
            val gap = 4.dp.toPx()
            val radius = CornerRadius(2.dp.toPx())
            val end = size.width * fraction
            drawRoundRect(colors.sel, Offset(end + gap, 0f), Size((size.width - end - gap).coerceAtLeast(0f), size.height), radius)
            drawRoundRect(colors.accent, Offset.Zero, Size(end, size.height), radius)
            drawCircle(colors.accent, size.height / 2, Offset(size.width - size.height / 2, size.height / 2))
        }
    }
    val left = when {
        usage != null -> "${bytes(usage.upload + usage.download)} / ${bytes(usage.total)}"
        profile.kind == ProfileKind.FILE -> stringResource(R.string.file_profile)
        else -> null
    }
    val right = usage?.expire?.takeIf { it > 0 }?.let { date(it) }
        ?: profile.updatedAt?.let { stringResource(R.string.updated, relativeTime(it)) }
    if (left != null || right != null) {
        Row(Modifier.padding(end = 8.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(left.orEmpty(), style = MaterialTheme.typography.bodyMedium.tabular(), color = colors.ink2, maxLines = 1)
            Text(right.orEmpty(), style = MaterialTheme.typography.bodyMedium.tabular(), color = colors.ink2, maxLines = 1)
        }
    }
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
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.auto_update), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
            Po0Switch(auto, { auto = it })
        }
        if (auto) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.update_interval), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                Box(Modifier.width(96.dp)) {
                    SheetField(hours, { hours = it.filter(Char::isDigit).take(4) }, "24", multiline = false, keyboardType = KeyboardType.Number)
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
        Modifier.fillMaxWidth().heightIn(min = 120.dp, max = 460.dp).clip(RoundedCornerShape(4.dp)).background(palette.card)
            .verticalScroll(rememberScrollState()).horizontalScroll(rememberScrollState()).padding(12.dp),
    ) {
        val content = text
        if (content == null) {
            SmallProgress()
        } else {
            Text(content, style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace), softWrap = false)
        }
    }
    SheetButtons(stringResource(R.string.copy), enabled = text != null, onCancel = sheets::dismiss) {
        copy(context, text.orEmpty())
        sheets.dismiss()
    }
}

@Composable
fun profileName(kind: ProfileKind, name: String): String =
    if (kind == ProfileKind.LINKS) stringResource(R.string.links_profile) else name
