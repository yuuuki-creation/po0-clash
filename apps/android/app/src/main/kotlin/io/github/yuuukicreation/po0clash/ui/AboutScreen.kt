package io.github.yuuukicreation.po0clash.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.graphics.drawable.toBitmap
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.BuildConfig
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.License
import io.github.yuuukicreation.po0clash.core.Release
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private const val PROJECT = "https://github.com/yuuuki-creation/po0-clash"
private const val UPSTREAM = "https://github.com/chen08209/FlClash"
private const val MIHOMO = "https://github.com/MetaCubeX/mihomo"

@Composable
fun AboutScreen(vm: AppViewModel, onBack: () -> Unit) {
    var licenses by rememberSaveable { mutableStateOf(false) }
    val animate = vm.appSettings.collectAsStateWithLifecycle().value.pageAnimation
    PushHost(Unit.takeIf { licenses }, animate, onBack = { licenses = false }, label = "about") { open ->
        if (open == null) AboutPage(vm, onBack, onLicenses = { licenses = true }) else LicensesPage(vm) { licenses = false }
    }
}

@Composable
private fun AboutPage(vm: AppViewModel, onBack: () -> Unit, onLicenses: () -> Unit) {
    val uri = LocalUriHandler.current
    val busy by vm.busy.collectAsStateWithLifecycle()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    var clicks by remember { mutableIntStateOf(0) }
    val enabled = stringResource(R.string.developer_mode_on)
    ToolPage(stringResource(R.string.about), onBack) {
        item {
            AppHeader {
                clicks += 1
                if (clicks == 5 && !settings.developerMode) {
                    vm.setAppSettings { it.copy(developerMode = true) }
                    vm.toast(enabled)
                }
            }
        }
        item {
            SectionHeader(stringResource(R.string.more))
            NavRow(0, 2, null, stringResource(R.string.check_update), busy = AppViewModel.BUSY_UPDATE in busy, chevron = false) {
                vm.checkUpdate(userInitiated = true)
            }
            NavRow(1, 2, null, stringResource(R.string.project), "yuuuki-creation/po0-clash") { uri.openUri(PROJECT) }
        }
        item {
            SectionHeader(stringResource(R.string.credits))
            NavRow(0, 4, null, stringResource(R.string.upstream_client), "chen08209/FlClash") { uri.openUri(UPSTREAM) }
            NavRow(1, 4, null, stringResource(R.string.engine), "mihomo") { uri.openUri(MIHOMO) }
            ValueRow(2, 4, stringResource(R.string.upstream_contributors), "June2 · Arue")
            NavRow(3, 4, null, stringResource(R.string.licenses), onClick = onLicenses)
        }
    }
}

/** The launcher icon, name and version; FlClash turns developer mode on after five taps on the version. */
@Composable
private fun AppHeader(onVersionTap: () -> Unit) {
    val context = LocalContext.current
    val icon = remember { context.packageManager.getApplicationIcon(context.packageName).toBitmap(192, 192).asImageBitmap() }
    Column(
        Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Image(icon, contentDescription = null, modifier = Modifier.size(76.dp).clip(RoundedCornerShape(18.dp)))
        Text("po0-clash", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Text(
            "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
            style = MaterialTheme.typography.bodyMedium,
            color = apple.secondaryLabel,
            modifier = Modifier.clickable(remember { MutableInteractionSource() }, indication = null, onClick = onVersionTap),
        )
        Text(
            stringResource(R.string.about_detail),
            style = MaterialTheme.typography.bodyMedium,
            color = apple.secondaryLabel,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun LicensesPage(vm: AppViewModel, onBack: () -> Unit) {
    val uri = LocalUriHandler.current
    val all by produceState(emptyList<License>()) { value = withContext(Dispatchers.IO) { vm.engine.core.licenses() } }
    var query by rememberSaveable { mutableStateOf("") }
    val shown = all.filter { query.isBlank() || it.name.contains(query.trim(), ignoreCase = true) }
    ToolPage(stringResource(R.string.licenses), onBack, subtitle = pluralStringResource(R.plurals.package_count, all.size, all.size)) {
        item { Column(Modifier.padding(bottom = 12.dp)) { SearchField(query) { query = it } } }
        itemsIndexed(shown, key = { _, license -> license.name + license.version }) { index, license ->
            GroupRow(index, shown.size, onClick = license.url.takeIf { it.isNotEmpty() }?.let { { uri.openUri(it) } }) {
                RowText(listOf(license.name, license.version).filter(String::isNotEmpty).joinToString(" "), license.license)
                if (license.url.isNotEmpty()) {
                    androidx.compose.material3.Icon(
                        LineIcons.ChevronRight,
                        contentDescription = null,
                        tint = apple.chevron,
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
        }
    }
}

/** FlClash's developer mode; About's version turns it on, and turning it off here hides the page again. */
@Composable
fun DeveloperScreen(vm: AppViewModel, onBack: () -> Unit) {
    val sheets = LocalSheets.current
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val anchor = rememberAnchor()
    val message = stringResource(R.string.message_test_body)
    val clear = stringResource(R.string.clear_data)
    val confirm = stringResource(R.string.clear_data_confirm)
    ToolPage(stringResource(R.string.developer), onBack) {
        item {
            Spacer()
            SwitchRow(0, 1, stringResource(R.string.developer_mode), settings.developerMode, stringResource(R.string.developer_mode_detail)) { on ->
                vm.setAppSettings { it.copy(developerMode = on) }
                if (!on) onBack()
            }
        }
        item {
            SectionHeader(stringResource(R.string.options))
            NavRow(0, 4, null, stringResource(R.string.message_test), chevron = false) { vm.toast(message) }
            GroupRow(1, 4, onClick = vm::addTestLogs.takeIf { settings.captureLogs }) {
                RowText(
                    stringResource(R.string.logs_test),
                    stringResource(if (settings.captureLogs) R.string.logs_test_detail else R.string.logs_test_off),
                )
            }
            NavRow(2, 4, null, stringResource(R.string.prune_cache), busy = AppViewModel.BUSY_CACHE in busy, chevron = false, onClick = vm::pruneCache)
            Column(Modifier.anchor(anchor)) {
                GroupRow(3, 4, onClick = { sheets.menu(anchor, confirm, listOf(SheetAction(clear, destructive = true) { vm.clearData() })) }) {
                    RowText(clear, stringResource(R.string.clear_data_detail), titleColor = apple.red)
                }
            }
        }
    }
}

@Composable
private fun Spacer() = androidx.compose.foundation.layout.Spacer(Modifier.padding(top = 12.dp))

/** A newer release; the automatic check also offers to stop checking. */
@Composable
fun ReleaseSheet(release: Release, automatic: Boolean, onDone: () -> Unit, onStop: () -> Unit) {
    val uri = LocalUriHandler.current
    val notes = release.notes.trim().let { if (it.length > 800) it.take(800) + "…" else it }
    SheetTitle(stringResource(R.string.update_available, release.version))
    if (notes.isNotEmpty()) {
        Text(notes, style = MaterialTheme.typography.bodySmall, color = apple.secondaryLabel, maxLines = 14)
    }
    SheetButtons(stringResource(R.string.open_download_page), onCancel = onDone) {
        onDone()
        uri.openUri(release.url)
    }
    if (automatic) {
        androidx.compose.material3.TextButton(onClick = onStop, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.dont_remind), color = apple.secondaryLabel)
        }
    }
}
