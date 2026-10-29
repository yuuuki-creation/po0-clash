import CryptoKit
import Foundation
import Network
import os
import Po0FFI
import ServiceManagement

let logger = Logger(subsystem: AppPaths.bundleID, category: "app")

enum AppPaths {
    static let bundleID = "io.github.yuuukicreation.po0clash"

    /// The Flutter app was not sandboxed, so its files sit directly in this folder; the native core stays in `core`.
    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(bundleID, isDirectory: true)
    static let data = support.appendingPathComponent("core", isDirectory: true)

    static var bundledMihomo: String? {
        Bundle.main.url(forAuxiliaryExecutable: "mihomo")?.path
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static func coreOptions() throws -> CoreOptions {
        let files = FileManager.default
        try files.createDirectory(at: data, withIntermediateDirectories: true)
        let firstRun = !files.fileExists(atPath: data.appendingPathComponent("settings.json").path)
        let database = support.appendingPathComponent("database.sqlite").path
        return CoreOptions(
            dataDir: data.path,
            platform: .macOs,
            mihomoPath: bundledMihomo,
            legacyPrefs: firstRun ? legacyPreferences() : nil,
            legacyDatabase: firstRun && files.fileExists(atPath: database) ? database : nil,
            appVersion: version
        )
    }

    /// On macOS Flutter's shared_preferences lives in this bundle id's user defaults as `flutter.*` keys, not in a
    /// file; dump them in the shared_preferences.json shape the core reads on the other platforms.
    private static func legacyPreferences() -> String? {
        let file = support.appendingPathComponent("shared_preferences.json")
        if FileManager.default.fileExists(atPath: file.path) { return file.path }
        guard let domain = UserDefaults.standard.persistentDomain(forName: bundleID) else { return nil }
        let values = domain.filter { $0.key.hasPrefix("flutter.") && JSONSerialization.isValidJSONObject([$0.value]) }
        guard !values.isEmpty, let json = try? JSONSerialization.data(withJSONObject: values) else { return nil }
        let dump = data.appendingPathComponent("legacy_shared_preferences.json")
        guard (try? json.write(to: dump, options: .atomic)) != nil else { return nil }
        return dump.path
    }
}

/// TUN needs mihomo running as root. Without a Network Extension (ADR 0018) that is a setuid-root copy of the bundled
/// binary in a root-owned folder, installed with one administrator prompt and reinstalled whenever the bundle changes.
enum TunEngine {
    static let installedPath = "/Library/Application Support/\(AppPaths.bundleID)/mihomo"

    static func isInstalled(matching bundled: String) -> Bool {
        var info = stat()
        guard stat(installedPath, &info) == 0, info.st_uid == 0, info.st_mode & 0o4000 != 0 else { return false }
        guard let installed = digest(installedPath), let source = digest(bundled) else { return false }
        return installed == source
    }

    /// Returns the path to hand the core, or nil when the user cancelled or authorization failed.
    static func ensureInstalled(from bundled: String) -> String? {
        if isInstalled(matching: bundled) { return installedPath }
        do {
            try install(from: bundled)
        } catch {
            logger.error("TUN engine install failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        return isInstalled(matching: bundled) ? installedPath : nil
    }

    private static func digest(_ path: String) -> SHA256.Digest? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) else { return nil }
        return SHA256.hash(data: data)
    }

    private static func install(from bundled: String) throws {
        let folder = (installedPath as NSString).deletingLastPathComponent
        let staged = installedPath + ".new"
        let shell = [
            "mkdir -p \(shellQuote(folder))",
            "cp -fX \(shellQuote(bundled)) \(shellQuote(staged))",
            "chown root:wheel \(shellQuote(staged))",
            "chmod 4755 \(shellQuote(staged))",
            "mv -f \(shellQuote(staged)) \(shellQuote(installedPath))",
        ].joined(separator: " && ")
        let prompt = String(localized: "po0-clash needs administrator permission to install its TUN engine.")
        let script = "do shell script \"\(appleScriptQuote(shell))\" with prompt \"\(appleScriptQuote(prompt))\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw CocoaError(.userCancelled, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

/// Reports physical connectivity changes. Virtual interfaces (mihomo's own utun) are ignored so starting TUN does
/// not look like a network change.
final class NetworkWatcher {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "io.github.yuuukicreation.po0clash.network")
    private var last: String?
    private var pending: DispatchWorkItem?

    func start(_ onChange: @escaping () -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let signature = Self.signature(of: path)
            defer { self.last = signature }
            guard let last = self.last, last != signature else { return }
            self.pending?.cancel()
            let work = DispatchWorkItem(block: onChange)
            self.pending = work
            self.queue.asyncAfter(deadline: .now() + 1, execute: work)
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    private static func signature(of path: NWPath) -> String {
        let interfaces = path.availableInterfaces.filter { $0.type != .other }.map(\.name)
        let gateways = path.gateways.map { "\($0)" }
        return "\(path.status) \(interfaces) \(gateways) \(path.supportsIPv4) \(path.supportsIPv6)"
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
