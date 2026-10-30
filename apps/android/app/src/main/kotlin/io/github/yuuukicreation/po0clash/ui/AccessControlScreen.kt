package io.github.yuuukicreation.po0clash.ui

import android.Manifest
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.graphics.drawable.toBitmap
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.AccessMode
import io.github.yuuukicreation.po0clash.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private class InstalledApp(val packageName: String, val label: String, val system: Boolean, val internet: Boolean, val info: ApplicationInfo)

/** FlClash's per-app proxy: proxy only the chosen apps, or everything except them. */
@Composable
fun AccessControlScreen(vm: AppViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val settings by vm.androidSettings.collectAsStateWithLifecycle()
    val clipboard = LocalClipboardManager.current
    val sheets = LocalSheets.current
    var query by rememberSaveable { mutableStateOf("") }
    var showSystem by rememberSaveable { mutableStateOf(false) }
    var onlyInternet by rememberSaveable { mutableStateOf(true) }
    var selectedFirst by rememberSaveable { mutableStateOf(true) }
    val apps by produceState<List<InstalledApp>?>(null) {
        value = withContext(Dispatchers.IO) { installedApps(context.packageManager, context.packageName) }
    }
    val chosen = settings.accessPackages
    val shown = apps.orEmpty()
        .filter { (showSystem || !it.system) && (!onlyInternet || it.internet) }
        .filter { query.isBlank() || it.label.contains(query.trim(), ignoreCase = true) || it.packageName.contains(query.trim(), ignoreCase = true) }
        .sortedWith(compareBy<InstalledApp> { selectedFirst && it.packageName !in chosen }.thenBy { it.label.lowercase() })
    val modes = AccessMode.entries.map { it to stringResource(it.label) }

    val filterAnchor = rememberAnchor()
    val moreAnchor = rememberAnchor()
    val filterTitle = stringResource(R.string.filter)
    val moreTitle = stringResource(R.string.more)
    val filterLabels = listOf(stringResource(R.string.show_system_apps), stringResource(R.string.only_internet_apps), stringResource(R.string.selected_first))
    val moreLabels = listOf(stringResource(R.string.select_all), stringResource(R.string.clear_selection), stringResource(R.string.copy_to_clipboard), stringResource(R.string.paste_from_clipboard))
    val actions = listOf(
        PageAction(LineIcons.Sliders, filterTitle, enabled = settings.accessMode != AccessMode.OFF, anchor = filterAnchor) {
            sheets.menu(
                filterAnchor,
                filterTitle,
                listOf(
                    SheetAction(filterLabels[0], checked = showSystem) { showSystem = !showSystem },
                    SheetAction(filterLabels[1], checked = onlyInternet) { onlyInternet = !onlyInternet },
                    SheetAction(filterLabels[2], checked = selectedFirst) { selectedFirst = !selectedFirst },
                ),
            )
        },
        PageAction(LineIcons.More, moreTitle, enabled = settings.accessMode != AccessMode.OFF, anchor = moreAnchor) {
            sheets.menu(
                moreAnchor,
                null,
                listOf(
                    SheetAction(moreLabels[0]) { vm.updateAndroid { s -> s.copy(accessPackages = s.accessPackages + shown.map { it.packageName }) } },
                    SheetAction(moreLabels[1]) { vm.updateAndroid { it.copy(accessPackages = emptySet()) } },
                    SheetAction(moreLabels[2]) { clipboard.setText(AnnotatedString(chosen.sorted().joinToString("\n"))) },
                    SheetAction(moreLabels[3]) {
                        val pasted = clipboard.getText()?.text.orEmpty().split('\n', ',', ' ').map(String::trim).filter(String::isNotEmpty)
                        if (pasted.isNotEmpty()) vm.updateAndroid { it.copy(accessPackages = pasted.toSet()) }
                    },
                ),
            )
        },
    )
    ToolPage(
        stringResource(R.string.access_control),
        onBack,
        actions,
        subtitle = pluralStringResource(R.plurals.app_count, chosen.size, chosen.size).takeIf { settings.accessMode != AccessMode.OFF },
    ) {
        item {
            Column(Modifier.padding(bottom = 4.dp)) {
                ChoiceRow(0, 1, stringResource(R.string.access_mode), modes, settings.accessMode) { v -> vm.updateAndroid { it.copy(accessMode = v) } }
                SectionFooter(stringResource(R.string.access_mode_detail))
            }
        }
        if (settings.accessMode == AccessMode.OFF) return@ToolPage
        item(key = "search") {
            Box(Modifier.padding(top = 16.dp, bottom = 12.dp)) { SearchField(query) { query = it } }
        }
        if (apps == null) {
            item { ValueRow(0, 1, stringResource(R.string.loading), "") }
        }
        itemsIndexed(shown, key = { _, app -> app.packageName }) { index, app ->
            AppRow(index, shown.size, app, app.packageName in chosen) { on ->
                vm.updateAndroid { s -> s.copy(accessPackages = if (on) s.accessPackages + app.packageName else s.accessPackages - app.packageName) }
            }
        }
    }
}

private fun installedApps(pm: PackageManager, self: String): List<InstalledApp> {
    @Suppress("DEPRECATION")
    val packages: List<PackageInfo> = pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
    return packages.mapNotNull { pkg ->
        val info = pkg.applicationInfo ?: return@mapNotNull null
        if (pkg.packageName == self) return@mapNotNull null
        InstalledApp(
            packageName = pkg.packageName,
            label = info.loadLabel(pm).toString(),
            system = info.flags and ApplicationInfo.FLAG_SYSTEM != 0,
            internet = pkg.requestedPermissions?.contains(Manifest.permission.INTERNET) == true,
            info = info,
        )
    }
}

@Composable
private fun AppRow(index: Int, count: Int, app: InstalledApp, checked: Boolean, onChange: (Boolean) -> Unit) {
    val context = LocalContext.current
    val colors = apple
    val icon by produceState<ImageBitmap?>(null, app.packageName) {
        value = withContext(Dispatchers.IO) {
            runCatching { app.info.loadIcon(context.packageManager).toBitmap(96, 96).asImageBitmap() }.getOrNull()
        }
    }
    GroupRow(index, count, onClick = { onChange(!checked) }, inset = 62.dp) {
        Box(Modifier.size(34.dp)) {
            icon?.let { Image(it, contentDescription = null, modifier = Modifier.size(34.dp)) }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(app.label, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(app.packageName, style = MaterialTheme.typography.bodySmall, color = colors.secondaryLabel, maxLines = 1, overflow = TextOverflow.MiddleEllipsis)
        }
        CheckCircle(checked)
    }
}

@Composable
fun CheckCircle(checked: Boolean) {
    val colors = apple
    Box(
        Modifier.size(24.dp).then(
            if (checked) Modifier.background(colors.accent, CircleShape) else Modifier.border(1.5.dp, colors.chevron, CircleShape),
        ),
        contentAlignment = Alignment.Center,
    ) {
        if (checked) Icon(LineIcons.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
    }
}
