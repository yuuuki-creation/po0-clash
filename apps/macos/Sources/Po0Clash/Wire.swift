import Foundation
import Po0FFI

/// The JSON the page exchanges with the shell. It has to equal what serde writes for the core's types on Windows
/// (`crates/core`, camelCase): enum cases go by their Swift names, which UniFFI spells the same way, and a missing
/// optional is `null`.
enum Wire {
    static let unit: Any = NSNull()

    static func text(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    static func name<Case>(_ value: Case) -> String {
        String(describing: value)
    }

    static func optional<Value>(_ value: Value?) -> Any {
        value.map { $0 as Any } ?? NSNull()
    }

    // MARK: Results

    static func status(_ status: Status) -> [String: Any] {
        let engine: [String: Any]
        switch status.engine {
        case .stopped: engine = ["state": "stopped"]
        case .starting: engine = ["state": "starting"]
        case .running: engine = ["state": "running"]
        case .failed(let message): engine = ["state": "failed", "message": message]
        }
        return [
            "engine": engine,
            "mode": name(status.mode),
            "routeMode": name(status.routeMode),
            "profileId": optional(status.profileId),
            "currentNode": optional(status.currentNode),
        ]
    }

    static func traffic(_ traffic: Traffic) -> [String: Any] {
        ["up": traffic.up, "down": traffic.down]
    }

    static func connection(_ item: Connection) -> [String: Any] {
        [
            "id": item.id,
            "network": item.network,
            "inbound": item.inbound,
            "host": item.host,
            "destination": item.destination,
            "source": item.source,
            "process": optional(item.process),
            "processPath": optional(item.processPath),
            "rule": item.rule,
            "rulePayload": item.rulePayload,
            "chains": item.chains,
            "upload": item.upload,
            "download": item.download,
            "start": item.start,
        ]
    }

    static func connections(_ all: Connections) -> [String: Any] {
        [
            "uploadTotal": all.uploadTotal,
            "downloadTotal": all.downloadTotal,
            "items": all.items.map(connection),
        ]
    }

    static func logEntry(_ entry: LogEntry) -> [String: Any] {
        ["level": name(entry.level), "message": entry.message, "at": entry.at]
    }

    static func exitIp(_ exit: ExitIp) -> [String: Any] {
        ["ip": exit.ip, "country": optional(exit.country)]
    }

    static func usage(_ usage: Usage) -> [String: Any] {
        [
            "upload": usage.upload,
            "download": usage.download,
            "total": usage.total,
            "expire": optional(usage.expire),
        ]
    }

    static func profile(_ profile: Profile) -> [String: Any] {
        [
            "id": profile.id,
            "name": profile.name,
            "kind": name(profile.kind),
            "url": optional(profile.url),
            "updatedAt": optional(profile.updatedAt),
            "usage": optional(profile.usage.map(usage)),
            "selected": profile.selected,
            "autoUpdate": profile.autoUpdate,
            "updateHours": profile.updateHours,
        ]
    }

    static func importResult(_ result: ImportResult) -> [String: Any] {
        ["profile": profile(result.profile), "added": result.added]
    }

    static func group(_ group: ProxyGroup) -> [String: Any] {
        [
            "name": group.name,
            "kind": group.kind,
            "selectable": group.selectable,
            "now": optional(group.now),
            "nodes": group.nodes.map { node -> [String: Any] in
                ["name": node.name, "kind": node.kind, "delay": optional(node.delay)]
            },
            "icon": optional(group.icon),
        ]
    }

    static func whitelist(_ state: WhitelistState) -> [String: Any] {
        [
            "enabled": state.enabled,
            "entries": state.entries.map { entry -> [String: Any] in
                [
                    "id": entry.id,
                    "kind": name(entry.kind),
                    "name": entry.name,
                    "label": entry.label,
                    "result": optional(entry.result.map(whitelistResult)),
                ]
            },
        ]
    }

    private static func whitelistResult(_ result: WhitelistResult) -> [String: Any] {
        [
            "outcome": name(result.outcome),
            "ip": optional(result.ip),
            "message": optional(result.message),
            "at": result.at,
        ]
    }

    static func provider(_ provider: Provider) -> [String: Any] {
        [
            "name": provider.name,
            "kind": name(provider.kind),
            "vehicle": provider.vehicle,
            "behavior": optional(provider.behavior),
            "count": provider.count,
            "updatedAt": optional(provider.updatedAt),
            "usage": optional(provider.usage.map(usage)),
        ]
    }

    static func rule(_ rule: Rule) -> [String: Any] {
        ["kind": rule.kind, "payload": rule.payload, "proxy": rule.proxy]
    }

    static func geoFile(_ file: GeoFile) -> [String: Any] {
        ["name": file.name, "size": optional(file.size), "modified": optional(file.modified)]
    }

    static func intranetIp(_ address: IntranetIp) -> [String: Any] {
        ["ip": address.ip, "interface": optional(address.interface)]
    }

    static func script(_ script: Script) -> [String: Any] {
        ["id": script.id, "name": script.name, "content": script.content]
    }

    static func shareNode(_ node: ShareNode) -> [String: Any] {
        ["name": node.name, "kind": node.kind]
    }

    static func license(_ license: License) -> [String: Any] {
        ["name": license.name, "version": license.version, "license": license.license, "url": license.url]
    }

    static func release(_ release: Release) -> [String: Any] {
        ["version": release.version, "url": release.url, "notes": release.notes]
    }

    static func profileParts(_ parts: ProfileParts) -> [String: Any] {
        ["groups": parts.groups, "rules": parts.rules]
    }

    static func profileOverride(_ value: ProfileOverride) -> [String: Any] {
        [
            "mode": name(value.mode),
            "addedRules": value.addedRules,
            "disabledGlobalRules": value.disabledGlobalRules,
            "matchTarget": optional(value.matchTarget),
            "scriptId": optional(value.scriptId),
            "customGroups": value.customGroups,
            "customRules": value.customRules,
        ]
    }

    private static func webDav(_ dav: WebDav) -> [String: Any] {
        ["url": dav.url, "user": dav.user, "password": dav.password, "fileName": dav.fileName]
    }

    private static func hotkey(_ hotkey: Hotkey) -> [String: Any] {
        ["action": name(hotkey.action), "key": hotkey.key, "modifiers": hotkey.modifiers.map(name)]
    }

    static func appSettings(_ settings: AppSettings) -> [String: Any] {
        let access = settings.accessControl
        let accessControl: [String: Any] = [
            "enabled": access.enabled,
            "mode": name(access.mode),
            "accepted": access.accepted,
            "rejected": access.rejected,
            "sort": name(access.sort),
            "hideSystemApps": access.hideSystemApps,
            "hideOfflineApps": access.hideOfflineApps,
        ]
        let androidVpn: [String: Any] = [
            "allowBypass": settings.androidVpn.allowBypass,
            "systemProxy": settings.androidVpn.systemProxy,
            "ipv6": settings.androidVpn.ipv6,
        ]
        var json: [String: Any] = [:]
        json["language"] = optional(settings.language)
        json["themeMode"] = name(settings.themeMode)
        json["themeColor"] = settings.themeColor
        json["themeColors"] = settings.themeColors
        json["schemeVariant"] = name(settings.schemeVariant)
        json["pureBlack"] = settings.pureBlack
        json["textScale"] = optional(settings.textScale)
        json["launchAtLogin"] = settings.launchAtLogin
        json["silentLaunch"] = settings.silentLaunch
        json["autoConnect"] = settings.autoConnect
        json["minimizeOnClose"] = settings.minimizeOnClose
        json["hideFromRecents"] = settings.hideFromRecents
        json["pageAnimation"] = settings.pageAnimation
        json["showNavLabels"] = settings.showNavLabels
        json["captureLogs"] = settings.captureLogs
        json["closeConnectionsOnSwitch"] = settings.closeConnectionsOnSwitch
        json["onlyProxyTraffic"] = settings.onlyProxyTraffic
        json["notificationStopButton"] = settings.notificationStopButton
        json["autoCheckUpdate"] = settings.autoCheckUpdate
        json["checkCertificate"] = settings.checkCertificate
        json["traySpeed"] = settings.traySpeed
        json["crashReports"] = settings.crashReports
        json["crashReportsAsked"] = settings.crashReportsAsked
        json["disclaimerAccepted"] = settings.disclaimerAccepted
        json["developerMode"] = settings.developerMode
        json["proxiesLayout"] = name(settings.proxiesLayout)
        json["proxiesSort"] = name(settings.proxiesSort)
        json["proxiesDensity"] = name(settings.proxiesDensity)
        json["proxyTileStyle"] = name(settings.proxyTileStyle)
        json["groupIconStyle"] = name(settings.groupIconStyle)
        json["dashboardCards"] = settings.dashboardCards.map(name)
        json["homeCards"] = settings.homeCards.map(name)
        json["hotkeys"] = settings.hotkeys.map(hotkey)
        json["webdav"] = optional(settings.webdav.map(webDav))
        json["restoreStrategy"] = name(settings.restoreStrategy)
        json["accessControl"] = accessControl
        json["androidVpn"] = androidVpn
        json["excludedSsids"] = settings.excludedSsids
        return json
    }

    static func engineOptions(_ options: EngineOptions) -> [String: Any] {
        let geox: [String: Any] = [
            "geoip": options.geoxUrl.geoip,
            "geosite": options.geoxUrl.geosite,
            "mmdb": options.geoxUrl.mmdb,
            "asn": options.geoxUrl.asn,
        ]
        var json: [String: Any] = [:]
        json["mixedPort"] = options.mixedPort
        json["socksPort"] = options.socksPort
        json["httpPort"] = options.httpPort
        json["allowLan"] = options.allowLan
        json["authentication"] = options.authentication
        json["logLevel"] = name(options.logLevel)
        json["ipv6"] = options.ipv6
        json["unifiedDelay"] = options.unifiedDelay
        json["tcpConcurrent"] = options.tcpConcurrent
        json["findProcessMode"] = name(options.findProcessMode)
        json["keepAliveInterval"] = options.keepAliveInterval
        json["interfaceName"] = options.interfaceName
        json["testUrl"] = options.testUrl
        json["userAgent"] = options.userAgent
        json["hosts"] = options.hosts
        json["externalController"] = options.externalController
        json["tunStack"] = optional(options.tunStack.map(name))
        json["tunRouteAddress"] = options.tunRouteAddress
        json["tunDnsHijack"] = options.tunDnsHijack
        json["geodataLoader"] = name(options.geodataLoader)
        json["geoAutoUpdate"] = options.geoAutoUpdate
        json["geoUpdateInterval"] = options.geoUpdateInterval
        json["geoxUrl"] = geox
        json["overrideDns"] = options.overrideDns
        json["dns"] = dns(options.dns)
        json["addedRules"] = options.addedRules
        json["bypassDomains"] = options.bypassDomains
        json["appendSystemDns"] = options.appendSystemDns
        json["autoSetSystemDns"] = options.autoSetSystemDns
        return json
    }

    private static func dns(_ dns: DnsOptions) -> [String: Any] {
        let filter = dns.fallbackFilter
        let fallbackFilter: [String: Any] = [
            "geoip": filter.geoip,
            "geoipCode": filter.geoipCode,
            "geosite": filter.geosite,
            "ipcidr": filter.ipcidr,
            "domain": filter.domain,
        ]
        var json: [String: Any] = [:]
        json["enable"] = dns.enable
        json["listen"] = dns.listen
        json["preferH3"] = dns.preferH3
        json["useHosts"] = dns.useHosts
        json["useSystemHosts"] = dns.useSystemHosts
        json["respectRules"] = dns.respectRules
        json["ipv6"] = dns.ipv6
        json["enhancedMode"] = name(dns.enhancedMode)
        json["fakeIpRange"] = dns.fakeIpRange
        json["fakeIpFilter"] = dns.fakeIpFilter
        json["defaultNameserver"] = dns.defaultNameserver
        json["nameserver"] = dns.nameserver
        json["fallback"] = dns.fallback
        json["proxyServerNameserver"] = dns.proxyServerNameserver
        json["nameserverPolicy"] = dns.nameserverPolicy
        json["fallbackFilter"] = fallbackFilter
        return json
    }

    // MARK: Arguments

    static let modes: [Mode] = [.rule, .global, .direct]
    static let routeModes: [RouteMode] = [.systemProxy, .tun]
    private static let themeModes: [ThemeMode] = [.system, .light, .dark]
    private static let schemeVariants: [SchemeVariant] = [
        .tonalSpot, .fidelity, .monochrome, .neutral, .vibrant, .expressive, .content, .rainbow, .fruitSalad,
    ]
    private static let proxiesLayouts: [ProxiesLayout] = [.tabs, .list]
    private static let proxiesSorts: [ProxiesSort] = [.profile, .delay, .name]
    private static let proxiesDensities: [ProxiesDensity] = [.loose, .standard, .tight]
    private static let proxyTileStyles: [ProxyTileStyle] = [.detailed, .compact, .minimal]
    private static let groupIconStyles: [GroupIconStyle] = [.standard, .iconOnly, .hidden]
    private static let dashboardCards: [DashboardCard] = [
        .currentNode, .speed, .mode, .takeover, .whitelist, .traffic, .connections, .memory, .intranetIp,
        .subscription, .exitIp,
    ]
    private static let homeCards: [HomeCard] = [.profile, .proxy, .network, .mode, .traffic, .whitelist, .ip, .info]
    private static let hotkeyActions: [HotkeyAction] = [.connect, .showWindow, .mode, .systemProxy, .tun]
    private static let hotkeyModifiers: [HotkeyModifier] = [.control, .alt, .shift, .meta]
    private static let restoreStrategies: [RestoreStrategy] = [.compatible, .override]
    private static let accessControlModes: [AccessControlMode] = [.rejectSelected, .acceptSelected]
    private static let appSorts: [AppSort] = [.unsorted, .name, .installTime]
    private static let logLevels: [LogLevel] = [.debug, .info, .warning, .error, .silent]
    private static let findProcessModes: [FindProcessMode] = [.off, .strict, .always]
    private static let tunStacks: [TunStack] = [.system, .gvisor, .mixed]
    private static let geodataLoaders: [GeodataLoader] = [.standard, .memconservative]
    private static let dnsModes: [DnsMode] = [.normal, .fakeIp, .redirHost]
    private static let overrideModes: [OverrideMode] = [.standard, .script, .custom]

    static func bool(_ value: Any) throws -> Bool {
        guard let result = value as? Bool else { throw MessageError("expected a boolean") }
        return result
    }

    static func string(_ value: Any) throws -> String {
        guard let result = value as? String else { throw MessageError("expected a string") }
        return result
    }

    static func strings(_ value: Any) throws -> [String] {
        guard let result = value as? [String] else { throw MessageError("expected a list of strings") }
        return result
    }

    static func stringMap(_ value: Any) throws -> [String: String] {
        guard let result = value as? [String: String] else { throw MessageError("expected a map of strings") }
        return result
    }

    static func int(_ value: Any) throws -> Int {
        guard let number = value as? NSNumber, number.doubleValue == Double(number.intValue) else {
            throw MessageError("expected a whole number")
        }
        return number.intValue
    }

    static func uint16(_ value: Any) throws -> UInt16 {
        guard let result = UInt16(exactly: try int(value)) else { throw MessageError("number out of range") }
        return result
    }

    static func uint32(_ value: Any) throws -> UInt32 {
        guard let result = UInt32(exactly: try int(value)) else { throw MessageError("number out of range") }
        return result
    }

    static func nullable<Value>(_ read: @escaping (Any) throws -> Value) -> (Any) throws -> Value? {
        { value in
            if value is NSNull { return nil }
            return try read(value)
        }
    }

    static func list<Value>(_ read: @escaping (Any) throws -> Value) -> (Any) throws -> [Value] {
        { value in
            guard let items = value as? [Any] else { throw MessageError("expected a list") }
            return try items.map(read)
        }
    }

    static func choice<Case>(_ all: [Case]) -> (Any) throws -> Case {
        { value in
            let text = try string(value)
            guard let match = all.first(where: { name($0) == text }) else {
                throw MessageError("unknown value \(text)")
            }
            return match
        }
    }

    /// serde fills a missing field of the settings and options from their defaults; here it keeps `base`, the
    /// current value, which is the same for a page that sends back what it read.
    static func readAppSettings(_ value: Any, base: AppSettings) throws -> AppSettings {
        let fields = try Fields(value)
        var settings = base
        try fields.take("language", into: &settings.language, nullable(string))
        try fields.take("themeMode", into: &settings.themeMode, choice(themeModes))
        try fields.take("themeColor", into: &settings.themeColor, uint32)
        try fields.take("themeColors", into: &settings.themeColors, list(uint32))
        try fields.take("schemeVariant", into: &settings.schemeVariant, choice(schemeVariants))
        try fields.take("pureBlack", into: &settings.pureBlack, bool)
        try fields.take("textScale", into: &settings.textScale, nullable(uint16))
        try fields.take("launchAtLogin", into: &settings.launchAtLogin, bool)
        try fields.take("silentLaunch", into: &settings.silentLaunch, bool)
        try fields.take("autoConnect", into: &settings.autoConnect, bool)
        try fields.take("minimizeOnClose", into: &settings.minimizeOnClose, bool)
        try fields.take("hideFromRecents", into: &settings.hideFromRecents, bool)
        try fields.take("pageAnimation", into: &settings.pageAnimation, bool)
        try fields.take("showNavLabels", into: &settings.showNavLabels, bool)
        try fields.take("captureLogs", into: &settings.captureLogs, bool)
        try fields.take("closeConnectionsOnSwitch", into: &settings.closeConnectionsOnSwitch, bool)
        try fields.take("onlyProxyTraffic", into: &settings.onlyProxyTraffic, bool)
        try fields.take("notificationStopButton", into: &settings.notificationStopButton, bool)
        try fields.take("autoCheckUpdate", into: &settings.autoCheckUpdate, bool)
        try fields.take("checkCertificate", into: &settings.checkCertificate, bool)
        try fields.take("traySpeed", into: &settings.traySpeed, bool)
        try fields.take("crashReports", into: &settings.crashReports, bool)
        try fields.take("crashReportsAsked", into: &settings.crashReportsAsked, bool)
        try fields.take("disclaimerAccepted", into: &settings.disclaimerAccepted, bool)
        try fields.take("developerMode", into: &settings.developerMode, bool)
        try fields.take("proxiesLayout", into: &settings.proxiesLayout, choice(proxiesLayouts))
        try fields.take("proxiesSort", into: &settings.proxiesSort, choice(proxiesSorts))
        try fields.take("proxiesDensity", into: &settings.proxiesDensity, choice(proxiesDensities))
        try fields.take("proxyTileStyle", into: &settings.proxyTileStyle, choice(proxyTileStyles))
        try fields.take("groupIconStyle", into: &settings.groupIconStyle, choice(groupIconStyles))
        try fields.take("dashboardCards", into: &settings.dashboardCards, list(choice(dashboardCards)))
        try fields.take("homeCards", into: &settings.homeCards, list(choice(homeCards)))
        try fields.take("hotkeys", into: &settings.hotkeys, list(readHotkey))
        try fields.take("webdav", into: &settings.webdav, nullable(readWebDav))
        try fields.take("restoreStrategy", into: &settings.restoreStrategy, choice(restoreStrategies))
        try fields.take("excludedSsids", into: &settings.excludedSsids, strings)

        if let value = fields.values["accessControl"] {
            let access = try Fields(value)
            try access.take("enabled", into: &settings.accessControl.enabled, bool)
            try access.take("mode", into: &settings.accessControl.mode, choice(accessControlModes))
            try access.take("accepted", into: &settings.accessControl.accepted, strings)
            try access.take("rejected", into: &settings.accessControl.rejected, strings)
            try access.take("sort", into: &settings.accessControl.sort, choice(appSorts))
            try access.take("hideSystemApps", into: &settings.accessControl.hideSystemApps, bool)
            try access.take("hideOfflineApps", into: &settings.accessControl.hideOfflineApps, bool)
        }
        if let value = fields.values["androidVpn"] {
            let vpn = try Fields(value)
            try vpn.take("allowBypass", into: &settings.androidVpn.allowBypass, bool)
            try vpn.take("systemProxy", into: &settings.androidVpn.systemProxy, bool)
            try vpn.take("ipv6", into: &settings.androidVpn.ipv6, bool)
        }
        return settings
    }

    private static func readHotkey(_ value: Any) throws -> Hotkey {
        let fields = try Fields(value)
        var modifiers: [HotkeyModifier] = []
        try fields.take("modifiers", into: &modifiers, list(choice(hotkeyModifiers)))
        return Hotkey(
            action: try fields.required("action", choice(hotkeyActions)),
            key: try fields.required("key", string),
            modifiers: modifiers
        )
    }

    static func readWebDav(_ value: Any) throws -> WebDav {
        let fields = try Fields(value)
        return WebDav(
            url: try fields.required("url", string),
            user: try fields.required("user", string),
            password: try fields.required("password", string),
            fileName: try fields.required("fileName", string)
        )
    }

    static func readEngineOptions(_ value: Any, base: EngineOptions) throws -> EngineOptions {
        let fields = try Fields(value)
        var options = base
        try fields.take("mixedPort", into: &options.mixedPort, uint16)
        try fields.take("socksPort", into: &options.socksPort, uint16)
        try fields.take("httpPort", into: &options.httpPort, uint16)
        try fields.take("allowLan", into: &options.allowLan, bool)
        try fields.take("authentication", into: &options.authentication, strings)
        try fields.take("logLevel", into: &options.logLevel, choice(logLevels))
        try fields.take("ipv6", into: &options.ipv6, bool)
        try fields.take("unifiedDelay", into: &options.unifiedDelay, bool)
        try fields.take("tcpConcurrent", into: &options.tcpConcurrent, bool)
        try fields.take("findProcessMode", into: &options.findProcessMode, choice(findProcessModes))
        try fields.take("keepAliveInterval", into: &options.keepAliveInterval, uint32)
        try fields.take("interfaceName", into: &options.interfaceName, string)
        try fields.take("testUrl", into: &options.testUrl, string)
        try fields.take("userAgent", into: &options.userAgent, string)
        try fields.take("hosts", into: &options.hosts, stringMap)
        try fields.take("externalController", into: &options.externalController, bool)
        try fields.take("tunStack", into: &options.tunStack, nullable(choice(tunStacks)))
        try fields.take("tunRouteAddress", into: &options.tunRouteAddress, strings)
        try fields.take("tunDnsHijack", into: &options.tunDnsHijack, strings)
        try fields.take("geodataLoader", into: &options.geodataLoader, choice(geodataLoaders))
        try fields.take("geoAutoUpdate", into: &options.geoAutoUpdate, bool)
        try fields.take("geoUpdateInterval", into: &options.geoUpdateInterval, uint32)
        try fields.take("overrideDns", into: &options.overrideDns, bool)
        try fields.take("addedRules", into: &options.addedRules, strings)
        try fields.take("bypassDomains", into: &options.bypassDomains, strings)
        try fields.take("appendSystemDns", into: &options.appendSystemDns, bool)
        try fields.take("autoSetSystemDns", into: &options.autoSetSystemDns, bool)

        if let value = fields.values["geoxUrl"] {
            let geox = try Fields(value)
            try geox.take("geoip", into: &options.geoxUrl.geoip, string)
            try geox.take("geosite", into: &options.geoxUrl.geosite, string)
            try geox.take("mmdb", into: &options.geoxUrl.mmdb, string)
            try geox.take("asn", into: &options.geoxUrl.asn, string)
        }
        if let value = fields.values["dns"] {
            let dns = try Fields(value)
            try dns.take("enable", into: &options.dns.enable, bool)
            try dns.take("listen", into: &options.dns.listen, string)
            try dns.take("preferH3", into: &options.dns.preferH3, bool)
            try dns.take("useHosts", into: &options.dns.useHosts, bool)
            try dns.take("useSystemHosts", into: &options.dns.useSystemHosts, bool)
            try dns.take("respectRules", into: &options.dns.respectRules, bool)
            try dns.take("ipv6", into: &options.dns.ipv6, bool)
            try dns.take("enhancedMode", into: &options.dns.enhancedMode, choice(dnsModes))
            try dns.take("fakeIpRange", into: &options.dns.fakeIpRange, string)
            try dns.take("fakeIpFilter", into: &options.dns.fakeIpFilter, strings)
            try dns.take("defaultNameserver", into: &options.dns.defaultNameserver, strings)
            try dns.take("nameserver", into: &options.dns.nameserver, strings)
            try dns.take("fallback", into: &options.dns.fallback, strings)
            try dns.take("proxyServerNameserver", into: &options.dns.proxyServerNameserver, strings)
            try dns.take("nameserverPolicy", into: &options.dns.nameserverPolicy, stringMap)
            if let value = dns.values["fallbackFilter"] {
                let filter = try Fields(value)
                try filter.take("geoip", into: &options.dns.fallbackFilter.geoip, bool)
                try filter.take("geoipCode", into: &options.dns.fallbackFilter.geoipCode, string)
                try filter.take("geosite", into: &options.dns.fallbackFilter.geosite, strings)
                try filter.take("ipcidr", into: &options.dns.fallbackFilter.ipcidr, strings)
                try filter.take("domain", into: &options.dns.fallbackFilter.domain, strings)
            }
        }
        return options
    }

    static func readProfileEdit(_ value: Any) throws -> ProfileEdit {
        let fields = try Fields(value)
        var url: String?
        try fields.take("url", into: &url, nullable(string))
        return ProfileEdit(
            name: try fields.required("name", string),
            url: url,
            autoUpdate: try fields.required("autoUpdate", bool),
            updateHours: try fields.required("updateHours", uint32)
        )
    }

    static func readProfileOverride(_ value: Any) throws -> ProfileOverride {
        let fields = try Fields(value)
        var result = ProfileOverride(
            mode: .standard, addedRules: [], disabledGlobalRules: [], matchTarget: nil, scriptId: nil,
            customGroups: "", customRules: []
        )
        try fields.take("mode", into: &result.mode, choice(overrideModes))
        try fields.take("addedRules", into: &result.addedRules, strings)
        try fields.take("disabledGlobalRules", into: &result.disabledGlobalRules, strings)
        try fields.take("matchTarget", into: &result.matchTarget, nullable(string))
        try fields.take("scriptId", into: &result.scriptId, nullable(string))
        try fields.take("customGroups", into: &result.customGroups, string)
        try fields.take("customRules", into: &result.customRules, strings)
        return result
    }

    static func readScript(_ value: Any) throws -> Script {
        let fields = try Fields(value)
        return Script(
            id: try fields.required("id", string),
            name: try fields.required("name", string),
            content: try fields.required("content", string)
        )
    }
}

/// A JSON object from the page: a command's arguments, or one of the records inside them.
struct Fields {
    let values: [String: Any]

    init(_ value: Any) throws {
        guard let values = value as? [String: Any] else { throw MessageError("expected an object") }
        self.values = values
    }

    func take<Value>(_ key: String, into target: inout Value, _ read: (Any) throws -> Value) throws {
        guard let value = values[key] else { return }
        target = try parse(key, value, read)
    }

    func raw(_ key: String) throws -> Any {
        guard let value = values[key] else { throw MessageError("missing field \(key)") }
        return value
    }

    func required<Value>(_ key: String, _ read: (Any) throws -> Value) throws -> Value {
        try parse(key, try raw(key), read)
    }

    private func parse<Value>(_ key: String, _ value: Any, _ read: (Any) throws -> Value) throws -> Value {
        do {
            return try read(value)
        } catch {
            throw MessageError("\(key): \(describe(error))")
        }
    }
}
