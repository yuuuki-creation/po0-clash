package io.github.yuuukicreation.po0clash.vpn

import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.random.Random

class VpnRoutesTest {
    private val routes = VpnRoutes.ipv4Excluding(VpnRoutes.PO0_API)

    private fun matches(address: String) = routes.count { VpnRoutes.contains(it, address) }

    @Test
    fun excludesOnlyThePo0Address() {
        assertEquals(32, routes.size)
        assertEquals(0, matches(VpnRoutes.PO0_API))
        listOf("124.221.69.229", "124.221.69.227", "0.0.0.0", "255.255.255.255", "8.8.8.8", "10.0.2.2")
            .forEach { assertEquals(it, 1, matches(it)) }
    }

    @Test
    fun coversEveryOtherAddressExactlyOnce() {
        val random = Random(7)
        repeat(10_000) {
            val address = List(4) { random.nextInt(256) }.joinToString(".")
            if (address != VpnRoutes.PO0_API) assertEquals(address, 1, matches(address))
        }
    }
}
