import Foundation
import Po0FFI

private let controlQueue = DispatchQueue(label: "io.github.yuuukicreation.po0clash.control", qos: .userInitiated)
private let workQueue = DispatchQueue(label: "io.github.yuuukicreation.po0clash.work", qos: .userInitiated, attributes: .concurrent)

/// Runs blocking work (core calls, file hashing, osascript) without holding the main actor or the cooperative pool.
func background<T>(_ body: @escaping () throws -> T) async throws -> T {
    try await perform(on: workQueue, body)
}

/// Termination waits in a nested run loop that cannot drain the main dispatch queue when it was entered from a
/// main-queue block, so anything that must reach it is scheduled on the run loop instead.
func onMainRunLoop(_ block: @escaping () -> Void) {
    let loop = CFRunLoopGetMain()
    CFRunLoopPerformBlock(loop, CFRunLoopMode.commonModes.rawValue, block)
    CFRunLoopWakeUp(loop)
}

private func perform<T>(on queue: DispatchQueue, _ body: @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        queue.async { continuation.resume(with: Result(catching: body)) }
    }
}

/// The only file that calls `Po0Core`. Engine and route commands share one serial queue so they apply in the order
/// the user gave them; reads and slow network calls run concurrently.
final class CoreClient: @unchecked Sendable {
    private let core: Po0Core

    private init(core: Po0Core) {
        self.core = core
    }

    static func open(_ options: CoreOptions, listener: CoreListener) async throws -> CoreClient {
        try await perform(on: controlQueue) {
            let core = try Po0Core(options: options)
            core.setListener(listener: listener)
            return CoreClient(core: core)
        }
    }

    private func control<T>(_ body: @escaping (Po0Core) throws -> T) async throws -> T {
        try await perform(on: controlQueue) { try body(self.core) }
    }

    private func work<T>(_ body: @escaping (Po0Core) throws -> T) async throws -> T {
        try await perform(on: workQueue) { try body(self.core) }
    }

    func status() async throws -> Status { try await work { $0.status() } }
    func traffic() async throws -> Traffic { try await work { $0.traffic() } }
    func exitIp() async throws -> ExitIp { try await work { try $0.exitIp() } }
    func checkUpdate() async throws -> Release? { try await work { try $0.checkUpdate() } }
    func ipQuality(_ ip: String, refresh: Bool) async throws -> IpQuality {
        try await work { try $0.ipQuality(ip: ip, refresh: refresh) }
    }
    func intranetIp() async throws -> IntranetIp? { try await work { $0.intranetIp() } }
    func wasConnected() async throws -> Bool { try await work { $0.wasConnected() } }
    func appSettings() async throws -> AppSettings { try await work { $0.appSettings() } }
    func setAppSettings(_ settings: AppSettings) async throws {
        try await work { try $0.setAppSettings(settings: settings) }
    }

    func start() async throws { try await control { try $0.start(tunFd: nil) } }
    func stop() async throws { try await control { $0.stop() } }
    func setMode(_ mode: Mode) async throws { try await control { try $0.setMode(mode: mode) } }
    func setRouteMode(_ mode: RouteMode) async throws { try await control { try $0.setRouteMode(routeMode: mode) } }
    func setMihomoPath(_ path: String) async throws { try await control { $0.setMihomoPath(path: path) } }

    func profiles() async throws -> [Profile] { try await work { $0.profiles() } }
    func addSubscription(_ url: String) async throws -> Profile { try await work { try $0.addSubscription(url: url) } }
    func updateProfile(_ id: String) async throws -> Profile { try await work { try $0.updateProfile(id: id) } }
    func removeProfile(_ id: String) async throws { try await control { try $0.removeProfile(id: id) } }
    func selectProfile(_ id: String) async throws { try await control { try $0.selectProfile(id: id) } }
    func importLinks(_ text: String) async throws -> ImportResult { try await work { try $0.importLinks(text: text) } }
    func importFile(name: String, content: String) async throws -> Profile {
        try await control { try $0.importFile(name: name, content: content) }
    }
    func editProfile(_ id: String, _ edit: ProfileEdit) async throws -> Profile {
        try await work { try $0.editProfile(id: id, edit: edit) }
    }
    func profileContent(_ id: String) async throws -> String { try await work { try $0.profileContent(id: id) } }
    func saveProfileContent(_ id: String, _ content: String) async throws -> Profile {
        try await control { try $0.saveProfileContent(id: id, content: content) }
    }
    func previewConfig(_ id: String) async throws -> String { try await work { try $0.previewConfig(id: id) } }
    func profileOverride(_ id: String) async throws -> ProfileOverride { try await work { try $0.profileOverride(id: id) } }
    func setProfileOverride(_ id: String, _ overrides: ProfileOverride) async throws {
        try await control { try $0.setProfileOverride(id: id, overrides: overrides) }
    }
    func profileGroupsAndRules(_ id: String) async throws -> ProfileParts {
        try await work { try $0.profileGroupsAndRules(id: id) }
    }
    func scripts() async throws -> [Script] { try await work { $0.scripts() } }
    func shareNodes(_ id: String) async throws -> [ShareNode] { try await work { try $0.shareNodes(id: id) } }
    func licenses() async throws -> [License] { try await work { $0.licenses() } }
    func renameShareNode(_ id: String, _ name: String, _ newName: String) async throws {
        try await control { try $0.renameShareNode(id: id, name: name, newName: newName) }
    }
    func removeShareNode(_ id: String, _ name: String) async throws {
        try await control { try $0.removeShareNode(id: id, name: name) }
    }
    func saveScript(_ script: Script) async throws -> Script { try await control { try $0.saveScript(script: script) } }
    func removeScript(_ id: String) async throws { try await control { try $0.removeScript(id: id) } }
    func reorderProfiles(_ ids: [String]) async throws { try await work { try $0.reorderProfiles(ids: ids) } }

