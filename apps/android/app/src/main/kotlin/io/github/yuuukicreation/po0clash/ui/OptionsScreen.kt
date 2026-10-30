package io.github.yuuukicreation.po0clash.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.yuuukicreation.po0clash.R
import io.github.yuuukicreation.po0clash.core.DnsMode
import io.github.yuuukicreation.po0clash.core.DnsOptions
import io.github.yuuukicreation.po0clash.core.FindProcessMode
import io.github.yuuukicreation.po0clash.core.LogLevel
import io.github.yuuukicreation.po0clash.core.TunStack

@Composable
fun BasicOptionsScreen(vm: AppViewModel, onBack: () -> Unit) {
    val o by vm.options.collectAsStateWithLifecycle()
    val set = vm::setOptions
    val levels = listOf(
        LogLevel.DEBUG to "Debug",
        LogLevel.INFO to "Info",
        LogLevel.WARNING to "Warning",
        LogLevel.ERROR to "Error",
        LogLevel.SILENT to "Silent",
    )
    val findProcess = listOf(
        FindProcessMode.OFF to stringResource(R.string.off),
        FindProcessMode.STRICT to stringResource(R.string.find_process_strict),
        FindProcessMode.ALWAYS to stringResource(R.string.find_process_always),
    )
    val default = stringResource(R.string.default_value)
    val off = stringResource(R.string.off)
    ToolPage(stringResource(R.string.basic_config), onBack) {
        item {
            SectionHeader(stringResource(R.string.general))
            ChoiceRow(0, 8, stringResource(R.string.log_level), levels, o.logLevel) { v -> set { it.copy(logLevel = v) } }
            EditRow(1, 8, stringResource(R.string.test_url), o.testUrl, default, KeyboardType.Uri) { v -> set { it.copy(testUrl = v) } }
            EditRow(2, 8, stringResource(R.string.user_agent), o.userAgent, default) { v -> set { it.copy(userAgent = v) } }
            EditRow(
                3,
                8,
                stringResource(R.string.keep_alive),
                o.keepAliveInterval.takeIf { it > 0u }?.let { stringResource(R.string.seconds, it.toInt()) }.orEmpty(),
                default,
                KeyboardType.Number,
                validate = { it.isEmpty() || it.toUIntOrNull() != null },
            ) { v -> set { it.copy(keepAliveInterval = v.toUIntOrNull() ?: 0u) } }
            SwitchRow(4, 8, stringResource(R.string.unified_delay), o.unifiedDelay, stringResource(R.string.unified_delay_detail)) { v ->
                set { it.copy(unifiedDelay = v) }
            }
            SwitchRow(5, 8, stringResource(R.string.tcp_concurrent), o.tcpConcurrent) { v -> set { it.copy(tcpConcurrent = v) } }
            ChoiceRow(6, 8, stringResource(R.string.find_process), findProcess, o.findProcessMode) { v -> set { it.copy(findProcessMode = v) } }
            SwitchRow(7, 8, "IPv6", o.ipv6) { v -> set { it.copy(ipv6 = v) } }
        }
        item {
            SectionHeader(stringResource(R.string.inbound))
            EditRow(0, 6, stringResource(R.string.mixed_port), o.mixedPort.toString(), keyboard = KeyboardType.Number, validate = ::isPort) { v ->
                set { it.copy(mixedPort = v.toUShort()) }
            }
            EditRow(1, 6, stringResource(R.string.socks_port), portText(o.socksPort), off, KeyboardType.Number, validate = { it.isEmpty() || isPort(it) }) { v ->
                set { it.copy(socksPort = v.toUShortOrNull() ?: 0u) }
            }
            EditRow(2, 6, stringResource(R.string.http_port), portText(o.httpPort), off, KeyboardType.Number, validate = { it.isEmpty() || isPort(it) }) { v ->
                set { it.copy(httpPort = v.toUShortOrNull() ?: 0u) }
            }
            SwitchRow(3, 6, stringResource(R.string.allow_lan), o.allowLan, stringResource(R.string.allow_lan_detail)) { v -> set { it.copy(allowLan = v) } }
            ListRow(4, 6, stringResource(R.string.authentication), o.authentication, stringResource(R.string.authentication_hint)) { v ->
                set { it.copy(authentication = v) }
            }
            SwitchRow(5, 6, stringResource(R.string.external_controller), o.externalController, stringResource(R.string.external_controller_detail)) { v ->
                set { it.copy(externalController = v) }
            }
        }
        item {
            SectionHeader("Hosts")
            MapRow(0, 1, "Hosts", o.hosts) { v -> set { it.copy(hosts = v) } }
        }
    }
}

