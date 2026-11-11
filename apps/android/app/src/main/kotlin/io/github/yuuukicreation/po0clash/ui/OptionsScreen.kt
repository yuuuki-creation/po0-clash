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
            ChoiceRow(stringResource(R.string.log_level), levels, o.logLevel) { v -> set { it.copy(logLevel = v) } }
            EditRow(stringResource(R.string.test_url), o.testUrl, default, KeyboardType.Uri) { v -> set { it.copy(testUrl = v) } }
            EditRow(stringResource(R.string.user_agent), o.userAgent, default) { v -> set { it.copy(userAgent = v) } }
            EditRow(
                stringResource(R.string.keep_alive),
                o.keepAliveInterval.takeIf { it > 0u }?.let { stringResource(R.string.seconds, it.toInt()) }.orEmpty(),
                default,
                KeyboardType.Number,
                validate = { it.isEmpty() || it.toUIntOrNull() != null },
            ) { v -> set { it.copy(keepAliveInterval = v.toUIntOrNull() ?: 0u) } }
            SwitchRow(stringResource(R.string.unified_delay), o.unifiedDelay) { v ->
                set { it.copy(unifiedDelay = v) }
            }
            SwitchRow(stringResource(R.string.tcp_concurrent), o.tcpConcurrent) { v -> set { it.copy(tcpConcurrent = v) } }
            ChoiceRow(stringResource(R.string.find_process), findProcess, o.findProcessMode) { v -> set { it.copy(findProcessMode = v) } }
            SwitchRow("IPv6", o.ipv6) { v -> set { it.copy(ipv6 = v) } }
        }
        item {
            SectionHeader(stringResource(R.string.inbound))
            EditRow(stringResource(R.string.mixed_port), o.mixedPort.toString(), keyboard = KeyboardType.Number, validate = ::isPort) { v ->
                set { it.copy(mixedPort = v.toUShort()) }
            }
            EditRow(stringResource(R.string.socks_port), portText(o.socksPort), off, KeyboardType.Number, validate = { it.isEmpty() || isPort(it) }) { v ->
                set { it.copy(socksPort = v.toUShortOrNull() ?: 0u) }
            }
            EditRow(stringResource(R.string.http_port), portText(o.httpPort), off, KeyboardType.Number, validate = { it.isEmpty() || isPort(it) }) { v ->
                set { it.copy(httpPort = v.toUShortOrNull() ?: 0u) }
            }
            SwitchRow(stringResource(R.string.allow_lan), o.allowLan) { v -> set { it.copy(allowLan = v) } }
            ListRow(stringResource(R.string.authentication), o.authentication, stringResource(R.string.authentication_hint)) { v ->
                set { it.copy(authentication = v) }
            }
            SwitchRow(stringResource(R.string.external_controller), o.externalController) { v ->
                set { it.copy(externalController = v) }
            }
        }
        item {
            SectionHeader("Hosts")
            MapRow("Hosts", o.hosts) { v -> set { it.copy(hosts = v) } }
        }
    }
}

private fun portText(port: UShort) = if (port == 0.toUShort()) "" else port.toString()

