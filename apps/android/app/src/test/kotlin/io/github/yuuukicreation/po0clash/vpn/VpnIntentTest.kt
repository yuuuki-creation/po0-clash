package io.github.yuuukicreation.po0clash.vpn

import org.junit.Assert.assertEquals
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
}
