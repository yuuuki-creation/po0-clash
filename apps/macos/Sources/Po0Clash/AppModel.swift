import AppKit
import Foundation
import Po0FFI
import Po0System
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var status: Status?
    @Published private(set) var traffic: Traffic?
    @Published private(set) var trafficHistory: [Traffic] = []
    @Published private(set) var memory: UInt64 = 0
    @Published private(set) var connectionSummary = ConnectionSummary()
    @Published private(set) var exitIp: ExitIp?
    @Published private(set) var intranetIp: IntranetIp?
    @Published private(set) var appSettings: AppSettings? {
        didSet {
            Theme.apply(appSettings)
            Hotkeys.shared.register(appSettings?.hotkeys ?? [])
            updateTrafficTimer()
        }
    }
    @Published private(set) var engineOptions: EngineOptions?
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var groups: [ProxyGroup] = []
    @Published private(set) var whitelist: WhitelistState?
    @Published private(set) var testing: Set<String> = []
    @Published private(set) var updating: Set<String> = []
    @Published private(set) var busy = false
    @Published private(set) var connectedAt: Date?
    @Published private(set) var launchError: String?
    @Published var notice: String?
    var showsMenuBarSpeed: Bool { appSettings?.traySpeed ?? true }

    private var client: CoreClient?
    private let network = NetworkWatcher()
    private var trafficTimer: Timer?
    private var exitIpTask: Task<Void, Never>?
    private var exitIpFetchedAt: Date?
    private var visibleSurfaces: Set<Surface> = []
    private var busyCount = 0

    var isOn: Bool {
        switch status?.engine {
        case .starting?, .running?: return true
        default: return false
        }
    }

    var isRunning: Bool {
        if case .running? = status?.engine { return true }
        return false
    }

    func launch(atLogin: Bool) {
        Task {
            do {
                let options = try await background { try AppPaths.coreOptions() }
                let forwarder = ChangeForwarder { change in
                    Task { @MainActor in AppModel.shared.handle(change) }
                }
                let client = try await CoreClient.open(options, listener: forwarder)
                self.client = client
                logger.notice("core ready")
                await refreshAll()
                adoptLegacySettings()
                AppLanguage.store(appSettings?.language)
                if appSettings?.disclaimerAccepted == false, !Showcase.isScripted, !confirmDisclaimer() {
                    NSApp.terminate(nil)
                    return
                }
                if !atLogin, !Showcase.keepsWindowClosed, appSettings?.silentLaunch != true { MainWindow.shared.show() }
                await adoptInstalledTunEngine()
                network.start {
                    Task {
                        try? await client.networkChanged()
                        await AppModel.shared.refreshIntranetIp()
                    }
                }
                let resume = atLogin ? (try? await client.wasConnected()) == true : false
                if resume || appSettings?.autoConnect == true { connect() }
                if appSettings?.autoCheckUpdate == true, !Showcase.isScripted { checkForUpdates(userInitiated: false) }
            } catch {
                launchError = describe(error)
                logger.error("core failed to start: \(self.launchError ?? "", privacy: .public)")
                if !Showcase.keepsWindowClosed { MainWindow.shared.show() }
            }
        }
    }

    func shutdown(then done: @escaping () -> Void) {
        logger.notice("shutting down")
        network.stop()
        trafficTimer?.invalidate()
        guard let client else { return done() }
        var finished = false
        let finish = {
            guard !finished else { return }
            finished = true
            logger.notice("shutdown finished")
            done()
        }
        client.shutdown(then: finish)
        DispatchQueue.global().asyncAfter(deadline: .now() + 8) { onMainRunLoop(finish) }
    }

    var hasCore: Bool { client != nil }

    /// For pages that poll the core themselves, such as Activity.
    var core: CoreClient? { client }

    // MARK: Connection

    func setConnected(_ on: Bool) {
        if on {
            connect()
        } else {
            command { try await $0.stop() }
        }
    }

    func reconnect() {
        command { client in
            try await client.stop()
            try await self.prepareRoute(client)
            try await client.start()
        }
    }

    private func connect() {
        command { client in
            try await self.prepareRoute(client)
            try await client.start()
        }
    }

    func setMode(_ mode: Mode) {
        command { try await $0.setMode(mode) }
    }

    func setRouteMode(_ mode: RouteMode) {
        command { client in
            if mode == .tun {
                guard let engine = await self.installTunEngine() else {
                    self.notice = String(localized: "TUN was not authorized, so po0-clash keeps using the system proxy.")
                    return
                }
                try await client.setMihomoPath(engine)
            } else if let bundled = AppPaths.bundledMihomo {
                try await client.setMihomoPath(bundled)
            }
            try await client.setRouteMode(mode)
        }
    }

    /// A saved TUN choice can outlive the root copy (an app update changes the bundled binary), so connecting
    /// re-checks it and falls back to the system proxy when the user declines the prompt.
    private func prepareRoute(_ client: CoreClient) async throws {
        guard (try await client.status()).routeMode == .tun else { return }
        if let engine = await installTunEngine() {
            try await client.setMihomoPath(engine)
            return
        }
        if let bundled = AppPaths.bundledMihomo { try await client.setMihomoPath(bundled) }
        try await client.setRouteMode(.systemProxy)
        notice = String(localized: "TUN was not authorized, so po0-clash keeps using the system proxy.")
    }

    private func installTunEngine() async -> String? {
        guard let bundled = AppPaths.bundledMihomo else { return nil }
        return try? await background { TunEngine.ensureInstalled(from: bundled) }
    }

    private func adoptInstalledTunEngine() async {
        guard let client, status?.routeMode == .tun, let bundled = AppPaths.bundledMihomo else { return }
        let ready = (try? await background { TunEngine.isInstalled(matching: bundled) }) == true
        if ready { try? await client.setMihomoPath(TunEngine.installedPath) }
    }

    // MARK: Profiles

    func selectProfile(_ id: String) {
        command { try await $0.selectProfile(id) }
    }

    func updateProfile(_ id: String) {
        guard let client else { return }
        updating.insert(id)
        Task {
            defer { updating.remove(id) }
            do { _ = try await client.updateProfile(id) } catch { notice = describe(error) }
            await refreshProfiles()
        }
    }

    func removeProfile(_ id: String) {
        attempt { try await $0.removeProfile(id) }
    }

    func updateAllProfiles() {
        for profile in profiles where profile.kind == .subscription && !updating.contains(profile.id) {
            updateProfile(profile.id)
        }
    }

    /// Returns an error message to show in the sheet, or nil on success.
    func editProfile(_ id: String, _ edit: ProfileEdit) async -> String? {
        guard let client else { return launchError }
        do {
            _ = try await client.editProfile(id, edit)
            await refreshProfiles()
            return nil
        } catch {
            return describe(error)
        }
    }

    func moveProfile(_ id: String, by offset: Int) {
        var ids = profiles.map(\.id)
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + offset) else { return }
        ids.swapAt(index, index + offset)
        attempt { [ids] client in
            try await client.reorderProfiles(ids)
            await self.refreshProfiles()
        }
    }

    func importProfileFile() {
        guard let client else { return }
        let panel = NSOpenPanel()
        activateApp()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                _ = try await client.importFile(name: url.lastPathComponent, content: content)
                await refreshProfiles()
            } catch {
                notice = describe(error)
            }
        }
    }

    func exportProfile(_ profile: Profile) {
        guard let client else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = profile.title + (profile.kind == .links ? ".txt" : ".yaml")
        activateApp()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                try await client.profileContent(profile.id).write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                notice = describe(error)
            }
        }
    }

    func profileText(_ id: String, _ text: ProfileText) async -> Result<String, MessageError> {
        guard let client else { return .failure(MessageError(launchError ?? "")) }
        do {
            switch text {
            case .content: return .success(try await client.profileContent(id))
            case .preview: return .success(try await client.previewConfig(id))
            }
        } catch {
            return .failure(MessageError(describe(error)))
        }
    }

    /// Returns an error message to show in the sheet, or nil on success.
    func addSubscription(_ url: String) async -> String? {
        guard let client else { return launchError }
        do {
            _ = try await client.addSubscription(url)
            await refreshProfiles()
            return nil
        } catch {
            return describe(error)
        }
    }

    func importLinks(_ text: String) async -> Result<Int, MessageError> {
        guard let client else { return .failure(MessageError(launchError ?? "")) }
        do {
            let result = try await client.importLinks(text)
            await refreshProfiles()
            return .success(Int(result.added))
        } catch {
            return .failure(MessageError(describe(error)))
        }
    }

    // MARK: Proxies

    func selectNode(group: String, node: String) {
        attempt { client in
            try await client.selectNode(group: group, node: node)
            await self.refreshGroups()
        }
    }

    func testDelay(_ group: String) {
        guard let client, !testing.contains(group) else { return }
        testing.insert(group)
        Task {
            defer { testing.remove(group) }
            do {
                let tested = try await client.testDelay(group)
                if let index = groups.firstIndex(where: { $0.name == group }) { groups[index] = tested }
            } catch {
                notice = describe(error)
            }
        }
    }

    func testNodeDelay(_ node: String) {
        guard let client, !testing.contains(node) else { return }
        testing.insert(node)
        Task {
            defer { testing.remove(node) }
            do {
                let delay = try await client.testNodeDelay(node)
                groups = groups.map { group in
                    var group = group
                    for index in group.nodes.indices where group.nodes[index].name == node {
                        group.nodes[index].delay = delay
                    }
                    return group
                }
            } catch {
                notice = describe(error)
            }
        }
    }

    /// FlClash asks once before the first start and quits when declined; the tools page shows it again.
    func confirmDisclaimer() -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Disclaimer")
        alert.informativeText = String(
            localized: "This software is intended only for non-commercial uses such as learning and research. Using it for any commercial purpose is strictly prohibited; any commercial activity is unrelated to this software."
        )
        alert.addButton(withTitle: String(localized: "Agree"))
        alert.addButton(withTitle: String(localized: "Quit"))
        activateApp()
        let agreed = alert.runModal() == .alertFirstButtonReturn
        if agreed, appSettings?.disclaimerAccepted == false { updateAppSettings { $0.disclaimerAccepted = true } }
        return agreed
    }

    // MARK: Updates

    func checkForUpdates(userInitiated: Bool) {
        guard let client else { return }
        Task {
            do {
                if let release = try await client.checkUpdate() {
                    offer(release, userInitiated: userInitiated)
                } else if userInitiated {
                    notice = String(localized: "po0-clash is up to date.")
                }
            } catch {
                if userInitiated { notice = describe(error) }
            }
        }
    }

    private func offer(_ release: Release, userInitiated: Bool) {
        let alert = NSAlert()
        alert.messageText = String(localized: "po0-clash \(release.version) is available")
        let notes = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.informativeText = notes.count > 800 ? String(notes.prefix(800)) + "…" : notes
        alert.addButton(withTitle: String(localized: "Open Download Page"))
        alert.addButton(withTitle: String(localized: "Later"))
        if !userInitiated { alert.addButton(withTitle: String(localized: "Don't Remind Me")) }
        activateApp()
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = URL(string: release.url) { NSWorkspace.shared.open(url) }
        case .alertThirdButtonReturn:
            updateAppSettings { $0.autoCheckUpdate = false }
        default:
            break
        }
    }

    // MARK: Settings

    /// The menu bar speed switch lived in this app's own defaults before the core kept app settings.
    private func adoptLegacySettings() {
        let defaults = UserDefaults.standard
        guard let traySpeed = defaults.object(forKey: "showsMenuBarSpeed") as? Bool else { return }
        defaults.removeObject(forKey: "showsMenuBarSpeed")
        if !traySpeed { updateAppSettings { $0.traySpeed = false } }
    }

    func updateAppSettings(_ change: (inout AppSettings) -> Void) {
        guard let client, var next = appSettings else { return }
        change(&next)
        appSettings = next
        Task {
            do { try await client.setAppSettings(next) } catch { notice = describe(error) }
            await refreshAppSettings()
        }
    }

    private func refreshAppSettings() async {
        guard let client, let next = try? await client.appSettings() else { return }
        appSettings = next
        engineOptions = try? await client.engineOptions()
    }

    /// Every apply reloads the engine, so pages send the options in one go rather than per keystroke.
    func applyEngineOptions(_ options: EngineOptions) async -> Bool {
        guard let client else { return false }
        do {
            try await client.setEngineOptions(options)
            engineOptions = try? await client.engineOptions()
            return true
        } catch {
            notice = describe(error)
            return false
        }
    }

    func geoFiles() async -> [GeoFile] {
        (try? await client?.geoFiles()) ?? []
    }

    func updateGeo() async {
        do {
            try await client?.updateGeo()
        } catch {
            notice = describe(error)
        }
    }

    func providers() async -> Result<[Provider], MessageError> {
        guard let client else { return .failure(MessageError(launchError ?? "")) }
        do {
            return .success(try await client.providers())
        } catch {
            return .failure(MessageError(describe(error)))
        }
    }

    func updateProvider(_ provider: Provider) async {
        do {
            try await client?.updateProvider(provider)
        } catch {
            notice = describe(error)
        }
    }

    // MARK: Whitelist

    func setWhitelistEnabled(_ enabled: Bool) {
        attempt { try await $0.setWhitelistEnabled(enabled) }
    }

    func addWhitelist(_ text: String, name: String) async -> String? {
        guard let client else { return launchError }
        do {
            _ = try await client.addWhitelistEntries(text, name: name)
            await refreshWhitelist()
            return nil
        } catch {
            return describe(error)
        }
    }

    func removeWhitelistEntry(_ id: String) {
        attempt { try await $0.removeWhitelistEntry(id) }
    }

    // MARK: Diagnostics

    func exportDiagnostics() {
        guard let client else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "po0-clash-diagnostics-\(Self.stamp.string(from: Date())).txt"
        activateApp()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                try await client.exportDiagnostics(to: url.path)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                notice = describe(error)
            }
        }
    }

    // MARK: Backup

    func checkWebDav(_ dav: WebDav) async -> String? {
        guard let client else { return launchError }
        do {
            try await client.checkWebDav(dav)
            return nil
        } catch {
            return describe(error)
        }
    }

    func backupToWebDav() async {
        guard let client else { return }
        do {
            try await client.backupToWebDav()
            notice = String(localized: "Backup successful")
        } catch {
            notice = describe(error)
        }
    }

    func backupToFile() async {
        guard let client else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "po0-clash-backup-\(Self.stamp.string(from: Date())).zip"
        activateApp()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try await client.backup().write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            notice = describe(error)
        }
    }

    func chooseBackupFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        activateApp()
        return panel.runModal() == .OK ? panel.url : nil
    }

    func restore(from source: BackupSource, scope: RestoreScope) async {
        guard let client else { return }
        do {
            switch source {
            case .webDav: try await client.restoreFromWebDav(scope: scope)
            case .file(let url): try await client.restore(Data(contentsOf: url), scope: scope)
            }
            await refreshAll()
            notice = String(localized: "Restore successful")
        } catch {
            notice = describe(error)
        }
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    // MARK: Visibility

    enum Surface {
        case menu, dashboard, proxies
    }

    func setVisible(_ surface: Surface, _ visible: Bool) {
        guard visibleSurfaces.contains(surface) != visible else { return }
        if visible {
            visibleSurfaces.insert(surface)
            if surface == .menu { logger.notice("menu panel shown") }
            Task { await refreshGroups() }
            if surface == .dashboard { Task { await refreshIntranetIp() } }
            if surface != .proxies, exitIpFetchedAt.map({ Date().timeIntervalSince($0) > 60 }) ?? true {
                refreshExitIp()
            }
        } else {
            visibleSurfaces.remove(surface)
        }
        updateTrafficTimer()
    }

    func refreshExitIpNow() {
        refreshExitIp()
        Task { await refreshIntranetIp() }
    }

    // MARK: Refresh

    private func handle(_ change: Change) {
        switch change {
        case .status: Task { await refreshStatus() }
        case .profiles: Task { await refreshProfiles() }
        case .groups: Task { await refreshGroups() }
        case .whitelist: Task { await refreshWhitelist() }
        }
    }

    private func refreshAll() async {
        await refreshAppSettings()
        await refreshStatus()
        await refreshProfiles()
        await refreshWhitelist()
        await refreshGroups()
    }

    private func refreshStatus() async {
        guard let client, let next = try? await client.status() else { return }
        let changed = status.map { old in
            Self.engineKey(old.engine) != Self.engineKey(next.engine) || old.mode != next.mode
                || old.currentNode != next.currentNode || old.profileId != next.profileId
        } ?? true
        status = next
        if !isRunning {
            connectedAt = nil
        } else if connectedAt == nil {
            connectedAt = Date()
        }
        if changed {
            refreshExitIp()
            await refreshGroups()
        }
        if !isRunning {
            traffic = nil
            trafficHistory = []
            memory = 0
            connectionSummary = ConnectionSummary()
        }
        updateTrafficTimer()
    }

    private func refreshProfiles() async {
        guard let client, let next = try? await client.profiles() else { return }
        profiles = next
    }

    private func refreshGroups() async {
        guard let client else { return }
        groups = (try? await client.groups()) ?? []
    }

    private func refreshWhitelist() async {
        guard let client, let next = try? await client.whitelist() else { return }
        whitelist = next
    }

    private func refreshIntranetIp() async {
        guard let client else { return }
        intranetIp = try? await client.intranetIp()
    }

    private func refreshExitIp() {
        guard let client else { return }
        exitIpTask?.cancel()
        exitIpTask = Task {
            let ip = try? await client.exitIp()
            guard !Task.isCancelled else { return }
            exitIp = ip
            exitIpFetchedAt = Date()
        }
    }

    private func updateTrafficTimer() {
        let wanted = isRunning && (showsMenuBarSpeed || !visibleSurfaces.isDisjoint(with: [.menu, .dashboard]))
        if wanted == (trafficTimer != nil) { return }
        trafficTimer?.invalidate()
        trafficTimer = nil
        guard wanted else { return }
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in await AppModel.shared.pollTraffic() }
        }
    }

    private func pollTraffic() async {
        guard let client else { return }
        traffic = try? await client.traffic()
        guard visibleSurfaces.contains(.dashboard) else { return }
        trafficHistory = (try? await client.trafficHistory()) ?? []
        memory = (try? await client.memory()) ?? 0
        if let connections = try? await client.connections() {
            connectionSummary = ConnectionSummary(
                count: connections.items.count,
                upload: connections.uploadTotal,
                download: connections.downloadTotal
            )
        }
    }

    private static func engineKey(_ state: EngineState) -> Int {
        switch state {
        case .stopped: return 0
        case .starting: return 1
        case .running: return 2
        case .failed: return 3
        }
    }

    // MARK: Helpers

    /// Engine and route changes: the connect controls stay disabled until the status has been re-read.
    private func command(_ body: @escaping @MainActor (CoreClient) async throws -> Void) {
        guard let client else { return }
        busyCount += 1
        busy = true
        Task {
            do { try await body(client) } catch { notice = describe(error) }
            await refreshStatus()
            busyCount -= 1
            busy = busyCount > 0
        }
    }

    private func attempt(_ body: @escaping @MainActor (CoreClient) async throws -> Void) {
        guard let client else { return }
        Task {
            do { try await body(client) } catch { notice = describe(error) }
        }
    }
}

struct ConnectionSummary: Equatable {
    var count = 0
    var upload: UInt64 = 0
    var download: UInt64 = 0
}

struct MessageError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

/// Core errors are enums whose single payload is the user-facing message, whatever the case is called.
func describe(_ error: Error) -> String {
    if let message = Mirror(reflecting: error).children.first?.value as? String { return message }
    return error.localizedDescription
}

func activateApp() {
    if #available(macOS 14, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}