    func groups() async throws -> [ProxyGroup] { try await work { try $0.groups() } }
    func selectNode(group: String, node: String) async throws {
        try await control { try $0.selectNode(group: group, node: node) }
    }
    func testDelay(_ group: String) async throws -> ProxyGroup { try await work { try $0.testDelay(group: group) } }
    func testNodeDelay(_ node: String) async throws -> UInt32 { try await work { try $0.testNodeDelay(node: node) } }

    func trafficHistory() async throws -> [Traffic] { try await work { $0.trafficHistory() } }
    func memory() async throws -> UInt64 { try await work { $0.memory() } }
    func connections() async throws -> Connections { try await work { $0.connections() } }
    func closeConnection(_ id: String) async throws { try await work { try $0.closeConnection(id: id) } }
    func closeAllConnections() async throws { try await work { try $0.closeAllConnections() } }
    func requests() async throws -> [Connection] { try await work { $0.requests() } }
    func clearRequests() async throws { try await work { $0.clearRequests() } }
    func logs() async throws -> [LogEntry] { try await work { $0.logs() } }
    func clearLogs() async throws { try await work { $0.clearLogs() } }

    func whitelist() async throws -> WhitelistState { try await work { $0.whitelist() } }
    func setWhitelistEnabled(_ enabled: Bool) async throws { try await control { try $0.setWhitelistEnabled(enabled: enabled) } }
    func addWhitelistEntries(_ text: String, name: String) async throws -> [WhitelistEntry] {
        try await work { try $0.addWhitelistEntries(text: text, name: name) }
    }
    func removeWhitelistEntry(_ id: String) async throws { try await control { try $0.removeWhitelistEntry(id: id) } }

    func networkChanged() async throws { try await work { $0.networkChanged() } }
    func exportDiagnostics(to path: String) async throws { try await work { try $0.exportDiagnostics(path: path) } }
    func backup() async throws -> Data { try await work { try $0.backup() } }
    func crashEngine() async throws { try await control { try $0.crashEngine() } }
    func addTestLogs() async throws { try await work { $0.addTestLogs() } }
    func pruneCache() async throws -> UInt32 { try await work { try $0.pruneCache() } }
    func clearData() async throws { try await control { try $0.clearData() } }
    func engineOptions() async throws -> EngineOptions { try await work { $0.engineOptions() } }
    func setEngineOptions(_ options: EngineOptions) async throws {
        try await control { try $0.setEngineOptions(options: options) }
    }
    func geoFiles() async throws -> [GeoFile] { try await work { $0.geoFiles() } }
    func updateGeo() async throws { try await work { try $0.updateGeo() } }
    func providers() async throws -> [Provider] { try await work { try $0.providers() } }
    func updateProvider(_ provider: Provider) async throws {
        try await work { try $0.updateProvider(kind: provider.kind, name: provider.name) }
    }
    func checkWebDav(_ dav: WebDav) async throws { try await work { try $0.checkWebdav(dav: dav) } }
    func backupToWebDav() async throws { try await work { try $0.backupToWebdav() } }
    func restore(_ data: Data, scope: RestoreScope) async throws {
        try await control { try $0.restore(data: data, scope: scope) }
    }
    func restoreFromWebDav(scope: RestoreScope) async throws {
        try await control { try $0.restoreFromWebdav(scope: scope) }
    }

    /// Queued behind pending commands so a stop or route change in flight cannot run after it and leave a proxy set.
    func shutdown(then done: @escaping () -> Void) {
        controlQueue.async {
            self.core.shutdown()
            onMainRunLoop(done)
        }
    }
}

final class ChangeForwarder: CoreListener, @unchecked Sendable {
    private let handler: (Change) -> Void

    init(_ handler: @escaping (Change) -> Void) {
        self.handler = handler
    }

    func onChange(change: Change) {
        handler(change)
    }
}
