package io.github.yuuukicreation.po0clash.ui

import androidx.compose.ui.unit.dp
import io.github.yuuukicreation.po0clash.core.ThemeMode
import io.github.yuuukicreation.po0clash.Language
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.material3.Text
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Icon
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.activity.compose.LocalActivity
import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.QuickActionActivity
import io.github.yuuukicreation.po0clash.R

/** Wi-Fi networks where the VPN steps aside, and the permissions that need: location for the SSID, no battery limits. */
@SuppressLint("BatteryLife")
@Composable
fun OnDemandScreen(vm: AppViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val ssid by vm.engine.ssid.collectAsStateWithLifecycle()
    var resumed by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { resumed++ }
    val location = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        resumed++
        vm.engine.refreshSsid()
    }
    fun granted(permission: String) = ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    val fine = remember(resumed) { granted(Manifest.permission.ACCESS_FINE_LOCATION) }
    val background = remember(resumed) { Build.VERSION.SDK_INT < 29 || granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION) }
    val battery = remember(resumed) { context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName) }
    val allowed = stringResource(R.string.allowed)
    val notAllowed = stringResource(R.string.not_allowed)
    ToolPage(stringResource(R.string.on_demand), onBack) {
        item {
            SectionHeader(stringResource(R.string.excluded_wifi))
            val current = ssid?.takeIf { it !in settings.excludedSsids }
            val count = if (current != null) 2 else 1
            ListRow(0, count, stringResource(R.string.excluded_wifi), settings.excludedSsids, stringResource(R.string.excluded_wifi_hint)) { v ->
                vm.setAppSettings { it.copy(excludedSsids = v.distinct()) }
            }
            if (current != null) {
                ActionRow(1, count, stringResource(R.string.exclude_current_wifi, current), LineIcons.Plus) {
                    vm.setAppSettings { it.copy(excludedSsids = it.excludedSsids + current) }
                }
            }
            SectionFooter(stringResource(R.string.excluded_wifi_detail))
        }
        item {
            SectionHeader(stringResource(R.string.permissions))
            NavRow(0, 3, LineIcons.Pin, stringResource(R.string.location_permission), if (fine) allowed else notAllowed) {
                if (!fine) location.launch(Manifest.permission.ACCESS_FINE_LOCATION) else context.startActivity(appDetails(context.packageName))
            }
            NavRow(1, 3, LineIcons.Pin, stringResource(R.string.background_location), if (background) allowed else notAllowed) {
                context.startActivity(appDetails(context.packageName))
            }
            NavRow(2, 3, LineIcons.Battery, stringResource(R.string.ignore_battery), if (battery) allowed else notAllowed) {
                val intent = if (battery) {
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                } else {
                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${context.packageName}"))
                }
                runCatching { context.startActivity(intent) }
            }
            SectionFooter(stringResource(R.string.permissions_detail))
        }
    }
}

private fun appDetails(packageName: String) =
    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))

/** FlClash's app switches that mean something on Android; desktop-only ones (tray, login items) stay hidden. */
@Composable
fun ApplicationScreen(vm: AppViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    val s by vm.appSettings.collectAsStateWithLifecycle()
    val set = vm::setAppSettings
    val actions = QuickActionActivity.actions(context.packageName)
    val copied = stringResource(R.string.copied)
    ToolPage(stringResource(R.string.application), onBack) {
        item {
            SectionHeader(stringResource(R.string.general))
            SwitchRow(0, 5, stringResource(R.string.auto_connect), s.autoConnect, stringResource(R.string.auto_connect_detail)) { v -> set { it.copy(autoConnect = v) } }
            SwitchRow(1, 5, stringResource(R.string.hide_from_recents), s.hideFromRecents) { v -> set { it.copy(hideFromRecents = v) } }
            SwitchRow(2, 5, stringResource(R.string.notification_stop), s.notificationStopButton, stringResource(R.string.notification_stop_detail)) { v ->
                set { it.copy(notificationStopButton = v) }
            }
            SwitchRow(3, 5, stringResource(R.string.page_animation), s.pageAnimation) { v -> set { it.copy(pageAnimation = v) } }
            SwitchRow(4, 5, stringResource(R.string.show_nav_labels), s.showNavLabels) { v -> set { it.copy(showNavLabels = v) } }
        }
        item {
            SectionHeader(stringResource(R.string.connections))
            SwitchRow(0, 4, stringResource(R.string.capture_logs), s.captureLogs, stringResource(R.string.capture_logs_detail)) { v -> set { it.copy(captureLogs = v) } }
            SwitchRow(1, 4, stringResource(R.string.close_on_switch), s.closeConnectionsOnSwitch, stringResource(R.string.close_on_switch_detail)) { v ->
                set { it.copy(closeConnectionsOnSwitch = v) }
            }
            SwitchRow(2, 4, stringResource(R.string.only_proxy_traffic), s.onlyProxyTraffic) { v -> set { it.copy(onlyProxyTraffic = v) } }
            SwitchRow(3, 4, stringResource(R.string.check_certificate), s.checkCertificate, stringResource(R.string.check_certificate_detail)) { v ->
                set { it.copy(checkCertificate = v) }
            }
        }
        item {
            SectionHeader(stringResource(R.string.other))
            SwitchRow(0, 2, stringResource(R.string.auto_check_update), s.autoCheckUpdate) { v -> set { it.copy(autoCheckUpdate = v) } }
            SwitchRow(1, 2, stringResource(R.string.crash_reports), s.crashReports, stringResource(R.string.crash_reports_detail)) { v -> set { it.copy(crashReports = v) } }
        }
        item {
            SectionHeader(stringResource(R.string.external_control))
            actions.forEachIndexed { index, action ->
                NavRow(index, actions.size, null, action.substringAfterLast('.'), action.substringBeforeLast(".action"), chevron = false) {
                    clipboard.setText(AnnotatedString(action))
                    vm.toast(copied)
                }
            }
            SectionFooter(stringResource(R.string.external_control_detail))
        }
    }
}

