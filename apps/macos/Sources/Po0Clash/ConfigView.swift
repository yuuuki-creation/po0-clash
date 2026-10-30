import Po0FFI
import SwiftUI

/// FlClash's basic configuration: general, inbound, virtual network card, hosts and DNS.
struct BasicConfigView: View {
    var body: some View {
        EngineOptionsForm { $options in
            Section("General") {
                Picker("Log level", selection: $options.logLevel) {
                    Text("Debug").tag(LogLevel.debug)
                    Text("Info").tag(LogLevel.info)
                    Text("Warning").tag(LogLevel.warning)
                    Text("Error").tag(LogLevel.error)
                    Text("Silent").tag(LogLevel.silent)
                }
                TextField("UA", text: $options.userAgent, prompt: Text("Default"))
                TextField("Test URL", text: $options.testUrl)
                TextField("TCP keep-alive interval (seconds)", value: $options.keepAliveInterval, format: .number)
                Picker(selection: $options.findProcessMode) {
                    Text("Off").tag(FindProcessMode.off)
                    Text("Strict").tag(FindProcessMode.strict)
                    Text("Always").tag(FindProcessMode.always)
                } label: {
                    Text("Find process")
                    Text("Enabling causes some performance loss")
                }
                Toggle(isOn: $options.unifiedDelay) {
                    Text("Unified delay")
                    Text("Remove extra delays such as handshakes")
                }
                Toggle(isOn: $options.tcpConcurrent) {
                    Text("TCP concurrent")
                    Text("Allow concurrent TCP connections")
                }
                Toggle(isOn: $options.externalController) {
                    Text("External controller")
                    Text("Panels such as metacubexd can control the engine on port 9090")
                }
            }
            Section("Inbound") {
                TextField("Mixed port", value: $options.mixedPort, format: .number.grouping(.never))
                TextField(
                    "SOCKS port",
                    value: $options.socksPort.offWhenZero,
                    format: .number.grouping(.never),
                    prompt: Text("Off")
                )
                TextField(
                    "HTTP port",
                    value: $options.httpPort.offWhenZero,
                    format: .number.grouping(.never),
                    prompt: Text("Off")
                )
                Toggle(isOn: $options.allowLan) {
                    Text("Allow LAN")
                    Text("Allow proxy access over the LAN")
                }
                Toggle(isOn: $options.ipv6) {
                    Text(verbatim: "IPv6")
                    Text("When enabled, IPv6 traffic can be received")
                }
                LinesEditor("Authentication", detail: "user:password, one per line", lines: $options.authentication)
            }
            Section("Virtual network card") {
                Picker("Stack mode", selection: $options.tunStack) {
                    Text("Default").tag(TunStack?.none)
                    Text(verbatim: "System").tag(TunStack?.some(.system))
                    Text(verbatim: "gVisor").tag(TunStack?.some(.gvisor))
                    Text(verbatim: "Mixed").tag(TunStack?.some(.mixed))
                }
                TextField("Interface name", text: $options.interfaceName, prompt: Text("Automatic"))
                LinesEditor("Route addresses", detail: "CIDR, one per line", lines: $options.tunRouteAddress)
                LinesEditor("DNS hijacking", detail: "such as any:53, one per line", lines: $options.tunDnsHijack)
            }
            Section {
                PairsEditor("Hosts", detail: "domain = address, one per line", pairs: $options.hosts)
            }
            Section("DNS") {
                Toggle(isOn: $options.overrideDns) {
                    Text("Override DNS")
                    Text("When enabled, the DNS options in the profile are overridden")
                }
                if options.overrideDns {
                    Toggle("Enable", isOn: $options.dns.enable)
                    TextField("Listen", text: $options.dns.listen, prompt: Text("Off"))
                    Picker("DNS mode", selection: $options.dns.enhancedMode) {
                        Text("Normal").tag(DnsMode.normal)
                        Text(verbatim: "Fake-IP").tag(DnsMode.fakeIp)
                        Text(verbatim: "Redir-host").tag(DnsMode.redirHost)
                    }
                    TextField("Fake-IP range", text: $options.dns.fakeIpRange)
                    Toggle(isOn: $options.dns.ipv6) { Text(verbatim: "IPv6") }
                    Toggle("Prefer HTTP/3 for DoH", isOn: $options.dns.preferH3)
                    Toggle("Use hosts", isOn: $options.dns.useHosts)
                    Toggle("Use system hosts", isOn: $options.dns.useSystemHosts)
                    Toggle(isOn: $options.dns.respectRules) {
                        Text("Respect rules")
                        Text("DNS connections follow rules; requires proxy-server-nameserver")
                    }
                }
            }
            if options.overrideDns {
                Section("Nameserver") {
                    LinesEditor("Default nameserver", lines: $options.dns.defaultNameserver)
                    LinesEditor("Nameserver", lines: $options.dns.nameserver)
                    LinesEditor("Fallback", lines: $options.dns.fallback)
                    LinesEditor("Proxy nameserver", lines: $options.dns.proxyServerNameserver)
                    PairsEditor(
                        "Nameserver policy",
                        detail: "domain = server, one per line",
                        pairs: $options.dns.nameserverPolicy
                    )
                    LinesEditor("Fake-IP filter", lines: $options.dns.fakeIpFilter)
                }
                Section("Fallback filter") {
                    Toggle(isOn: $options.dns.fallbackFilter.geoip) { Text(verbatim: "GeoIP") }
                    TextField("GeoIP code", text: $options.dns.fallbackFilter.geoipCode)
                    LinesEditor("GeoSite", lines: $options.dns.fallbackFilter.geosite)
                    LinesEditor("IP/CIDR", lines: $options.dns.fallbackFilter.ipcidr)
                    LinesEditor("Domain", lines: $options.dns.fallbackFilter.domain)
                }
            }
        }
    }
}

