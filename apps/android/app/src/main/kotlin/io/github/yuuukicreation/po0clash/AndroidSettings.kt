package io.github.yuuukicreation.po0clash

import android.content.Context
import androidx.annotation.StringRes
import io.github.yuuukicreation.po0clash.core.AccessControl
import io.github.yuuukicreation.po0clash.core.AccessControlMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

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

/** VPN builder options only Android has; the core's settings do not model them. */
data class AndroidSettings(
    val allowBypass: Boolean = false,
    val systemProxy: Boolean = false,
    val ipv6: Boolean = true,
)

class AndroidSettingsStore(context: Context) {
    private val prefs = context.getSharedPreferences("android_settings", Context.MODE_PRIVATE)
    private val _state = MutableStateFlow(read())
    val state = _state.asStateFlow()

    @Synchronized
    fun update(change: (AndroidSettings) -> AndroidSettings) {
        val next = change(_state.value)
        prefs.edit()
            .putBoolean(ALLOW_BYPASS, next.allowBypass)
            .putBoolean(SYSTEM_PROXY, next.systemProxy)
            .putBoolean(IPV6, next.ipv6)
            .apply()
        _state.value = next
    }

    private fun read(): AndroidSettings {
        val defaults = AndroidSettings()
        return AndroidSettings(
            allowBypass = prefs.getBoolean(ALLOW_BYPASS, defaults.allowBypass),
            systemProxy = prefs.getBoolean(SYSTEM_PROXY, defaults.systemProxy),
            ipv6 = prefs.getBoolean(IPV6, defaults.ipv6),
        )
    }

    private companion object {
        const val ALLOW_BYPASS = "allow_bypass"
        const val SYSTEM_PROXY = "system_proxy"
        const val IPV6 = "ipv6"
    }
}
