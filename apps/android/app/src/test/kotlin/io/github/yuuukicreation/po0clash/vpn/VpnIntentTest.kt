package io.github.yuuukicreation.po0clash.vpn

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnIntentTest {
    @Test
    fun exclusionPausesAndLeavingResumesOnlyWhileWanted() {
        assertEquals(VpnAction.PAUSE, vpnAction(true, true, true))
        assertEquals(VpnAction.NONE, vpnAction(true, true, false))
        assertEquals(VpnAction.START, vpnAction(true, false, false))
        assertEquals(VpnAction.NONE, vpnAction(false, false, false))
        assertEquals(VpnAction.NONE, vpnAction(false, true, false))
    }

    @Test
    fun unknownWifiNameCannotBypassConfiguredExclusions() {
        val excluded = listOf("Office")
        assertTrue(shouldPauseForWifi(true, null, excluded))
        assertTrue(shouldPauseForWifi(true, "Office", excluded))
        assertFalse(shouldPauseForWifi(true, "Home", excluded))
        assertFalse(shouldPauseForWifi(false, null, excluded))
        assertFalse(shouldPauseForWifi(true, null, emptyList()))
    }
}
