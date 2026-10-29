import Foundation
import Po0FFI
import XCTest

@testable import Po0Clash

/// Drives the real core against a local shadowsocks node and subscription that `scripts/e2e.sh` serves.
final class RealFlowTests: XCTestCase {
    private let target = "http://1.1.1.1/cdn-cgi/trace"

    func testSystemProxyThenTunThenSystemProxyAgain() throws {
        let env = ProcessInfo.processInfo.environment
        guard let mihomo = env["PO0_E2E_MIHOMO"], let subscription = env["PO0_E2E_SUBSCRIPTION"],
              let link = env["PO0_E2E_LINK"], let nodeLog = env["PO0_E2E_NODE_LOG"], let data = env["PO0_E2E_DATA"]
        else { throw XCTSkip("run through scripts/e2e.sh") }
        let node = NodeLog(path: nodeLog, needle: "1.1.1.1:80")

        let core = try Po0Core(options: CoreOptions(
            dataDir: data, platform: .macOs, mihomoPath: mihomo,
            legacyPrefs: nil, legacyDatabase: nil, appVersion: "e2e"
        ))
        let profile = try core.addSubscription(url: subscription)
        XCTAssertEqual(profile.name, "po0 demo")
        XCTAssertEqual(profile.usage?.total, 100 << 30)
        XCTAssertNotNil(profile.usage?.expire)
        XCTAssertEqual(try core.importLinks(text: link).added, 1)
        try core.selectProfile(id: profile.id)

        try core.setRouteMode(routeMode: .systemProxy)
        try connect(core)
        let proxy = try XCTUnwrap(systemProxy(), "the system proxy is not set while connected")
        try node.expectHit { try curl(["--proxy", "http://\(proxy)", target]) }
        XCTAssertFalse(try core.exitIp().ip.isEmpty)
        core.stop()
        XCTAssertNil(systemProxy(), "stop left the system proxy set")

        try shell("/usr/bin/sudo", ["-n", "/bin/sh", "-c", TunEngine.installCommand(from: mihomo)])
        XCTAssertTrue(TunEngine.isInstalled(matching: mihomo))
        core.setMihomoPath(path: TunEngine.installedPath)
        try core.setRouteMode(routeMode: .tun)
        try connect(core)
        XCTAssertNil(systemProxy(), "TUN and the system proxy must not be on together")
        try node.expectHit { try curl(["--noproxy", "*", target]) }
        core.stop()

        core.setMihomoPath(path: mihomo)
        try core.setRouteMode(routeMode: .systemProxy)
        try connect(core)
        let again = try XCTUnwrap(systemProxy())
        try node.expectHit { try curl(["--proxy", "http://\(again)", target]) }

        for group in try core.groups() where group.selectable {
            let tested = try core.testDelay(group: group.name)
            XCTAssertTrue(tested.nodes.contains { ($0.delay ?? 0) > 0 }, "no node in \(group.name) answered the delay test")
        }
        try seedWhitelist(core)
        core.shutdown()
    }

    private func connect(_ core: Po0Core) throws {
        try core.start(tunFd: nil)
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            switch core.status().engine {
            case .running: return
            case .failed(let message): return XCTFail("engine failed: \(message)")
            default: Thread.sleep(forTimeInterval: 0.2)
            }
        }
        XCTFail("engine did not reach running within 20 s")
    }

    /// One round of real requests so the screenshots show results; the invalid demo secrets are rejected.
    private func seedWhitelist(_ core: Po0Core) throws {
        let entries = try core.addWhitelistEntries(
            text: "pgnfw_demo0000000000000000\nhttps://guguyun.com/whitelist?token=demo0000000000",
            name: "Demo"
        )
        XCTAssertEqual(entries.map(\.kind), [.po0, .ggy])
        try core.setWhitelistEnabled(enabled: true)
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline, core.whitelist().entries.contains(where: { $0.result == nil }) {
            Thread.sleep(forTimeInterval: 0.5)
        }
        try core.setWhitelistEnabled(enabled: false)
    }

    private func systemProxy() -> String? {
        guard let output = try? shell("/usr/sbin/scutil", ["--proxy"]) else { return nil }
        var values: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { values[parts[0]] = parts[1] }
        }
        guard values["HTTPEnable"] == "1", let host = values["HTTPProxy"], let port = values["HTTPPort"] else { return nil }
        return "\(host):\(port)"
    }

    private func curl(_ arguments: [String]) throws {
        try shell("/usr/bin/curl", ["--silent", "--show-error", "--fail", "--max-time", "15"] + arguments)
    }
}

private struct NodeLog {
    let path: String
    let needle: String

    private func hits() -> Int {
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        return text.components(separatedBy: needle).count - 1
    }

    func expectHit(file: StaticString = #filePath, line: UInt = #line, _ request: () throws -> Void) throws {
        let before = hits()
        try request()
        let deadline = Date().addingTimeInterval(5)
        while hits() == before, Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertGreaterThan(hits(), before, "the request did not go through the shadowsocks node", file: file, line: line)
    }
}

@discardableResult
private func shell(_ path: String, _ arguments: [String]) throws -> String {
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
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "shell", code: Int(process.terminationStatus),
                      userInfo: [NSLocalizedDescriptionKey: "\(path) \(arguments.joined(separator: " ")): \(text)"])
    }
    return text
}
