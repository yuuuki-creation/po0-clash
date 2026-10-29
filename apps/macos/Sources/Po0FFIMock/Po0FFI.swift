import Foundation

// Stand-in with the shape of the UniFFI bindings, used only until crates/ffi exists; delete it then.

public enum Platform { case macOs, windows, android }
public enum Mode { case rule, global, direct }
public enum RouteMode { case systemProxy, tun }
public enum EngineState { case stopped, starting, running, failed(message: String) }
public enum ProfileKind { case subscription, links }
public enum WhitelistKind { case po0, ggy }
public enum WhitelistOutcome { case applied, notApplied, disabled, rejected, error }
public enum Change { case status, profiles, groups, whitelist }

public enum CoreError: Error {
    case Invalid(message: String)
    case Network(message: String)
    case Engine(message: String)
    case Io(message: String)
}

public struct CoreOptions {
    public var dataDir: String
    public var platform: Platform
    public var mihomoPath: String?
    public var legacyPrefs: String?
    public var legacyDatabase: String?
    public var appVersion: String

    public init(dataDir: String, platform: Platform, mihomoPath: String?, legacyPrefs: String?, legacyDatabase: String?, appVersion: String) {
        self.dataDir = dataDir
        self.platform = platform
        self.mihomoPath = mihomoPath
        self.legacyPrefs = legacyPrefs
        self.legacyDatabase = legacyDatabase
        self.appVersion = appVersion
    }
}

public struct Status {
    public var engine: EngineState
    public var mode: Mode
    public var routeMode: RouteMode
    public var profileId: String?
    public var currentNode: String?
}

public struct Traffic {
    public var up: UInt64
    public var down: UInt64
}

public struct ExitIp {
    public var ip: String
    public var country: String?
}

public struct Usage {
    public var upload: UInt64
    public var download: UInt64
    public var total: UInt64
    public var expire: Int64?
}

public struct Profile {
    public var id: String
    public var name: String
    public var kind: ProfileKind
    public var url: String?
    public var updatedAt: Int64?
    public var usage: Usage?
    public var selected: Bool
}

public struct ImportResult {
    public var profile: Profile
    public var added: UInt32
}

public struct Node {
    public var name: String
    public var kind: String
    public var delay: UInt32?
}

public struct ProxyGroup {
    public var name: String
    public var kind: String
    public var selectable: Bool
    public var now: String?
    public var nodes: [Node]
}

public struct WhitelistResult {
    public var outcome: WhitelistOutcome
    public var ip: String?
    public var message: String?
    public var at: Int64
}

public struct WhitelistEntry {
    public var id: String
    public var kind: WhitelistKind
    public var name: String
    public var label: String
    public var result: WhitelistResult?
}

public struct WhitelistState {
    public var enabled: Bool
    public var entries: [WhitelistEntry]
}

public protocol CoreListener: AnyObject {
    func onChange(change: Change)
}

public final class Po0Core {
    private let lock = NSLock()
    private var listener: CoreListener?
    private var current = Status(engine: .stopped, mode: .rule, routeMode: .systemProxy, profileId: nil, currentNode: nil)
    private var profileList: [Profile] = []
    private var groupList: [ProxyGroup] = []
    private var whitelistState = WhitelistState(enabled: true, entries: [])

    public init(options: CoreOptions) throws {}

    private func mutate<T>(_ change: Change?, _ body: () throws -> T) rethrows -> T {
        lock.lock()
        let value = try body()
        let listener = self.listener
        lock.unlock()
        if let change { listener?.onChange(change: change) }
        return value
    }

    public func setListener(listener: CoreListener) { mutate(nil) { self.listener = listener } }
    public func setMihomoPath(path: String) {}
    public func status() -> Status { mutate(nil) { current } }

    public func start(tunFd: Int32?) throws {
        mutate(.status) { current.engine = .starting }
        Thread.sleep(forTimeInterval: 0.4)
        mutate(.status) {
            current.engine = .running
            current.currentNode = groupList.first?.now
        }
    }

    public func stop() { mutate(.status) { current.engine = .stopped } }

    public func traffic() -> Traffic {
        mutate(nil) {
            guard case .running = current.engine else { return Traffic(up: 0, down: 0) }
            return Traffic(up: .random(in: 0...40_000), down: .random(in: 0...900_000))
        }
    }

    public func exitIp() throws -> ExitIp { ExitIp(ip: "203.0.113.7", country: "JP") }
    public func setMode(mode: Mode) throws { mutate(.status) { current.mode = mode } }
    public func setRouteMode(routeMode: RouteMode) throws { mutate(.status) { current.routeMode = routeMode } }
    public func profiles() -> [Profile] { mutate(nil) { profileList } }

