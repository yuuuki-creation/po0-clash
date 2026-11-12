import AppKit
import Foundation
import Po0FFI
import Po0System

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var status: Status?
    @Published private(set) var traffic: Traffic?
    @Published private(set) var exitIp: ExitIp?
    @Published private(set) var appSettings: AppSettings? {
        didSet {
            Theme.apply(appSettings)
            Hotkeys.shared.register(appSettings?.hotkeys ?? [])
            updateTrafficTimer()
        }
    }
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var groups: [ProxyGroup] = []
    @Published private(set) var whitelist: WhitelistState?
    @Published private(set) var testingGroups: Set<String> = []
    @Published private(set) var busy = false
    @Published private(set) var launchError: String?
    @Published var notice: String? {
        didSet {
            if let notice { MainWindow.shared.emit("shell-error", notice) }
        }
    }
    @Published private var proxyPort: UInt16?
    var showsMenuBarSpeed: Bool { appSettings?.traySpeed ?? true }

    var proxyCommand: String? {
        guard let port = proxyPort, port != 0 else { return nil }
        let proxy = "http://127.0.0.1:\(port)"
        return "export https_proxy=\(proxy) http_proxy=\(proxy) all_proxy=\(proxy)"
    }

    private var client: CoreClient?
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []
    private var launchNotice: LaunchCheck?
    private let network = NetworkWatcher()
    private var trafficTimer: Timer?
    private var exitIpTask: Task<Void, Never>?
    private var exitIpFetchedAt: Date?
    private var menuVisible = false
    private var busyCount = 0
    private var settingsSaveTask: Task<Void, Never>?
    private var pendingSettings: AppSettings?
    private var settingsRevision: UInt64 = 0
    private var measuredDelays: [String: UInt32] = [:]
    private var acceptsLinks = false
    private var pendingLinks: [URL] = []

    private static let tunDenied = String(
        localized: "TUN was not authorized, so po0-clash keeps using the system proxy."
    )

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
                let launchCheck = try await client.launchStarted()
                if launchCheck.recovery != .normal {
                    logger.notice("previous launch did not finish: \(String(describing: launchCheck.recovery), privacy: .public)")
                    launchNotice = launchCheck
                }
                await refreshAll()
                releaseWaiters()
                adoptLegacySettings()
                AppLanguage.store(appSettings?.language)
                if appSettings?.disclaimerAccepted == false, !Showcase.isScripted, !confirmDisclaimer() {
                    NSApp.terminate(nil)
                    return
                }
                if !atLogin, !Showcase.keepsWindowClosed, appSettings?.silentLaunch != true { MainWindow.shared.show() }
                acceptsLinks = true
                let links = pendingLinks
                pendingLinks = []
                openLinks(links)
                await adoptInstalledTunEngine()
                network.start {
                    Task { try? await client.networkChanged() }
                }
                let resume = atLogin ? (try? await client.wasConnected()) == true : false
                if launchCheck.recovery == .normal, resume || appSettings?.autoConnect == true {
                    await connect()?.value
                }
                try? await client.launchFinished()
            } catch {
                launchError = describe(error)
                releaseWaiters()
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

    /// The page can load before the core has opened; its commands wait here instead of failing.
    func coreClient() async throws -> CoreClient {
        if client == nil, launchError == nil {
            await withCheckedContinuation { readyWaiters.append($0) }
        }
        guard let client else { throw MessageError(launchError ?? "the core is not available") }
        return client
    }

    private func releaseWaiters() {
        let waiters = readyWaiters
        readyWaiters = []
        for waiter in waiters { waiter.resume() }
    }

    func takeLaunchNotice() -> LaunchCheck? {
        defer { launchNotice = nil }
        return launchNotice
    }

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

    @discardableResult
    private func connect() -> Task<Void, Never>? {
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
            if try await !self.applyRoute(mode, client) { self.notice = Self.tunDenied }
        }
    }

    func selectProfile(_ id: String) {
        command { try await $0.selectProfile(id) }
    }

    func start() async throws {
        try await engineCommand { client in
            try await self.prepareRoute(client)
            try await client.start()
        }
    }

    func changeRoute(_ mode: RouteMode) async throws {
        try await engineCommand { client in
            if try await !self.applyRoute(mode, client) { throw MessageError(Self.tunDenied) }
        }
    }

    /// False when TUN was asked for and the administrator prompt was declined; the route is then left as it was.
    private func applyRoute(_ mode: RouteMode, _ client: CoreClient) async throws -> Bool {
        if mode == .tun {
            guard let engine = await installTunEngine() else { return false }
            try await client.setMihomoPath(engine)
        } else if let bundled = AppPaths.bundledMihomo {
            try await client.setMihomoPath(bundled)
        }
        try await client.setRouteMode(mode)
        return true
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
        notice = Self.tunDenied
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

    /// A clash://install-config link that opens the app waits until the core is ready and the disclaimer is accepted.
    func openLinks(_ links: [URL]) {
        guard acceptsLinks else {
            pendingLinks += links
            return
        }
        for link in links {
            guard link.host == "install-config",
                  let address = URLComponents(url: link, resolvingAgainstBaseURL: false)?
                      .queryItems?.first(where: { $0.name == "url" })?.value
            else { continue }
            MainWindow.shared.show(page: "profiles")
            let alert = NSAlert()
            alert.messageText = String(localized: "Add Subscription")
            alert.informativeText = String(localized: "Add the subscription at \(address)?")
            alert.addButton(withTitle: String(localized: "Add"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            activateApp()
            guard alert.runModal() == .alertFirstButtonReturn else { continue }
            attempt { _ = try await $0.addSubscription(address) }
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
        guard let client, !testingGroups.contains(group) else { return }
        let profile = status?.profileId
        testingGroups.insert(group)
        Task {
            defer { testingGroups.remove(group) }
            do {
                let tested = try await client.testDelay(group)
                guard profile == status?.profileId else { return }
                for node in tested.nodes {
                    if let delay = node.delay { measuredDelays[node.name] = delay }
                }
                groups = groups.map { current in
                    withMeasuredDelays(current.name == group ? tested : current)
                }
            } catch {
                notice = describe(error)
            }
        }
    }

    private func confirmDisclaimer() -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Disclaimer")
        alert.informativeText = String(
            localized: "This software is intended only for non-commercial uses such as learning and research. Using it for any commercial purpose is strictly prohibited; any commercial activity is unrelated to this software."
        )
        alert.addButton(withTitle: String(localized: "Agree"))
        alert.addButton(withTitle: String(localized: "Quit"))
        activateApp()
        let agreed = alert.runModal() == .alertFirstButtonReturn
        if agreed { updateAppSettings { $0.disclaimerAccepted = true } }
        return agreed
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
        guard client != nil, var next = appSettings else { return }
        change(&next)
        appSettings = next
        settingsRevision += 1
        pendingSettings = next
        guard settingsSaveTask == nil else { return }
        settingsSaveTask = Task { await saveAppSettings() }
    }

    private func saveAppSettings() async {
        defer { settingsSaveTask = nil }
        guard let client else { return }
        while let next = pendingSettings {
            pendingSettings = nil
            let revision = settingsRevision
            do {
                try await client.setAppSettings(next)
            } catch {
                notice = describe(error)
            }
            if pendingSettings == nil, let actual = try? await client.appSettings(), revision == settingsRevision {
                appSettings = actual
            }
        }
    }

    /// macOS reads an app's language at launch, so one saved by the page reaches the menu on the next start.
    func storeAppSettings(_ settings: AppSettings) async throws {
        let client = try await coreClient()
        await settingsSaveTask?.value
        try await client.setAppSettings(settings)
        settingsRevision += 1
        if settings.language != appSettings?.language { AppLanguage.store(settings.language) }
        appSettings = (try? await client.appSettings()) ?? settings
    }

    private func refreshAppSettings() async {
        guard settingsSaveTask == nil else { return }
        let revision = settingsRevision
        guard let client, let next = try? await client.appSettings() else { return }
        let port = try? await client.mixedProxyPort()
        guard revision == settingsRevision else { return }
        appSettings = next
        proxyPort = port
    }

    // MARK: Whitelist

    func setWhitelistEnabled(_ enabled: Bool) {
        attempt { try await $0.setWhitelistEnabled(enabled) }
    }

    // MARK: Visibility

    func setMenuVisible(_ visible: Bool) {
        guard menuVisible != visible else { return }
        menuVisible = visible
        if visible {
            logger.notice("menu panel shown")
            Task { await refreshGroups() }
            if exitIpFetchedAt.map({ Date().timeIntervalSince($0) > 60 }) ?? true { refreshExitIp() }
        }
        updateTrafficTimer()
    }

    // MARK: Refresh

    private func handle(_ change: Change) {
        MainWindow.shared.emit("core-change", String(describing: change))
        switch change {
        case .status: Task { await refreshStatus() }
        case .profiles: Task { await refreshProfiles() }
        case .groups: Task { await refreshGroups() }
        case .whitelist: Task { await refreshWhitelist() }
        }
    }

    func refreshAll() async {
        await refreshAppSettings()
        await refreshStatus()
        await refreshProfiles()
        await refreshWhitelist()
        await refreshGroups()
    }

    private func refreshStatus() async {
        guard let client, let next = try? await client.status() else { return }
        if status?.profileId != next.profileId { measuredDelays.removeAll() }
        let changed = status.map { old in
            Self.engineKey(old.engine) != Self.engineKey(next.engine) || old.mode != next.mode
                || old.currentNode != next.currentNode || old.profileId != next.profileId
        } ?? true
        status = next
        proxyPort = try? await client.mixedProxyPort()
        if changed {
            refreshExitIp()
            await refreshGroups()
        }
        if !isRunning { traffic = nil }
        updateTrafficTimer()
    }

    private func withMeasuredDelays(_ source: ProxyGroup) -> ProxyGroup {
        var group = source
        group.nodes = group.nodes.map { source in
            var node = source
            node.delay = measuredDelays[node.name] ?? node.delay
            return node
        }
        return group
    }

    private func refreshWhitelist() async {
        guard let client, let next = try? await client.whitelist() else { return }
        whitelist = next
    }

    private func refreshProfiles() async {
        guard let client, let next = try? await client.profiles() else { return }
        profiles = next
    }

    private func refreshGroups() async {
        guard let client else { return }
        groups = ((try? await client.groups()) ?? []).map(withMeasuredDelays)
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
        let wanted = isRunning && (showsMenuBarSpeed || menuVisible)
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
        let next = try? await client.traffic()
        if traffic != next { traffic = next }
    }

    private static func engineKey(_ state: EngineState) -> Int {
        switch state {
        case .stopped: return 0
        case .starting: return 1
        case .running: return 2
        case .failed: return 3
        }
    }

    /// The core wipes its data at the next start, so the app restarts straight away.
    func clearData() async throws {
        let client = try await coreClient()
        try await client.clearData()
        try? LaunchAtLogin.set(false)
        if let domain = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: domain) }
        AppLanguage.relaunch()
    }

    // MARK: Helpers

    /// Engine and route changes: the connect controls stay disabled until the status has been re-read.
    @discardableResult
    private func command(_ body: @escaping @MainActor (CoreClient) async throws -> Void) -> Task<Void, Never>? {
        guard let client else { return nil }
        busyCount += 1
        busy = true
        return Task {
            do { try await body(client) } catch { notice = describe(error) }
            await refreshStatus()
            busyCount -= 1
            busy = busyCount > 0
        }
    }

    /// `command` for the page: the menu's controls are held the same way, and the error is thrown instead of shown.
    func engineCommand(_ body: @MainActor (CoreClient) async throws -> Void) async throws {
        let client = try await coreClient()
        busyCount += 1
        busy = true
        var failure: Error?
        do { try await body(client) } catch { failure = error }
        await refreshStatus()
        busyCount -= 1
        busy = busyCount > 0
        if let failure { throw failure }
    }

    private func attempt(_ body: @escaping @MainActor (CoreClient) async throws -> Void) {
        guard let client else { return }
        Task {
            do { try await body(client) } catch { notice = describe(error) }
        }
    }
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
