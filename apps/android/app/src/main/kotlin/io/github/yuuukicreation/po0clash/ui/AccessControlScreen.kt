package io.github.yuuukicreation.po0clash.ui

import android.Manifest
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
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
import io.github.yuuukicreation.po0clash.accessMode
import io.github.yuuukicreation.po0clash.core.AccessControl
import io.github.yuuukicreation.po0clash.core.AppSort
import io.github.yuuukicreation.po0clash.selected
import io.github.yuuukicreation.po0clash.withMode
import io.github.yuuukicreation.po0clash.withSelected
import io.github.yuuukicreation.po0clash.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private class InstalledApp(
    val packageName: String,
    val label: String,
    val system: Boolean,
    val internet: Boolean,
    val installed: Long,
    val info: ApplicationInfo,
)

/** FlClash's per-app proxy: proxy only the chosen apps, or everything except them. */
@Composable
fun AccessControlScreen(vm: AppViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val access = settings.accessControl
    val mode = access.accessMode
    fun update(change: (AccessControl) -> AccessControl) = vm.setAppSettings { it.copy(accessControl = change(it.accessControl)) }
    val clipboard = LocalClipboardManager.current
    val sheets = LocalSheets.current
    var query by rememberSaveable { mutableStateOf("") }
    var selectedFirst by rememberSaveable { mutableStateOf(true) }
    val apps by produceState<List<InstalledApp>?>(null) {
        value = withContext(Dispatchers.IO) { installedApps(context.packageManager, context.packageName) }
    }
    val chosen = access.selected.toSet()
    val shown = apps.orEmpty()
        .filter { (!access.hideSystemApps || !it.system) && (!access.hideOfflineApps || it.internet) }
        .filter { query.isBlank() || it.label.contains(query.trim(), ignoreCase = true) || it.packageName.contains(query.trim(), ignoreCase = true) }
        .sortedWith(
            compareBy<InstalledApp> { selectedFirst && it.packageName !in chosen }.then(
                when (access.sort) {
                    AppSort.NAME -> compareBy { it.label.lowercase() }
                    AppSort.INSTALL_TIME -> compareByDescending { it.installed }
                    AppSort.UNSORTED -> compareBy { 0 }
                },
            ),
        )
    val modes = AccessMode.entries.map { it to stringResource(it.label) }

    val filterAnchor = rememberAnchor()
    val moreAnchor = rememberAnchor()
    val sortAnchor = rememberAnchor()
    val sortTitle = stringResource(R.string.sort)
    val sortLabels = listOf(stringResource(R.string.sort_default), stringResource(R.string.sort_name), stringResource(R.string.sort_install_time))
    val filterTitle = stringResource(R.string.filter)
    val moreTitle = stringResource(R.string.more)
    val filterLabels = listOf(stringResource(R.string.show_system_apps), stringResource(R.string.only_internet_apps), stringResource(R.string.selected_first))
    val moreLabels = listOf(stringResource(R.string.select_all), stringResource(R.string.clear_selection), stringResource(R.string.copy_to_clipboard), stringResource(R.string.paste_from_clipboard))
    val actions = listOf(
        PageAction(LineIcons.Sliders, filterTitle, enabled = mode != AccessMode.OFF, anchor = filterAnchor) {
            sheets.menu(
                filterAnchor,
                listOf(
                    SheetAction(filterLabels[0], checked = !access.hideSystemApps) { update { it.copy(hideSystemApps = !it.hideSystemApps) } },
                    SheetAction(filterLabels[1], checked = access.hideOfflineApps) { update { it.copy(hideOfflineApps = !it.hideOfflineApps) } },
                    SheetAction(filterLabels[2], checked = selectedFirst) { selectedFirst = !selectedFirst },
                ),
            )
        },
        PageAction(LineIcons.Sort, sortTitle, enabled = mode != AccessMode.OFF, anchor = sortAnchor) {
            sheets.menu(
                sortAnchor,
                AppSort.entries.mapIndexed { i, sort -> SheetAction(sortLabels[i], checked = access.sort == sort) { update { it.copy(sort = sort) } } },
            )
        },
        PageAction(LineIcons.More, moreTitle, enabled = mode != AccessMode.OFF, anchor = moreAnchor) {
            sheets.menu(
                moreAnchor,
                listOf(
                    SheetAction(moreLabels[0]) { update { it.withSelected(it.selected + shown.map { app -> app.packageName }.filterNot(chosen::contains)) } },
                    SheetAction(moreLabels[1]) { update { it.withSelected(emptyList()) } },
                    SheetAction(moreLabels[2]) { clipboard.setText(AnnotatedString(chosen.sorted().joinToString("\n"))) },
                    SheetAction(moreLabels[3]) {
                        val pasted = clipboard.getText()?.text.orEmpty().split('\n', ',', ' ').map(String::trim).filter(String::isNotEmpty)
                        if (pasted.isNotEmpty()) update { it.withSelected(pasted.distinct()) }
                    },
                ),
            )
        },
    )
    ToolPage(stringResource(R.string.access_control), onBack, actions) {
        item {
            ChoiceRow(stringResource(R.string.access_mode), modes, mode) { v -> update { it.withMode(v) } }
        }
        if (mode == AccessMode.OFF) return@ToolPage
        item(key = "search") {
            Column(Modifier.padding(top = 12.dp)) {
                SearchField(query) { query = it }
                SectionHeader(pluralStringResource(R.plurals.app_count, chosen.size, chosen.size))
            }
        }
        if (apps == null) {
            item { ValueRow(stringResource(R.string.loading), "") }
        }
        items(shown, key = { app -> app.packageName }) { app ->
            AppRow(app, app.packageName in chosen) { on ->
                update { it.withSelected(if (on) it.selected + app.packageName else it.selected - app.packageName) }
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
            installed = pkg.firstInstallTime,
            info = info,
        )
    }
}

@Composable
private fun AppRow(app: InstalledApp, checked: Boolean, onChange: (Boolean) -> Unit) {
    val context = LocalContext.current
    val colors = palette
    val icon by produceState<ImageBitmap?>(null, app.packageName) {
        value = withContext(Dispatchers.IO) {
            runCatching { app.info.loadIcon(context.packageManager).toBitmap(96, 96).asImageBitmap() }.getOrNull()
        }
    }
    GroupRow(onClick = { onChange(!checked) }) {
        Box(Modifier.size(34.dp)) {
            icon?.let { Image(it, contentDescription = null, modifier = Modifier.size(34.dp)) }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(app.label, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(app.packageName, style = MaterialTheme.typography.bodyMedium, color = colors.ink2, maxLines = 1, overflow = TextOverflow.MiddleEllipsis)
        }
        Checkbox(
            checked,
            null,
            colors = CheckboxDefaults.colors(checkedColor = colors.accent, uncheckedColor = colors.ink2, checkmarkColor = colors.onAccent),
        )
    }
}