private fun portText(port: UShort) = if (port == 0.toUShort()) "" else port.toString()

@Composable
fun NetworkOptionsScreen(vm: AppViewModel, onBack: () -> Unit) {
    val o by vm.options.collectAsStateWithLifecycle()
    val android by vm.androidSettings.collectAsStateWithLifecycle()
    val set = vm::setOptions
    val stacks = listOf(
        null to stringResource(R.string.default_value),
        TunStack.SYSTEM to "System",
        TunStack.GVISOR to "gVisor",
        TunStack.MIXED to "Mixed",
    )
    ToolPage(stringResource(R.string.network), onBack) {
        item {
            SectionHeader(stringResource(R.string.vpn))
            SwitchRow(0, 3, stringResource(R.string.allow_bypass), android.allowBypass, stringResource(R.string.allow_bypass_detail)) { v ->
                vm.updateAndroid { it.copy(allowBypass = v) }
            }
            SwitchRow(1, 3, stringResource(R.string.system_proxy), android.systemProxy, stringResource(R.string.system_proxy_detail)) { v ->
                vm.updateAndroid { it.copy(systemProxy = v) }
            }
            SwitchRow(2, 3, "IPv6", android.ipv6, stringResource(R.string.vpn_ipv6_detail)) { v -> vm.updateAndroid { it.copy(ipv6 = v) } }
            SectionFooter(stringResource(R.string.reconnect_to_apply))
        }
        item {
            SectionHeader(stringResource(R.string.tun))
            ChoiceRow(0, 4, stringResource(R.string.tun_stack), stacks, o.tunStack) { v -> set { it.copy(tunStack = v) } }
            ListRow(1, 4, stringResource(R.string.route_address), o.tunRouteAddress, "0.0.0.0/1") { v -> set { it.copy(tunRouteAddress = v) } }
            ListRow(2, 4, stringResource(R.string.dns_hijack), o.tunDnsHijack, "any:53") { v -> set { it.copy(tunDnsHijack = v) } }
            EditRow(3, 4, stringResource(R.string.interface_name), o.interfaceName, stringResource(R.string.automatic)) { v ->
                set { it.copy(interfaceName = v) }
            }
        }
    }
}

