import AppKit
import Foundation
import Network
import os
import Po0FFI
import Po0System
import ServiceManagement

let logger = Logger(subsystem: AppPaths.bundleID, category: "app")

enum AppPaths {
    static let bundleID = AppIdentity.bundleID

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

    /// Valid only while the launch's open-application event is being handled; `-launchedAtLogin YES` stands in for CI.
    static var launchedAtLogin: Bool {
        if UserDefaults.standard.bool(forKey: "launchedAtLogin") { return true }
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == AEEventID(kAEOpenApplication)
        else { return false }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }
}
