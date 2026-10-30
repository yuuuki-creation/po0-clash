package io.github.yuuukicreation.po0clash

import android.content.Context
import androidx.annotation.StringRes
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class AccessMode(@param:StringRes val label: Int) {
    OFF(R.string.access_off),
    ALLOW(R.string.access_allow),
    DENY(R.string.access_deny),
}

/** Settings only the Android VPN has (per-app proxy, Wi-Fi exclusions, notification and VPN builder options). */
data class AndroidSettings(
    val accessMode: AccessMode = AccessMode.OFF,
    val accessPackages: Set<String> = emptySet(),
    val excludedSsids: Set<String> = emptySet(),
    val notificationStop: Boolean = true,
    val hideFromRecents: Boolean = false,
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
            .putString(ACCESS_MODE, next.accessMode.name)
            .putStringSet(ACCESS_PACKAGES, next.accessPackages)
            .putStringSet(EXCLUDED_SSIDS, next.excludedSsids)
            .putBoolean(NOTIFICATION_STOP, next.notificationStop)
            .putBoolean(HIDE_FROM_RECENTS, next.hideFromRecents)
            .putBoolean(ALLOW_BYPASS, next.allowBypass)
            .putBoolean(SYSTEM_PROXY, next.systemProxy)
            .putBoolean(IPV6, next.ipv6)
            .apply()
        _state.value = next
    }

    private fun read(): AndroidSettings {
        val defaults = AndroidSettings()
        return AndroidSettings(
            accessMode = prefs.getString(ACCESS_MODE, null)?.let { runCatching { AccessMode.valueOf(it) }.getOrNull() } ?: defaults.accessMode,
            accessPackages = prefs.getStringSet(ACCESS_PACKAGES, null)?.toSet() ?: defaults.accessPackages,
            excludedSsids = prefs.getStringSet(EXCLUDED_SSIDS, null)?.toSet() ?: defaults.excludedSsids,
            notificationStop = prefs.getBoolean(NOTIFICATION_STOP, defaults.notificationStop),
            hideFromRecents = prefs.getBoolean(HIDE_FROM_RECENTS, defaults.hideFromRecents),
            allowBypass = prefs.getBoolean(ALLOW_BYPASS, defaults.allowBypass),
            systemProxy = prefs.getBoolean(SYSTEM_PROXY, defaults.systemProxy),
            ipv6 = prefs.getBoolean(IPV6, defaults.ipv6),
        )
    }

    private companion object {
        const val ACCESS_MODE = "access_mode"
        const val ACCESS_PACKAGES = "access_packages"
        const val EXCLUDED_SSIDS = "excluded_ssids"
        const val NOTIFICATION_STOP = "notification_stop"
        const val HIDE_FROM_RECENTS = "hide_from_recents"
        const val ALLOW_BYPASS = "allow_bypass"
        const val SYSTEM_PROXY = "system_proxy"
        const val IPV6 = "ipv6"
    }
}
