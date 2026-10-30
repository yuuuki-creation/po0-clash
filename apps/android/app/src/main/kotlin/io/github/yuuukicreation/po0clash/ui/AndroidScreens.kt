package io.github.yuuukicreation.po0clash.ui

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
    val settings by vm.androidSettings.collectAsStateWithLifecycle()
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
            ListRow(0, count, stringResource(R.string.excluded_wifi), settings.excludedSsids.sorted(), stringResource(R.string.excluded_wifi_hint)) { v ->
                vm.updateAndroid { it.copy(excludedSsids = v.toSet()) }
            }
            if (current != null) {
                ActionRow(1, count, stringResource(R.string.exclude_current_wifi, current), LineIcons.Plus) {
                    vm.updateAndroid { it.copy(excludedSsids = it.excludedSsids + current) }
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

/** The Android-only app settings; the shared ones arrive with the core's settings model. */
@Composable
fun ApplicationScreen(vm: AppViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    val settings by vm.androidSettings.collectAsStateWithLifecycle()
    val actions = QuickActionActivity.actions(context.packageName)
    val copied = stringResource(R.string.copied)
    ToolPage(stringResource(R.string.application), onBack) {
        item {
            SectionHeader("Android")
            SwitchRow(0, 2, stringResource(R.string.hide_from_recents), settings.hideFromRecents) { v -> vm.updateAndroid { it.copy(hideFromRecents = v) } }
            SwitchRow(1, 2, stringResource(R.string.notification_stop), settings.notificationStop, stringResource(R.string.notification_stop_detail)) { v ->
                vm.updateAndroid { it.copy(notificationStop = v) }
            }
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
        item {
            SectionHeader(stringResource(R.string.other))
            ComingSoonRow()
            SectionFooter(stringResource(R.string.app_settings_pending))
        }
    }
}