private val textScales = listOf(null, 85, 100, 115, 130)

@Composable
fun AppearanceScreen(vm: AppViewModel, onBack: () -> Unit) {
    val s by vm.appSettings.collectAsStateWithLifecycle()
    val sheets = LocalSheets.current
    val modes = listOf(
        ThemeMode.SYSTEM to stringResource(R.string.follow_system),
        ThemeMode.LIGHT to stringResource(R.string.theme_light),
        ThemeMode.DARK to stringResource(R.string.theme_dark),
    )
    val scales = textScales.map { it to (it?.let { p -> "$p%" } ?: stringResource(R.string.follow_system)) }
    val addColor = stringResource(R.string.add_color)
    ToolPage(stringResource(R.string.appearance), onBack) {
        item {
            SectionHeader(stringResource(R.string.theme_mode))
            SegmentedPicker(modes, s.themeMode, enabled = true) { v -> vm.setAppSettings { it.copy(themeMode = v) } }
        }
        item {
            SectionHeader(stringResource(R.string.theme_color))
            ColorSwatches(
                colors = s.themeColors,
                selected = s.themeColor,
                onSelect = { c -> vm.setAppSettings { it.copy(themeColor = c) } },
                onRemove = { c -> vm.setAppSettings { it.copy(themeColors = it.themeColors - c) } },
                onAdd = {
                    sheets.show {
                        ColorSheet(addColor) { c -> vm.setAppSettings { it.copy(themeColors = it.themeColors + c, themeColor = c) } }
                    }
                },
            )
            SectionFooter(stringResource(R.string.theme_color_detail))
        }
        item {
            SectionHeader(stringResource(R.string.display))
            SwitchRow(0, 2, stringResource(R.string.pure_black), s.pureBlack, stringResource(R.string.pure_black_detail)) { v -> vm.setAppSettings { it.copy(pureBlack = v) } }
            ChoiceRow(1, 2, stringResource(R.string.text_size), scales, s.textScale?.toInt()) { v ->
                vm.setAppSettings { it.copy(textScale = v?.toUShort()) }
            }
        }
    }
}

/** The presets and custom colors as dots; long-press removes one that is not in use. */
@OptIn(ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
@Composable
private fun ColorSwatches(colors: List<UInt>, selected: UInt, onSelect: (UInt) -> Unit, onRemove: (UInt) -> Unit, onAdd: () -> Unit) {
    val palette = apple
    FlowRow(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(cardRadius)).background(palette.card).padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        colors.forEach { argb ->
            val active = argb == selected
            Box(
                Modifier.size(38.dp).clip(CircleShape).background(Color(argb.toInt()))
                    .combinedClickable(onLongClick = { if (!active) onRemove(argb) }) { onSelect(argb) },
                contentAlignment = Alignment.Center,
            ) {
                if (active) Icon(LineIcons.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
            }
        }
        Box(
            Modifier.size(38.dp).clip(CircleShape).background(palette.track).clickable(onClick = onAdd),
            contentAlignment = Alignment.Center,
        ) {
            Icon(LineIcons.Plus, contentDescription = stringResource(R.string.add_color), tint = palette.label, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun ColorSheet(title: String, onAdd: (UInt) -> Unit) {
    val sheets = LocalSheets.current
    var text by rememberSaveable { mutableStateOf("#") }
    val argb = text.removePrefix("#").takeIf { it.length == 6 }?.toUIntOrNull(16)?.let { it or 0xFF000000u }
    SheetTitle(title)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(38.dp).clip(CircleShape).background(argb?.let { Color(it.toInt()) } ?: apple.track))
        Box(Modifier.weight(1f)) { SheetField(text, { text = it.take(7) }, "#007AFF", multiline = false, keyboardType = KeyboardType.Ascii) }
    }
    SheetButtons(stringResource(R.string.add), enabled = argb != null, onCancel = sheets::dismiss) {
        sheets.dismiss()
        argb?.let(onAdd)
    }
}

@Composable
fun LanguageScreen(vm: AppViewModel, onBack: () -> Unit) {
    val s by vm.appSettings.collectAsStateWithLifecycle()
    val activity = LocalActivity.current
    val labels = mapOf(null to stringResource(R.string.follow_system), "zh-CN" to "简体中文", "en" to "English")
    ToolPage(stringResource(R.string.language), onBack) {
        item {
            Language.tags.forEachIndexed { index, tag ->
                GroupRow(index, Language.tags.size, onClick = {
                    if (tag != s.language) {
                        vm.setAppSettings { it.copy(language = tag) }
                        activity?.let { Language.apply(it, tag) }
                    }
                }) {
                    Text(labels.getValue(tag), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                    if (tag == s.language) Icon(LineIcons.Check, contentDescription = null, tint = apple.accent, modifier = Modifier.size(18.dp))
                }
            }
            SectionFooter(stringResource(R.string.language_detail))
        }
    }
}

fun languageLabel(tag: String?): String? = when (tag) {
    "zh-CN" -> "简体中文"
    "en" -> "English"
    else -> null
}
