package io.github.yuuukicreation.po0clash.vpn

internal enum class VpnAction { START, PAUSE, NONE }

internal fun shouldPauseForWifi(wifiPresent: Boolean, ssid: String?, excluded: List<String>): Boolean =
    wifiPresent && excluded.isNotEmpty() && (ssid == null || ssid in excluded)

internal fun vpnAction(wanted: Boolean, excluded: Boolean, running: Boolean): VpnAction = when {
    !wanted -> VpnAction.NONE
    excluded && running -> VpnAction.PAUSE
    !excluded && !running -> VpnAction.START
    else -> VpnAction.NONE
}