    public func addSubscription(url: String) throws -> Profile {
        guard URL(string: url)?.scheme?.hasPrefix("http") == true else {
            throw CoreError.Invalid(message: "Not a subscription URL")
        }
        let used = UInt64.random(in: 1...40) << 30
        let expire = Int64(Date().timeIntervalSince1970) + 86_400 * 40
        return mutate(.profiles) {
            let profile = Profile(id: UUID().uuidString, name: URL(string: url)?.host ?? url, kind: .subscription, url: url,
                                  updatedAt: Int64(Date().timeIntervalSince1970),
                                  usage: Usage(upload: used / 10, download: used, total: 100 << 30, expire: expire),
                                  selected: profileList.isEmpty)
            profileList.append(profile)
            if profile.selected { selectLocked(profile.id) }
            return profile
        }
    }

    public func updateProfile(id: String) throws -> Profile {
        Thread.sleep(forTimeInterval: 0.6)
        return try mutate(.profiles) {
            guard let index = profileList.firstIndex(where: { $0.id == id }) else { throw CoreError.Invalid(message: "No such profile") }
            profileList[index].updatedAt = Int64(Date().timeIntervalSince1970)
            return profileList[index]
        }
    }

    public func removeProfile(id: String) throws { mutate(.profiles) { profileList.removeAll { $0.id == id } } }
    public func selectProfile(id: String) throws { mutate(.profiles) { selectLocked(id) } }

    private func selectLocked(_ id: String) {
        for index in profileList.indices { profileList[index].selected = profileList[index].id == id }
        current.profileId = id
        let nodes = ["Tokyo 01", "Tokyo 02", "Singapore", "Los Angeles"].map { Node(name: $0, kind: "vless", delay: nil) }
        groupList = [
            ProxyGroup(name: "Proxy", kind: "Selector", selectable: true, now: nodes[0].name, nodes: nodes),
            ProxyGroup(name: "Auto", kind: "URLTest", selectable: false, now: nodes[1].name, nodes: nodes),
        ]
    }

    public func importLinks(text: String) throws -> ImportResult {
        let links = text.split(whereSeparator: \.isNewline).filter { $0.contains("://") }
        guard !links.isEmpty else { throw CoreError.Invalid(message: "No share links found") }
        return mutate(.profiles) {
            if let index = profileList.firstIndex(where: { $0.kind == .links }) {
                return ImportResult(profile: profileList[index], added: UInt32(links.count))
            }
            let profile = Profile(id: "links", name: "Links", kind: .links, url: nil, updatedAt: nil, usage: nil, selected: profileList.isEmpty)
            profileList.append(profile)
            return ImportResult(profile: profile, added: UInt32(links.count))
        }
    }

    public func groups() throws -> [ProxyGroup] { mutate(nil) { groupList } }

    public func selectNode(group: String, node: String) throws {
        mutate(.groups) {
            if let index = groupList.firstIndex(where: { $0.name == group }) { groupList[index].now = node }
            current.currentNode = node
        }
    }

    public func testDelay(group: String) throws -> ProxyGroup {
        Thread.sleep(forTimeInterval: 0.8)
        return try mutate(.groups) {
            guard let index = groupList.firstIndex(where: { $0.name == group }) else { throw CoreError.Invalid(message: "No such group") }
            for node in groupList[index].nodes.indices { groupList[index].nodes[node].delay = .random(in: 0...400) }
            return groupList[index]
        }
    }

    public func whitelist() -> WhitelistState { mutate(nil) { whitelistState } }
    public func setWhitelistEnabled(enabled: Bool) { mutate(.whitelist) { whitelistState.enabled = enabled } }

    public func addWhitelistEntries(text: String, name: String) throws -> [WhitelistEntry] {
        let secrets = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !secrets.isEmpty else { throw CoreError.Invalid(message: "No po0 token or ggy link found") }
        return mutate(.whitelist) {
            let added = secrets.map { secret in
                WhitelistEntry(id: UUID().uuidString, kind: secret.contains("://") ? .ggy : .po0, name: name,
                               label: String(secret.prefix(6)) + "…",
                               result: WhitelistResult(outcome: .applied, ip: "203.0.113.7", message: nil, at: Int64(Date().timeIntervalSince1970)))
            }
            whitelistState.entries += added
            return added
        }
    }

    public func removeWhitelistEntry(id: String) { mutate(.whitelist) { whitelistState.entries.removeAll { $0.id == id } } }
    public func whitelistNow() {}
    public func networkChanged() {}
    public func setActive(active: Bool) {}

    public func exportDiagnostics(path: String) throws {
        try "po0-clash mock diagnostics\n".write(toFile: path, atomically: true, encoding: .utf8)
    }

    public func shutdown() { stop() }
}
