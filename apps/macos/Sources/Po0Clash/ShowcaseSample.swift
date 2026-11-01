import Foundation
import Po0FFI

extension Showcase {
    /// The data of the design demo (docs/design/native-ui/demo/src/logic.js): 24 groups, up to 20 nodes each.
    struct Sample {
        let settings: AppSettings
        let engineOptions: EngineOptions
        let status: Status
        let groups: [ProxyGroup]
        let profiles: [Profile]
        let whitelist: WhitelistState
        let traffic: Traffic
        let trafficHistory: [Traffic]
        let memory: UInt64
        let connections: Connections
        let logs: [LogEntry]
        let exitIp: ExitIp
        let ipQuality: IpQuality
        let intranetIp: IntranetIp

        init(settings: AppSettings, engineOptions: EngineOptions) {
            let now = Int64(Date().timeIntervalSince1970)
            self.settings = settings
            self.engineOptions = engineOptions
            status = Status(
                engine: .running,
                mode: .rule,
                routeMode: .tun,
                profileId: "main",
                currentNode: "东京 03"
            )
            groups = Self.makeGroups()
            profiles = [
                Self.profile("main", "主力订阅", used: 185, total: 500, expire: now + 86400 * 60, selected: true, now: now),
                Self.profile("spare", "备用订阅", used: 12, total: 100, expire: now + 86400 * 137, selected: false, now: now),
                Profile(
                    id: "links", name: "Share links", kind: .links, url: nil, updatedAt: now - 86400, usage: nil,
                    selected: false, autoUpdate: false, updateHours: 0
                ),
            ]
            whitelist = WhitelistState(enabled: true, entries: [
                Self.entry("home", .po0, "家里宽带", "a8f3…91c2", .applied, nil, now),
                Self.entry("office", .po0, "公司", "7bd0…e41a", .applied, nil, now),
                Self.entry("spare", .ggy, "备用线路", "ggy.example/k2f…", .applied, nil, now),
                Self.entry("old", .po0, "旧宽带", "c11e…07bd", .rejected, "token expired", now),
            ])
            let history = Self.makeHistory()
            trafficHistory = history
            traffic = history.last ?? Traffic(up: 0, down: 0)
            memory = 86 * 1_048_576
            connections = Self.makeConnections(now: now)
            logs = Self.makeLogs(now: now)
            exitIp = ExitIp(ip: "198.51.100.24", country: "JP")
            ipQuality = IpQuality(
                ip: "198.51.100.24",
                source: .ipApiIs,
                kind: .hosting,
                level: .good,
                organization: "Example Networks",
                asn: 64500,
                isProxy: false,
                isVpn: false,
                isTor: false,
                isAbuser: false
            )
            intranetIp = IntranetIp(ip: "192.168.1.23", interface: "en0")
        }

        private static let delays: [(name: String, delay: UInt32)] = [
            ("东京 03", 38), ("东京 07", 46), ("东京 11", 49), ("大阪 02", 52), ("大阪 05", 58), ("香港 01", 64),
            ("香港 05", 67), ("香港 IEPL 02", 71), ("台北 01", 83), ("首尔 01", 88), ("首尔 02", 91), ("新加坡 02", 96),
            ("新加坡 05", 104), ("洛杉矶 04", 162), ("洛杉矶 09", 168), ("圣何塞 01", 171), ("法兰克福 01", 612), ("伦敦 03", 0),
        ]

        private static func makeGroups() -> [ProxyGroup] {
            let all = delays.map(\.name)
            let pick = ["节点选择", "自动选择", "香港 01", "东京 03", "新加坡 02", "洛杉矶 04", "DIRECT"]
            typealias Spec = (name: String, kind: String, members: [String])
            let policies: [Spec] = [
                ("节点选择", "Selector", ["自动选择", "DIRECT"] + all),
                ("自动选择", "URLTest", Array(all.prefix(8))),
                ("故障转移", "Fallback", Array(all.prefix(5))),
                ("AI", "Selector", ["新加坡 02", "东京 03", "洛杉矶 04", "圣何塞 01"]),
                ("流媒体", "Selector", ["香港 01", "香港 IEPL 02", "新加坡 02", "东京 07"]),
            ]
            let services = [
                "Netflix", "YouTube", "Disney+", "Spotify", "Telegram", "Discord", "Twitter", "GitHub", "Google",
                "Microsoft", "Apple", "Steam", "PayPal",
            ]
            let serviceSpecs: [Spec] = services.map { (name: $0, kind: "Selector", members: pick) }
            let others: [Spec] = [
                ("日本 IEPL 专线优选节点组（低倍率）", "URLTest", ["东京 03", "东京 07", "东京 11", "大阪 02", "大阪 05"]),
                ("哔哩哔哩", "Selector", ["DIRECT", "香港 01", "台北 01"]),
                ("巴哈姆特", "Selector", ["台北 01", "DIRECT"]),
                ("广告拦截", "Selector", ["REJECT", "DIRECT"]),
                ("国内直连", "Selector", ["DIRECT", "节点选择"]),
                ("漏网之鱼", "Selector", ["节点选择", "DIRECT"]),
            ]
            let specs = policies + serviceSpecs + others
            let current = ["节点选择": "东京 03", "自动选择": "东京 07", "AI": "新加坡 02", "流媒体": "香港 01"]
            let delayByName = Dictionary(uniqueKeysWithValues: delays.map { ($0.name, $0.delay) })
            let kinds = ["Trojan", "Hysteria2", "VLESS", "Shadowsocks"]
            let groupKinds = Dictionary(uniqueKeysWithValues: specs.map { ($0.name, $0.kind) })
            return specs.map { spec in
                let nodes = spec.members.map { name -> Node in
                    let index = all.firstIndex(of: name) ?? 0
                    let kind: String
                    switch name {
                    case "DIRECT": kind = "Direct"
                    case "REJECT": kind = "Reject"
                    default: kind = groupKinds[name] ?? kinds[index % kinds.count]
                    }
                    return Node(name: name, kind: kind, delay: delayByName[name])
                }
                return ProxyGroup(
                    name: spec.name,
                    kind: spec.kind,
                    selectable: spec.kind == "Selector",
                    now: current[spec.name] ?? spec.members.first,
                    nodes: nodes,
                    icon: nil
                )
            }
        }