/// FlClash's advanced configuration: rules added in front of every profile's own.
struct AdvancedConfigView: View {
    var body: some View {
        EngineOptionsForm { $options in
            Section {
                LinesEditor(
                    "Added rules",
                    detail: "Matched before the profile's own rules, one per line, such as DOMAIN,example.com,DIRECT",
                    lines: $options.addedRules
                )
            }
            Section {
                LabeledContent("Override scripts") {
                    Text("Coming soon.").foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// FlClash's resources: the geo databases, where they come from, and the profile's providers.
struct ResourcesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var files: [GeoFile] = []
    @State private var providers: Result<[Provider], MessageError> = .success([])
    @State private var updating: Set<String> = []

    var body: some View {
        EngineOptionsForm { $options in
            Section("Geo resources") {
                ForEach(files, id: \.name) { file in
                    LabeledContent(file.name) {
                        Text(verbatim: describe(file)).foregroundStyle(.secondary)
                    }
                }
                LabeledContent {
                    updateButton(id: "geo") { await model.updateGeo() }
                } label: {
                    Text("Update now")
                    Text("Downloads all four databases again.")
                }
                Toggle(isOn: Binding(
                    get: { options.geodataLoader == .memconservative },
                    set: { options.geodataLoader = $0 ? .memconservative : .standard }
                )) {
                    Text("Geo low-memory mode")
                    Text("Use the low-memory Geo loader")
                }
                Toggle("Auto update", isOn: $options.geoAutoUpdate)
                if options.geoAutoUpdate {
                    TextField("Auto-update interval (hours)", value: $options.geoUpdateInterval, format: .number)
                }
            }
            Section("Download addresses") {
                TextField(text: $options.geoxUrl.geoip) { Text(verbatim: "GeoIP") }
                TextField(text: $options.geoxUrl.geosite) { Text(verbatim: "GeoSite") }
                TextField(text: $options.geoxUrl.mmdb) { Text(verbatim: "MMDB") }
                TextField(text: $options.geoxUrl.asn) { Text(verbatim: "ASN") }
            }
            switch providers {
            case .failure:
                Section("External resources") {
                    Text("Connect to see the profile's external resources.").foregroundStyle(.secondary)
                }
            case .success(let items) where items.isEmpty:
                Section("External resources") {
                    Text("The profile has no external resources.").foregroundStyle(.secondary)
                }
            case .success(let items):
                providerSection("Proxy providers", items.filter { $0.kind == .proxy })
                providerSection("Rule providers", items.filter { $0.kind == .rule })
            }
        }
        .task { await reload() }
    }

    @ViewBuilder
    private func providerSection(_ title: LocalizedStringKey, _ items: [Provider]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items, id: \.name) { provider in
                    LabeledContent {
                        updateButton(id: "\(provider.kind)/\(provider.name)") { await model.updateProvider(provider) }
                    } label: {
                        Text(verbatim: provider.name)
                        Text(verbatim: summary(provider))
                    }
                }
            }
        }
    }

    private func updateButton(id: String, action: @escaping () async -> Void) -> some View {
        Button("Update") {
            updating.insert(id)
            Task {
                await action()
                updating.remove(id)
                await reload()
            }
        }
        .disabled(updating.contains(id))
    }

    private func reload() async {
        files = await model.geoFiles()
        providers = await model.providers()
    }

    private func describe(_ file: GeoFile) -> String {
        guard let size = file.size else { return String(localized: "Not downloaded") }
        let parts = [Format.bytes(size), file.modified.map(Format.ago)]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    private func summary(_ provider: Provider) -> String {
        let count = Int(provider.count)
        let size = provider.kind == .proxy
            ? Format.nodeCount(count)
            : count == 1 ? String(localized: "1 rule") : String(localized: "\(count) rules")
        return [provider.vehicle, size, provider.updatedAt.map(Format.ago)].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Edits a copy of the engine options and applies it from a bar that shows while there are changes: every apply
/// reloads the engine.
private struct EngineOptionsForm<Content: View>: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft: EngineOptions?
    @State private var applying = false
    @ViewBuilder let content: (Binding<EngineOptions>) -> Content

    var body: some View {
        if let saved = model.engineOptions {
            Form {
                content(Binding(get: { draft ?? saved }, set: { draft = $0 }))
            }
            .formStyle(.grouped)
            .safeAreaInset(edge: .bottom) {
                if let draft, draft.tidied != saved.tidied {
                    HStack {
                        Text("The engine reloads when you apply.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Revert") { self.draft = nil }
                        Button("Apply") { apply(draft) }
                            .disabled(applying || draft.mixedPort == 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.bar)
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func apply(_ options: EngineOptions) {
        applying = true
        Task {
            if await model.applyEngineOptions(options.tidied) { draft = nil }
            applying = false
        }
    }
}

/// One entry per line; blank lines and stray spaces go when the options are applied.
private struct LinesEditor: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    @Binding var lines: [String]

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, lines: Binding<[String]>) {
        self.title = title
        self.detail = detail
        _lines = lines
    }

    var body: some View {
        TextBlock(title: title, detail: detail, text: Binding(
            get: { lines.joined(separator: "\n") },
            set: { lines = $0.components(separatedBy: "\n") }
        ))
    }
}

/// `key = value` lines; the text is kept as typed so a half-written line does not vanish.
private struct PairsEditor: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @Binding var pairs: [String: String]
    @State private var text = ""

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey, pairs: Binding<[String: String]>) {
        self.title = title
        self.detail = detail
        _pairs = pairs
    }

    var body: some View {
        TextBlock(title: title, detail: detail, text: $text)
            .onAppear { text = Self.render(pairs) }
            .onChange(of: text) { text in
                let parsed = Self.parse(text)
                if parsed != pairs { pairs = parsed }
            }
            .onChange(of: pairs) { pairs in
                if Self.parse(text) != pairs { text = Self.render(pairs) }
            }
    }

    private static func render(_ pairs: [String: String]) -> String {
        pairs.sorted { $0.key < $1.key }.map { "\($0.key) = \($0.value)" }.joined(separator: "\n")
    }

    private static func parse(_ text: String) -> [String: String] {
        var pairs: [String: String] = [:]
        for line in text.components(separatedBy: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty { pairs[parts[0]] = parts[1] }
        }
        return pairs
    }
}

private struct TextBlock: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 56, maxHeight: 160)
                .padding(4)
                .background(Color.tileBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.cardEdge))
        }
        .padding(.vertical, 2)
    }
}