@Composable
fun DnsOptionsScreen(vm: AppViewModel, onBack: () -> Unit) {
    val o by vm.options.collectAsStateWithLifecycle()
    val dns = o.dns
    val set: ((DnsOptions) -> DnsOptions) -> Unit = { change -> vm.setOptions { it.copy(dns = change(it.dns)) } }
    val modes = listOf(DnsMode.NORMAL to "Normal", DnsMode.FAKE_IP to "Fake-IP", DnsMode.REDIR_HOST to "Redir-Host")
    ToolPage(stringResource(R.string.dns), onBack) {
        item {
            SectionHeader(stringResource(R.string.dns_override))
            SwitchRow(0, 1, stringResource(R.string.dns_override), o.overrideDns, stringResource(R.string.dns_override_detail)) { v ->
                vm.setOptions { it.copy(overrideDns = v) }
            }
        }
        if (!o.overrideDns) return@ToolPage
        item {
            SectionHeader(stringResource(R.string.general))
            SwitchRow(0, 9, stringResource(R.string.enable), dns.enable) { v -> set { it.copy(enable = v) } }
            EditRow(1, 9, stringResource(R.string.listen), dns.listen, keyboard = KeyboardType.Uri) { v -> set { it.copy(listen = v) } }
            ChoiceRow(2, 9, stringResource(R.string.enhanced_mode), modes, dns.enhancedMode) { v -> set { it.copy(enhancedMode = v) } }
            EditRow(3, 9, stringResource(R.string.fake_ip_range), dns.fakeIpRange, keyboard = KeyboardType.Uri) { v -> set { it.copy(fakeIpRange = v) } }
            SwitchRow(4, 9, stringResource(R.string.prefer_h3), dns.preferH3) { v -> set { it.copy(preferH3 = v) } }
            SwitchRow(5, 9, stringResource(R.string.use_hosts), dns.useHosts) { v -> set { it.copy(useHosts = v) } }
            SwitchRow(6, 9, stringResource(R.string.use_system_hosts), dns.useSystemHosts) { v -> set { it.copy(useSystemHosts = v) } }
            SwitchRow(7, 9, stringResource(R.string.respect_rules), dns.respectRules) { v -> set { it.copy(respectRules = v) } }
            SwitchRow(8, 9, "IPv6", dns.ipv6) { v -> set { it.copy(ipv6 = v) } }
        }
        item {
            SectionHeader(stringResource(R.string.nameservers))
            ListRow(0, 6, stringResource(R.string.default_nameserver), dns.defaultNameserver, "223.5.5.5") { v -> set { it.copy(defaultNameserver = v) } }
            ListRow(1, 6, "Nameserver", dns.nameserver, "https://doh.pub/dns-query") { v -> set { it.copy(nameserver = v) } }
            ListRow(2, 6, "Fallback", dns.fallback) { v -> set { it.copy(fallback = v) } }
            ListRow(3, 6, stringResource(R.string.proxy_server_nameserver), dns.proxyServerNameserver) { v -> set { it.copy(proxyServerNameserver = v) } }
            MapRow(4, 6, stringResource(R.string.nameserver_policy), dns.nameserverPolicy) { v -> set { it.copy(nameserverPolicy = v) } }
            ListRow(5, 6, stringResource(R.string.fake_ip_filter), dns.fakeIpFilter, "+.lan") { v -> set { it.copy(fakeIpFilter = v) } }
        }
        item {
            val filter = dns.fallbackFilter
            SectionHeader(stringResource(R.string.fallback_filter))
            SwitchRow(0, 5, "GeoIP", filter.geoip) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(geoip = v)) } }
            EditRow(1, 5, stringResource(R.string.geoip_code), filter.geoipCode) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(geoipCode = v)) } }
            ListRow(2, 5, "GeoSite", filter.geosite) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(geosite = v)) } }
            ListRow(3, 5, "IP-CIDR", filter.ipcidr) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(ipcidr = v)) } }
            ListRow(4, 5, stringResource(R.string.domain), filter.domain) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(domain = v)) } }
        }
    }
}

@Composable
fun AdvancedOptionsScreen(vm: AppViewModel, onBack: () -> Unit) {
    val o by vm.options.collectAsStateWithLifecycle()
    ToolPage(stringResource(R.string.advanced), onBack) {
        item {
            SectionHeader(stringResource(R.string.added_rules))
            ListRow(0, 1, stringResource(R.string.added_rules), o.addedRules, "DOMAIN-SUFFIX,example.com,DIRECT") { v ->
                vm.setOptions { it.copy(addedRules = v) }
            }
            SectionFooter(stringResource(R.string.added_rules_detail))
        }
        item {
            SectionHeader(stringResource(R.string.override_script))
            ComingSoonRow()
        }
    }
}

@Composable
fun ComingSoonRow() {
    ValueRow(0, 1, stringResource(R.string.coming_soon), stringResource(R.string.coming_soon_short))
}
