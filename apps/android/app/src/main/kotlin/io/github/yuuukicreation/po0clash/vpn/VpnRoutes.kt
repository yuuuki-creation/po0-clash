package io.github.yuuukicreation.po0clash.vpn

object VpnRoutes {
    const val MTU = 9000
    const val ADDRESS4 = "172.19.0.1"
    const val PREFIX4 = 30
    const val ADDRESS6 = "fdfe:dcba:9876::1"
    const val PREFIX6 = 126
    const val DNS = "172.19.0.2"
    const val PO0_API = "124.221.69.228"

    data class Route(val address: String, val prefix: Int)

    /** The 32 prefixes that together cover 0.0.0.0/0 except [excluded]/32, for systems without excludeRoute. */
    fun ipv4Excluding(excluded: String): List<Route> {
        val target = parse(excluded)
        return (1..32).map { prefix ->
            val mask = -1 shl (32 - prefix)
            Route(format((target xor (1 shl (32 - prefix))) and mask), prefix)
        }
    }

    fun contains(route: Route, address: String): Boolean {
        val mask = if (route.prefix == 0) 0 else -1 shl (32 - route.prefix)
        return parse(route.address) and mask == parse(address) and mask
    }

    private fun parse(address: String): Int =
        address.split('.').fold(0) { acc, part -> (acc shl 8) or part.toInt() }

    private fun format(address: Int): String =
        (3 downTo 0).joinToString(".") { ((address ushr (it * 8)) and 0xff).toString() }
}