        private static func profile(
            _ id: String, _ name: String, used: UInt64, total: UInt64, expire: Int64, selected: Bool, now: Int64
        ) -> Profile {
            let gigabyte: UInt64 = 1_073_741_824
            return Profile(
                id: id,
                name: name,
                kind: .subscription,
                url: "https://example.com/\(id).yaml",
                updatedAt: now - 3600,
                usage: Usage(upload: used * gigabyte / 10, download: used * gigabyte * 9 / 10, total: total * gigabyte, expire: expire),
                selected: selected,
                autoUpdate: true,
                updateHours: 24
            )
        }

        private static func entry(
            _ id: String,
            _ kind: WhitelistKind,
            _ name: String,
            _ label: String,
            _ outcome: WhitelistOutcome,
            _ message: String?,
            _ now: Int64
        ) -> WhitelistEntry {
            WhitelistEntry(
                id: id,
                kind: kind,
                name: name,
                label: label,
                result: WhitelistResult(
                    outcome: outcome,
                    ip: outcome == .applied ? "203.0.113.17" : nil,
                    message: message,
                    at: now - 120
                )
            )
        }

        /// Fixed curves rather than random ones, so two screenshots of the same page can be compared.
        private static func makeHistory() -> [Traffic] {
            (0...60).map { second in
                let phase = Double(second)
                let down = 0.45 + 0.22 * sin(phase / 4) + 0.1 * sin(phase * 1.7)
                let up = 0.15 + 0.05 * sin(phase / 3 + 1) + 0.02 * sin(phase * 2.3)
                return Traffic(up: UInt64(up * 6 * 1_048_576), down: UInt64(down * 16 * 1_048_576))
            }
        }

        private static func makeConnections(now: Int64) -> Connections {
            let rows: [(host: String, rule: String, chain: [String], size: UInt64, process: String)] = [
                ("api.github.com", "DOMAIN-SUFFIX", ["东京 03", "节点选择"], 1_258_291, "git"),
                ("www.google.com", "GEOSITE", ["东京 03", "节点选择"], 86016, "Safari"),
                ("chatgpt.com", "GEOSITE", ["新加坡 02", "AI"], 3_774_874, "Safari"),
                ("i.ytimg.com", "GEOSITE", ["香港 01", "流媒体"], 18_874_368, "Safari"),
                ("registry.npmjs.org", "MATCH", ["东京 03", "节点选择"], 655_360, "node"),
                ("www.bilibili.com", "GEOIP", ["DIRECT"], 9_542_041, "Safari"),
                ("update.microsoft.com", "GEOSITE", ["DIRECT"], 225_280, "Edge"),
                ("cdn.discordapp.com", "MATCH", ["东京 03", "节点选择"], 1_048_576, "Discord"),
                ("github.com", "DOMAIN-SUFFIX", ["东京 03", "节点选择"], 419_840, "git"),
                ("open.spotify.com", "GEOSITE", ["香港 01", "流媒体"], 2_411_724, "Spotify"),
                ("claude.ai", "GEOSITE", ["新加坡 02", "AI"], 778_240, "Safari"),
            ]
            let items = rows.enumerated().map { index, row in
                Connection(
                    id: "\(index)",
                    network: "tcp",
                    inbound: "Tun",
                    host: row.host,
                    destination: "\(row.host):443",
                    source: "192.168.1.23",
                    process: row.process,
                    processPath: nil,
                    rule: row.rule,
                    rulePayload: "",
                    chains: row.chain,
                    upload: row.size / 10,
                    download: row.size,
                    start: now - Int64(index * 20)
                )
            }
            return Connections(uploadTotal: 325_058_560, downloadTotal: 4_509_715_456, items: items)
        }

        private static func makeLogs(now: Int64) -> [LogEntry] {
            let lines: [(level: LogLevel, message: String)] = [
                (.info, "[TCP] 127.0.0.1:52144 → api.github.com:443 using 节点选择[东京 03]"),
                (.info, "[TCP] 127.0.0.1:52151 → chatgpt.com:443 using AI[新加坡 02]"),
                (.info, "[UDP] 127.0.0.1:61022 → i.ytimg.com:443 using 流媒体[香港 01]"),
                (.warning, "[DNS] resolve cdn.example.invalid: no such host"),
                (.info, "[TCP] 127.0.0.1:52160 → www.bilibili.com:443 using DIRECT"),
                (.info, "[TCP] 127.0.0.1:52171 → registry.npmjs.org:443 using 节点选择[东京 03]"),
                (.info, "[Provider] 主力订阅 updated"),
                (.error, "[TCP] dial 伦敦 03: i/o timeout"),
                (.info, "[TCP] 127.0.0.1:52194 → github.com:443 using 节点选择[东京 03]"),
                (.debug, "[Sniffer] Sniff TCP [claude.ai] success"),
            ]
            return lines.enumerated().map { index, line in
                LogEntry(level: line.level, message: line.message, at: now - Int64(index * 7))
            }
        }
    }
}
