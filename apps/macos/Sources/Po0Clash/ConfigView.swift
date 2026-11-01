import Po0FFI
import SwiftUI

/// FlClash's basic configuration: general, inbound, virtual network card, hosts and DNS.
struct BasicConfigView: View {
    var body: some View {
        EngineOptionsForm { $options in
            SettingsSection("General") {
                OptionRow("Log level", selection: $options.logLevel, options: [
                    Option(LogLevel.debug, String(localized: "Debug")),
                    Option(LogLevel.info, String(localized: "Info")),
                    Option(LogLevel.warning, String(localized: "Warning")),
                    Option(LogLevel.error, String(localized: "Error")),
                    Option(LogLevel.silent, String(localized: "Silent")),
                ])
                FieldRow("UA") { TextField("UA", text: $options.userAgent, prompt: Text("Default")) }
                FieldRow("Test URL") { TextField("Test URL", text: $options.testUrl) }
                FieldRow("TCP keep-alive interval (seconds)") {
                    TextField("TCP keep-alive interval (seconds)", value: $options.keepAliveInterval, format: .number)
                }
                OptionRow("Find process", selection: $options.findProcessMode, options: [
                    Option(FindProcessMode.off, String(localized: "Off")),
                    Option(FindProcessMode.strict, String(localized: "Strict")),
                    Option(FindProcessMode.always, String(localized: "Always")),
                ])
                ToggleRow("Unified delay", isOn: $options.unifiedDelay)
                ToggleRow("TCP concurrent", isOn: $options.tcpConcurrent)
                ToggleRow("External controller", isOn: $options.externalController)
            }
            SettingsSection("Inbound") {
                FieldRow("Mixed port") {
                    TextField("Mixed port", value: $options.mixedPort, format: .number.grouping(.never))
                }
                FieldRow("SOCKS port") {
                    TextField(
                        "SOCKS port",
                        value: $options.socksPort.offWhenZero,
                        format: .number.grouping(.never),
                        prompt: Text("Off")
                    )
                }
                FieldRow("HTTP port") {
                    TextField(
                        "HTTP port",
                        value: $options.httpPort.offWhenZero,
                        format: .number.grouping(.never),
                        prompt: Text("Off")
                    )
                }
                ToggleRow("Allow LAN", isOn: $options.allowLan)
                ToggleRow(verbatim: "IPv6", isOn: $options.ipv6)
                LinesEditor("Authentication", lines: $options.authentication)
            }
            SettingsSection("System proxy") {
                LinesEditor("Bypass domain", lines: $options.bypassDomains)
            }
            SettingsSection("Virtual network card") {
                OptionRow("Stack mode", selection: $options.tunStack, options: [
                    Option<TunStack?>(nil, String(localized: "Default")),
                    Option<TunStack?>(.system, "System"),
                    Option<TunStack?>(.gvisor, "gVisor"),
                    Option<TunStack?>(.mixed, "Mixed"),
                ])
                FieldRow("Interface name") {
                    TextField("Interface name", text: $options.interfaceName, prompt: Text("Automatic"))
                }
                LinesEditor("Route addresses", lines: $options.tunRouteAddress)
                LinesEditor("DNS hijacking", lines: $options.tunDnsHijack)
                ToggleRow("Auto-set system DNS", isOn: $options.autoSetSystemDns)
            }
            SettingsSection {
                PairsEditor("Hosts", pairs: $options.hosts)
            }
            SettingsSection("DNS") {
                ToggleRow("Override DNS", isOn: $options.overrideDns)
                ToggleRow("Append system DNS", isOn: $options.appendSystemDns)
                if options.overrideDns {
                    ToggleRow("Enable", isOn: $options.dns.enable)
                    FieldRow("Listen") { TextField("Listen", text: $options.dns.listen, prompt: Text("Off")) }
                    OptionRow("DNS mode", selection: $options.dns.enhancedMode, options: [
                        Option(DnsMode.normal, String(localized: "Normal")),
                        Option(DnsMode.fakeIp, "Fake-IP"),
                        Option(DnsMode.redirHost, "Redir-host"),
                    ])
                    FieldRow("Fake-IP range") { TextField("Fake-IP range", text: $options.dns.fakeIpRange) }
                    ToggleRow(verbatim: "IPv6", isOn: $options.dns.ipv6)
                    ToggleRow("Prefer HTTP/3 for DoH", isOn: $options.dns.preferH3)
                    ToggleRow("Use hosts", isOn: $options.dns.useHosts)
                    ToggleRow("Use system hosts", isOn: $options.dns.useSystemHosts)
                    ToggleRow("Respect rules", isOn: $options.dns.respectRules)
                }
            }
            if options.overrideDns {
                SettingsSection("Nameserver") {
                    LinesEditor("Default nameserver", lines: $options.dns.defaultNameserver)
                    LinesEditor("Nameserver", lines: $options.dns.nameserver)
                    LinesEditor("Fallback", lines: $options.dns.fallback)
                    LinesEditor("Proxy nameserver", lines: $options.dns.proxyServerNameserver)
                    PairsEditor("Nameserver policy", pairs: $options.dns.nameserverPolicy)
                    LinesEditor("Fake-IP filter", lines: $options.dns.fakeIpFilter)
                }
                SettingsSection("Fallback filter") {
                    ToggleRow(verbatim: "GeoIP", isOn: $options.dns.fallbackFilter.geoip)
                    FieldRow("GeoIP code") { TextField("GeoIP code", text: $options.dns.fallbackFilter.geoipCode) }
                    LinesEditor("GeoSite", lines: $options.dns.fallbackFilter.geosite)
                    LinesEditor("IP/CIDR", lines: $options.dns.fallbackFilter.ipcidr)
                    LinesEditor("Domain", lines: $options.dns.fallbackFilter.domain)
                }
            }
        }
    }
}