@Composable
fun NetworkOptionsScreen(vm: AppViewModel, onBack: () -> Unit) {
    val o by vm.options.collectAsStateWithLifecycle()
    val settings by vm.appSettings.collectAsStateWithLifecycle()
    val android = settings.androidVpn
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
            SwitchRow(stringResource(R.string.allow_bypass), android.allowBypass) { v ->
                vm.updateAndroid { it.copy(allowBypass = v) }
            }
            SwitchRow(stringResource(R.string.system_proxy), android.systemProxy) { v ->
                vm.updateAndroid { it.copy(systemProxy = v) }
            }
            SwitchRow("IPv6", android.ipv6) { v -> vm.updateAndroid { it.copy(ipv6 = v) } }
        }
        item {
            SectionHeader(stringResource(R.string.tun))
            ChoiceRow(stringResource(R.string.tun_stack), stacks, o.tunStack) { v -> set { it.copy(tunStack = v) } }
            ListRow(stringResource(R.string.route_address), o.tunRouteAddress, "0.0.0.0/1") { v -> set { it.copy(tunRouteAddress = v) } }
            ListRow(stringResource(R.string.dns_hijack), o.tunDnsHijack, "any:53") { v -> set { it.copy(tunDnsHijack = v) } }
            EditRow(stringResource(R.string.interface_name), o.interfaceName, stringResource(R.string.automatic)) { v ->
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
            SwitchRow(stringResource(R.string.dns_override), o.overrideDns) { v ->
                vm.setOptions { it.copy(overrideDns = v) }
            }
        }
        if (!o.overrideDns) return@ToolPage
        item {
            SectionHeader(stringResource(R.string.general))
            SwitchRow(stringResource(R.string.enable), dns.enable) { v -> set { it.copy(enable = v) } }
            EditRow(stringResource(R.string.listen), dns.listen, keyboard = KeyboardType.Uri) { v -> set { it.copy(listen = v) } }
            ChoiceRow(stringResource(R.string.enhanced_mode), modes, dns.enhancedMode) { v -> set { it.copy(enhancedMode = v) } }
            EditRow(stringResource(R.string.fake_ip_range), dns.fakeIpRange, keyboard = KeyboardType.Uri) { v -> set { it.copy(fakeIpRange = v) } }
            SwitchRow(stringResource(R.string.prefer_h3), dns.preferH3) { v -> set { it.copy(preferH3 = v) } }
            SwitchRow(stringResource(R.string.use_hosts), dns.useHosts) { v -> set { it.copy(useHosts = v) } }
            SwitchRow(stringResource(R.string.use_system_hosts), dns.useSystemHosts) { v -> set { it.copy(useSystemHosts = v) } }
            SwitchRow(stringResource(R.string.respect_rules), dns.respectRules) { v -> set { it.copy(respectRules = v) } }
            SwitchRow("IPv6", dns.ipv6) { v -> set { it.copy(ipv6 = v) } }
        }
        item {
            SectionHeader(stringResource(R.string.nameservers))
            ListRow(stringResource(R.string.default_nameserver), dns.defaultNameserver, "223.5.5.5") { v -> set { it.copy(defaultNameserver = v) } }
            ListRow("Nameserver", dns.nameserver, "https://doh.pub/dns-query") { v -> set { it.copy(nameserver = v) } }
            ListRow("Fallback", dns.fallback) { v -> set { it.copy(fallback = v) } }
            ListRow(stringResource(R.string.proxy_server_nameserver), dns.proxyServerNameserver) { v -> set { it.copy(proxyServerNameserver = v) } }
            MapRow(stringResource(R.string.nameserver_policy), dns.nameserverPolicy) { v -> set { it.copy(nameserverPolicy = v) } }
            ListRow(stringResource(R.string.fake_ip_filter), dns.fakeIpFilter, "+.lan") { v -> set { it.copy(fakeIpFilter = v) } }
        }
        item {
            val filter = dns.fallbackFilter
            SectionHeader(stringResource(R.string.fallback_filter))
            SwitchRow("GeoIP", filter.geoip) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(geoip = v)) } }
            EditRow(stringResource(R.string.geoip_code), filter.geoipCode) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(geoipCode = v)) } }
            ListRow("GeoSite", filter.geosite) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(geosite = v)) } }
            ListRow("IP-CIDR", filter.ipcidr) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(ipcidr = v)) } }
            ListRow(stringResource(R.string.domain), filter.domain) { v -> set { it.copy(fallbackFilter = it.fallbackFilter.copy(domain = v)) } }
        }
    }
}

@Composable
fun AdvancedOptionsScreen(vm: AppViewModel, onBack: () -> Unit) {
    val o by vm.options.collectAsStateWithLifecycle()
    ToolPage(stringResource(R.string.advanced), onBack) {
        item {
            SectionHeader(stringResource(R.string.added_rules))
            ListRow(stringResource(R.string.added_rules), o.addedRules, "DOMAIN-SUFFIX,example.com,DIRECT") { v ->
                vm.setOptions { it.copy(addedRules = v) }
            }
        }
        item { ScriptLibrary(vm) }
    }
}