private extension EngineOptions {
    var tidied: EngineOptions {
        var next = self
        next.authentication = next.authentication.tidied
        next.tunRouteAddress = next.tunRouteAddress.tidied
        next.tunDnsHijack = next.tunDnsHijack.tidied
        next.addedRules = next.addedRules.tidied
        next.dns.fakeIpFilter = next.dns.fakeIpFilter.tidied
        next.dns.defaultNameserver = next.dns.defaultNameserver.tidied
        next.dns.nameserver = next.dns.nameserver.tidied
        next.dns.fallback = next.dns.fallback.tidied
        next.dns.proxyServerNameserver = next.dns.proxyServerNameserver.tidied
        next.dns.fallbackFilter.geosite = next.dns.fallbackFilter.geosite.tidied
        next.dns.fallbackFilter.ipcidr = next.dns.fallbackFilter.ipcidr.tidied
        next.dns.fallbackFilter.domain = next.dns.fallbackFilter.domain.tidied
        return next
    }
}

private extension Binding where Value == UInt16 {
    /// A port of 0 is off, which reads better as an empty field than as a literal 0.
    var offWhenZero: Binding<UInt16?> {
        Binding<UInt16?>(get: { wrappedValue == 0 ? nil : wrappedValue }, set: { wrappedValue = $0 ?? 0 })
    }
}

private extension Array where Element == String {
    var tidied: [String] {
        map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
