package io.github.yuuukicreation.po0clash

import android.content.Context
import androidx.annotation.StringRes
import io.github.yuuukicreation.po0clash.core.AccessControl
import io.github.yuuukicreation.po0clash.core.AccessControlMode
import io.github.yuuukicreation.po0clash.core.Po0Core
import io.github.yuuukicreation.po0clash.core.ProxiesLayout
import io.github.yuuukicreation.po0clash.core.ProxyTileStyle

/** FlClash's per-app proxy as one choice: off, or which of the core's two lists applies. */
enum class AccessMode(@param:StringRes val label: Int) {
    OFF(R.string.access_off),
    ALLOW(R.string.access_allow),
    DENY(R.string.access_deny),
}

val AccessControl.accessMode: AccessMode
    get() = when {
        !enabled -> AccessMode.OFF
        mode == AccessControlMode.ACCEPT_SELECTED -> AccessMode.ALLOW
        else -> AccessMode.DENY
    }

/** The list the current mode uses; the core keeps the other one for when the mode switches back. */
val AccessControl.selected: List<String>
    get() = if (mode == AccessControlMode.ACCEPT_SELECTED) accepted else rejected

fun AccessControl.withMode(mode: AccessMode): AccessControl = when (mode) {
    AccessMode.OFF -> copy(enabled = false)
    AccessMode.ALLOW -> copy(enabled = true, mode = AccessControlMode.ACCEPT_SELECTED)
    AccessMode.DENY -> copy(enabled = true, mode = AccessControlMode.REJECT_SELECTED)
}

fun AccessControl.withSelected(packages: Collection<String>): AccessControl =
    if (mode == AccessControlMode.ACCEPT_SELECTED) copy(accepted = packages.toList()) else copy(rejected = packages.toList())

fun migrateAndroidSettings(context: Context, core: Po0Core) {
    val prefs = context.getSharedPreferences("android_settings", Context.MODE_PRIVATE)
    val keys = listOf("allow_bypass", "system_proxy", "ipv6")
    val old = core.appSettings()
    var settings = old
    if (keys.any(prefs::contains)) {
        settings = settings.copy(androidVpn = old.androidVpn.copy(
            allowBypass = prefs.getBoolean(keys[0], old.androidVpn.allowBypass),
            systemProxy = prefs.getBoolean(keys[1], old.androidVpn.systemProxy),
            ipv6 = prefs.getBoolean(keys[2], old.androidVpn.ipv6),
        ))
    }
    val currentUi = prefs.getBoolean("flclash_093_ui", false)
    if (!currentUi) settings = settings.copy(proxiesLayout = ProxiesLayout.LIST, proxyTileStyle = ProxyTileStyle.COMPACT)
    if (settings != old) core.setAppSettings(settings)
    if (!currentUi || keys.any(prefs::contains)) {
        val edit = prefs.edit().putBoolean("flclash_093_ui", true)
        keys.forEach { edit.remove(it) }
        check(edit.commit())
    }
}