/// FlClash's advanced configuration: rules added in front of every standard profile's own, and the script library.
struct AdvancedConfigView: View {
    @EnvironmentObject private var model: AppModel
    @State private var scripts: [Script] = []
    @State private var editing: ScriptSheet?
    @State private var pendingRemoval: Script?

    var body: some View {
        EngineOptionsForm { $options in
            SettingsSection {
                LinesEditor("Added rules", lines: $options.addedRules)
            }
            ScriptsSection(scripts: scripts, edit: { editing = $0 }, remove: { pendingRemoval = $0 })
        }
        .dialog(item: $editing) { sheet in
            ScriptEditorDialog(script: sheet.script) { _ in Task { scripts = await model.scripts() } }
        }
        .dialog(item: $pendingRemoval, closesOnScrimClick: true) { script in
            ConfirmDialog(
                title: String(localized: "Delete \(script.name)?"),
                message: "Profiles that use it go back to their own config.",
                confirm: "Delete"
            ) {
                Task {
                    if let error = await model.removeScript(script.id) { model.notice = error }
                    scripts = await model.scripts()
                }
            }
        }
        .task { scripts = await model.scripts() }
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
            SettingsSection("Geo resources") {
                ForEach(files, id: \.name) { file in
                    ValueRow(Text(verbatim: file.name)) {
                        Text(verbatim: describe(file))
                    }
                }
                Row {
                    Text("Update now").frame(maxWidth: .infinity, alignment: .leading)
                    updateButton(id: "geo") { await model.updateGeo() }
                }
                ToggleRow("Geo low-memory mode", isOn: Binding(
                    get: { options.geodataLoader == .memconservative },
                    set: { options.geodataLoader = $0 ? .memconservative : .standard }
                ))
                ToggleRow("Auto update", isOn: $options.geoAutoUpdate)
                if options.geoAutoUpdate {
                    FieldRow("Auto-update interval (hours)") {
                        TextField("Auto-update interval (hours)", value: $options.geoUpdateInterval, format: .number)
                    }
                }
            }
            SettingsSection("Download addresses") {
                FieldRow(verbatim: "GeoIP") { TextField(text: $options.geoxUrl.geoip) { Text(verbatim: "GeoIP") } }
                FieldRow(verbatim: "GeoSite") { TextField(text: $options.geoxUrl.geosite) { Text(verbatim: "GeoSite") } }
                FieldRow(verbatim: "MMDB") { TextField(text: $options.geoxUrl.mmdb) { Text(verbatim: "MMDB") } }
                FieldRow(verbatim: "ASN") { TextField(text: $options.geoxUrl.asn) { Text(verbatim: "ASN") } }
            }
            switch providers {
            case .failure:
                SettingsSection("External resources") {
                    Row { Text("Connect to see the profile's external resources.").foregroundStyle(Color.ink2) }
                }
            case .success(let items) where items.isEmpty:
                SettingsSection("External resources") {
                    Row { Text("The profile has no external resources.").foregroundStyle(Color.ink2) }
                }
            case .success(let items):
                providerSection("Proxy providers", items.filter { $0.kind == .proxy })
                providerSection("Rule providers", items.filter { $0.kind == .rule })
            }
        }
        .task(id: model.isRunning) { await reload() }
    }

    @ViewBuilder
    private func providerSection(_ title: LocalizedStringKey, _ items: [Provider]) -> some View {
        if !items.isEmpty {
            SettingsSection(title) {
                ForEach(items, id: \.name) { provider in
                    Row {
                        Text(verbatim: provider.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: summary(provider)).foregroundStyle(Color.ink2).lineLimit(1)
                        updateButton(id: "\(provider.kind)/\(provider.name)") { await model.updateProvider(provider) }
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
            PageScroll {
                content(Binding(get: { draft ?? saved }, set: { draft = $0 }))
            }
            .safeAreaInset(edge: .bottom) {
                if let draft, draft.tidied != saved.tidied {
                    HStack(spacing: 8) {
                        Spacer()
                        Button("Revert") { self.draft = nil }
                        Button("Apply") { apply(draft) }
                            .buttonStyle(ActionButtonStyle(primary: true))
                            .disabled(applying || draft.mixedPort == 0)
                    }
                    .padding(.horizontal, Ui.pageInset)
                    .padding(.vertical, 10)
                    .background(Color.page)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.line).frame(height: 1)
                    }
                }
            }
        } else {
            Ring().frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @Binding var lines: [String]

    init(_ title: LocalizedStringKey, lines: Binding<[String]>) {
        self.title = title
        _lines = lines
    }

    var body: some View {
        TextBlock(title: title, text: Binding(
            get: { lines.joined(separator: "\n") },
            set: { lines = $0.components(separatedBy: "\n") }
        ))
    }
}

/// `key = value` lines; the text is kept as typed so a half-written line does not vanish.
private struct PairsEditor: View {
    let title: LocalizedStringKey
    @Binding var pairs: [String: String]
    @State private var text = ""

    init(_ title: LocalizedStringKey, pairs: Binding<[String: String]>) {
        self.title = title
        _pairs = pairs
    }

    var body: some View {
        TextBlock(title: title, text: $text)
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
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            TextEditor(text: $text)
                .font(Ui.codeFont)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 56, maxHeight: 160)
                .padding(4)
                .editorChrome()
        }
        .padding(.horizontal, Ui.padding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hairlineAbove()
    }
}

private extension EngineOptions {
    var tidied: EngineOptions {
        var next = self
        next.authentication = next.authentication.tidied
        next.tunRouteAddress = next.tunRouteAddress.tidied
        next.tunDnsHijack = next.tunDnsHijack.tidied
        next.addedRules = next.addedRules.tidied
        next.bypassDomains = next.bypassDomains.tidied
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
