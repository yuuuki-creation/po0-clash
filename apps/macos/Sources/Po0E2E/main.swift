import Foundation
import Po0FFI
import Po0System

// Real-flow check run by scripts/e2e.sh against a local shadowsocks node and subscription: system proxy, then TUN
// through the setuid engine the app would install, then the system proxy again. Exits non-zero on the first failure.

struct Failure: Error, CustomStringConvertible {
    let description: String
}

func check(_ condition: Bool, _ message: @autoclosure () -> String) throws {
    if !condition { throw Failure(description: message()) }
}

func step(_ name: String) {
    print("== \(name)")
}

@discardableResult
func shell(_ path: String, _ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let text = String(decoding: data, as: UTF8.self)
    try check(process.terminationStatus == 0, "\(path) \(arguments.joined(separator: " ")) failed: \(text)")
    return text
}

func systemProxy() -> String? {
    guard let output = try? shell("/usr/sbin/scutil", ["--proxy"]) else { return nil }
    var values: [String: String] = [:]
    for line in output.split(separator: "\n") {
        let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2 { values[parts[0]] = parts[1] }
    }
    guard values["HTTPEnable"] == "1", let host = values["HTTPProxy"], let port = values["HTTPPort"] else { return nil }
    return "\(host):\(port)"
}

struct NodeLog {
    let path: String
    let needle = "1.1.1.1:80"

    private func hits() -> Int {
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        return text.components(separatedBy: needle).count - 1
    }

    func expectHit(_ curlArguments: [String]) throws {
        let before = hits()
        try shell("/usr/bin/curl", ["--silent", "--show-error", "--fail", "--max-time", "15"] + curlArguments
            + ["http://1.1.1.1/cdn-cgi/trace"])
        let deadline = Date().addingTimeInterval(5)
        while hits() == before, Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
        try check(hits() > before, "the request did not go through the shadowsocks node")
    }
}

func connect(_ core: Po0Core) throws {
    try core.start(tunFd: nil)
    let deadline = Date().addingTimeInterval(20)
    while Date() < deadline {
        switch core.status().engine {
        case .running: return
        case .failed(let message): throw Failure(description: "engine failed: \(message)")
        default: Thread.sleep(forTimeInterval: 0.2)
        }
    }
    throw Failure(description: "engine did not reach running within 20 s")
}

func run() throws {
    let env = ProcessInfo.processInfo.environment
    func value(_ key: String) throws -> String {
        guard let value = env[key], !value.isEmpty else { throw Failure(description: "\(key) is not set") }
        return value
    }
    let mihomo = try value("PO0_E2E_MIHOMO")
    let node = NodeLog(path: try value("PO0_E2E_NODE_LOG"))
    let core = try Po0Core(options: CoreOptions(
        dataDir: try value("PO0_E2E_DATA"), platform: .macOs, mihomoPath: mihomo,
        legacyPrefs: nil, legacyDatabase: nil, appVersion: "e2e"
    ))

    step("subscription and share link")
    let profile = try core.addSubscription(url: try value("PO0_E2E_SUBSCRIPTION"))
    try check(profile.name == "po0 demo", "unexpected profile name \(profile.name)")
    try check(profile.usage?.total == 100 << 30 && profile.usage?.expire != nil, "usage headers were not read")
    try check(try core.importLinks(text: try value("PO0_E2E_LINK")).added == 1, "the share link was not imported")
    try core.selectProfile(id: profile.id)

    step("system proxy")
    try core.setRouteMode(routeMode: .systemProxy)
    try connect(core)
    guard let proxy = systemProxy() else { throw Failure(description: "the system proxy is not set while connected") }
    try node.expectHit(["--proxy", "http://\(proxy)"])
    try check(!(try core.exitIp().ip.isEmpty), "no exit IP")
    core.stop()
    try check(systemProxy() == nil, "stop left the system proxy set")

    step("tun with the setuid engine")
    try shell("/usr/bin/sudo", ["-n", "/bin/sh", "-c", TunEngine.installCommand(from: mihomo)])
    try check(TunEngine.isInstalled(matching: mihomo), "the setuid engine is not installed")
    core.setMihomoPath(path: TunEngine.installedPath)
    try core.setRouteMode(routeMode: .tun)
    try connect(core)
    try check(systemProxy() == nil, "TUN and the system proxy are on together")
    try node.expectHit(["--noproxy", "*"])
    core.stop()

    step("system proxy again")
    core.setMihomoPath(path: mihomo)
    try core.setRouteMode(routeMode: .systemProxy)
    try connect(core)
    guard let again = systemProxy() else { throw Failure(description: "the system proxy is not set after TUN") }
    try node.expectHit(["--proxy", "http://\(again)"])

    step("delays and whitelist results")
    for group in try core.groups() where group.selectable {
        let tested = try core.testDelay(group: group.name)
        try check(tested.nodes.contains { ($0.delay ?? 0) > 0 }, "no node in \(group.name) answered the delay test")
    }
    // One round of real requests so the screenshots show results; the demo secrets are invalid and get rejected.
    let entries = try core.addWhitelistEntries(
        text: "pgnfw_demo0000000000000000\nhttps://guguyun.com/whitelist?token=demo0000000000", name: "Demo"
    )
    try check(entries.map(\.kind) == [.po0, .ggy], "whitelist entries were not parsed")
    try core.setWhitelistEnabled(enabled: true)
    let deadline = Date().addingTimeInterval(25)
    while Date() < deadline, core.whitelist().entries.contains(where: { $0.result == nil }) {
        Thread.sleep(forTimeInterval: 0.5)
    }
    try core.setWhitelistEnabled(enabled: false)
    core.shutdown()
}

do {
    try run()
    print("== passed")
} catch {
    print("FAILED: \(error)")
    exit(1)
}
