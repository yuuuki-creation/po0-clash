import CryptoKit
import Foundation
import os

public enum AppIdentity {
    public static let bundleID = "io.github.yuuukicreation.po0clash"
}

private let logger = Logger(subsystem: AppIdentity.bundleID, category: "tun")

/// TUN needs mihomo running as root. Without a Network Extension (ADR 0018) that is a setuid-root copy of the bundled
/// binary in a root-owned folder, installed with one administrator prompt and reinstalled whenever the bundle changes.
public enum TunEngine {
    public static let installedPath = "/Library/Application Support/\(AppIdentity.bundleID)/mihomo"

    public static func isInstalled(matching bundled: String) -> Bool {
        var info = stat()
        guard stat(installedPath, &info) == 0, info.st_uid == 0, info.st_mode & 0o4000 != 0 else { return false }
        guard let installed = digest(installedPath), let source = digest(bundled) else { return false }
        return installed == source
    }

    /// Returns the path to hand the core, or nil when the user cancelled or authorization failed.
    public static func ensureInstalled(from bundled: String) -> String? {
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

    /// The root shell command that installs the copy; CI runs the same command with sudo.
    public static func installCommand(from bundled: String) -> String {
        let folder = (installedPath as NSString).deletingLastPathComponent
        let staged = installedPath + ".new"
        return [
            "mkdir -p \(shellQuote(folder))",
            "cp -fX \(shellQuote(bundled)) \(shellQuote(staged))",
            "chown root:wheel \(shellQuote(staged))",
            "chmod 4755 \(shellQuote(staged))",
            "mv -f \(shellQuote(staged)) \(shellQuote(installedPath))",
        ].joined(separator: " && ")
    }

    private static func install(from bundled: String) throws {
        let shell = installCommand(from: bundled)
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
