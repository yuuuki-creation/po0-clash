import AppKit
import Foundation
import Po0FFI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var status: Status?
    @Published private(set) var traffic: Traffic?
    @Published private(set) var exitIp: ExitIp?
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var groups: [ProxyGroup] = []
    @Published private(set) var whitelist: WhitelistState?
    @Published private(set) var testing: Set<String> = []
    @Published private(set) var updating: Set<String> = []
    @Published private(set) var busy = false
    @Published private(set) var launchError: String?
    @Published var notice: String?

    private var client: CoreClient?
    private let network = NetworkWatcher()
    private var trafficTimer: Timer?
    private var exitIpTask: Task<Void, Never>?
    private var exitIpFetchedAt: Date?
    private var menuVisible = false
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
                await adoptInstalledTunEngine()
                network.start { Task { try? await client.networkChanged() } }
                if atLogin, (try? await client.wasConnected()) == true { connect() }
            } catch {
                launchError = describe(error)
                logger.error("core failed to start: \(self.launchError ?? "", privacy: .public)")
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

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    // MARK: Menu visibility

    func menuAppeared() {
        guard !menuVisible else { return }
        menuVisible = true
        updateTrafficTimer()
        Task { await refreshGroups() }
        if exitIpFetchedAt.map({ Date().timeIntervalSince($0) > 60 }) ?? true { refreshExitIp() }
    }

    func menuDisappeared() {
        guard menuVisible else { return }
        menuVisible = false
        updateTrafficTimer()
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
        if changed {
            refreshExitIp()
            await refreshGroups()
        }
        if !isRunning { traffic = nil }
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
        let wanted = menuVisible && isRunning
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
