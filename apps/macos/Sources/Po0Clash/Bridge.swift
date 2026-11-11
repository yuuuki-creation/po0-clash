import AppKit
import Po0FFI
import UniformTypeIdentifiers
import WebKit

/// The page's side of `invoke`: `webkit.messageHandlers.po0.postMessage({cmd, args})` resolves with the result as
/// JSON text or rejects with the error message. Commands, argument names and results are those of the Windows shell
/// (`apps/windows/src-tauri/src/shell/commands.rs`), so one page serves both.
@MainActor
final class Bridge: NSObject, WKScriptMessageHandlerWithReply {
    static let name = "po0"

    private let model = AppModel.shared

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.scheme == WebAssets.scheme,
              let body = message.body as? [String: Any], let command = body["cmd"] as? String,
              let args = try? Fields(body["args"] ?? [String: Any]())
        else {
            replyHandler(nil, "malformed bridge message")
            return
        }
        Task {
            do {
                let result = try await self.run(command, args)
                replyHandler(try Wire.text(result), nil)
            } catch {
                replyHandler(nil, describe(error))
            }
        }
    }

    private func run(_ command: String, _ args: Fields) async throws -> Any {
        if let result = try await shell(command, args) { return result }
        let core = try await model.coreClient()
        switch command {
        case "status":
            return Wire.status(try await core.status())
        case "start":
            try await model.start()
        case "stop":
            try await model.engineCommand { try await $0.stop() }
        case "set_mode":
            let mode = try args.required("mode", Wire.choice(Wire.modes))
            try await model.engineCommand { try await $0.setMode(mode) }
        case "set_route_mode":
            try await model.changeRoute(try args.required("routeMode", Wire.choice(Wire.routeModes)))
        case "traffic":
            return Wire.traffic(try await core.traffic())
        case "traffic_history":
            return try await core.trafficHistory().map(Wire.traffic)
        case "memory":
            return try await core.memory()
        case "connections":
            return Wire.connections(try await core.connections())
        case "close_connection":
            try await core.closeConnection(try args.required("id", Wire.string))
        case "close_all_connections":
            try await core.closeAllConnections()
        case "requests":
            return try await core.requests().map(Wire.connection)
        case "clear_requests":
            try await core.clearRequests()
        case "logs":
            return try await core.logs().map(Wire.logEntry)
        case "clear_logs":
            try await core.clearLogs()
        case "exit_ip":
            return Wire.exitIp(try await core.exitIp())
        case "intranet_ip":
            return Wire.optional(try await core.intranetIp().map(Wire.intranetIp))
        case "check_update":
            return Wire.optional(try await core.checkUpdate().map(Wire.release))

        case "profiles":
            return try await core.profiles().map(Wire.profile)
        case "add_subscription":
            let url = try args.required("url", Wire.string).trimmingCharacters(in: .whitespacesAndNewlines)
            return Wire.profile(try await core.addSubscription(url))
        case "update_profile":
            return Wire.profile(try await core.updateProfile(try args.required("id", Wire.string)))
        case "remove_profile":
            try await core.removeProfile(try args.required("id", Wire.string))
        case "select_profile":
            let id = try args.required("id", Wire.string)
            try await model.engineCommand { try await $0.selectProfile(id) }
        case "import_file":
            let name = try args.required("name", Wire.string)
            let content = try args.required("content", Wire.string)
            return Wire.profile(try await core.importFile(name: name, content: content))
        case "import_links":
            return Wire.importResult(try await core.importLinks(try args.required("text", Wire.string)))
        case "edit_profile":
            let edit = try args.required("edit", Wire.readProfileEdit)
            return Wire.profile(try await core.editProfile(try args.required("id", Wire.string), edit))
        case "preview_config":
            return try await core.previewConfig(try args.required("id", Wire.string))
        case "reorder_profiles":
            try await core.reorderProfiles(try args.required("ids", Wire.strings))
        case "export_profile":
            let content = try await core.profileContent(try args.required("id", Wire.string))
            let panel = NSSavePanel()
            panel.nameFieldStringValue = try args.required("name", Wire.string) + ".yaml"
            guard let url = await choose(panel) else { break }
            try await background { try content.write(to: url, atomically: true, encoding: .utf8) }
            return url.path
        case "profile_override":
            return Wire.profileOverride(try await core.profileOverride(try args.required("id", Wire.string)))
        case "set_profile_override":
            let overrides = try args.required("overrides", Wire.readProfileOverride)
            try await core.setProfileOverride(try args.required("id", Wire.string), overrides)
        case "profile_groups_and_rules":
            return Wire.profileParts(try await core.profileGroupsAndRules(try args.required("id", Wire.string)))
        case "share_nodes":
            return try await core.shareNodes(try args.required("id", Wire.string)).map(Wire.shareNode)
        case "rename_share_node":
            let name = try args.required("name", Wire.string)
            let newName = try args.required("newName", Wire.string)
            try await core.renameShareNode(try args.required("id", Wire.string), name, newName)
        case "remove_share_node":
            let name = try args.required("name", Wire.string)
            try await core.removeShareNode(try args.required("id", Wire.string), name)
        case "scripts":
            return try await core.scripts().map(Wire.script)
        case "save_script":
            return Wire.script(try await core.saveScript(try args.required("script", Wire.readScript)))
        case "remove_script":
            try await core.removeScript(try args.required("id", Wire.string))

        case "groups":
            return try await core.groups().map(Wire.group)
        case "select_node":
            let group = try args.required("group", Wire.string)
            try await core.selectNode(group: group, node: try args.required("node", Wire.string))
        case "test_delay":
            return Wire.group(try await core.testDelay(try args.required("group", Wire.string)))
        case "test_node_delay":
            return try await core.testNodeDelay(try args.required("node", Wire.string))
        case "providers":
            return try await core.providers().map(Wire.provider)
        case "update_provider":
            let kind: ProviderKind = try args.required("kind", Wire.string) == "rule" ? .rule : .proxy
            try await core.updateProvider(kind: kind, name: try args.required("name", Wire.string))
        case "rules":
            return try await core.rules().map(Wire.rule)
        case "geo_files":
            return try await core.geoFiles().map(Wire.geoFile)
        case "update_geo":
            try await core.updateGeo()
        case "flush_dns_cache":
            try await core.flushDnsCache()

        case "whitelist":
            return Wire.whitelist(try await core.whitelist())
        case "set_whitelist_enabled":
            try await core.setWhitelistEnabled(try args.required("enabled", Wire.bool))
        case "add_whitelist_entries":
            let name = try args.required("name", Wire.string).trimmingCharacters(in: .whitespacesAndNewlines)
            return try await core.addWhitelistEntries(try args.required("text", Wire.string), name: name).count
        case "remove_whitelist_entry":
            try await core.removeWhitelistEntry(try args.required("id", Wire.string))
        case "whitelist_now":
            try await core.whitelistNow()

        case "app_settings":
            return Wire.appSettings(try await core.appSettings())
        case "set_app_settings":
            let base = try await core.appSettings()
            try await model.storeAppSettings(try Wire.readAppSettings(try args.raw("settings"), base: base))
        case "engine_options":
            return Wire.engineOptions(try await core.engineOptions())
        case "set_engine_options":
            let base = try await core.engineOptions()
            try await core.setEngineOptions(try Wire.readEngineOptions(try args.raw("options"), base: base))

        case "backup_to_file":
            let data = try await core.backup()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.zip]
            panel.nameFieldStringValue = "po0-clash-backup.zip"
            guard let url = await choose(panel) else { break }
            try await background { try data.write(to: url, options: .atomic) }
            return url.path
        case "restore_from_file":
            let scope = try restoreScope(args)
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.zip]
            guard let url = await choose(panel) else { return false }
            let data = try await background { try Data(contentsOf: url) }
            try await core.restore(data, scope: scope)
            await model.refreshAll()
            return true
        case "check_webdav":
            try await core.checkWebDav(try args.required("dav", Wire.readWebDav))
        case "backup_to_webdav":
            try await core.backupToWebDav()
        case "restore_from_webdav":
            try await core.restoreFromWebDav(scope: try restoreScope(args))
            await model.refreshAll()
        case "export_diagnostics":
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = "po0-clash-diagnostics.txt"
            guard let url = await choose(panel) else { break }
            try await core.exportDiagnostics(to: url.path)
            return url.path

        case "licenses":
            return try await core.licenses().map(Wire.license)
        case "crash_engine":
            try await core.crashEngine()
        case "add_test_logs":
            try await core.addTestLogs()
        case "prune_cache":
            return try await core.pruneCache()
        case "clear_data":
            try await model.clearData()
        default:
            throw MessageError("unknown command: \(command)")
        }
        return Wire.unit
    }

    /// The commands that answer without the core, so the window still works when the core failed to open.
    private func shell(_ command: String, _ args: Fields) async throws -> Any? {
        switch command {
        case "app_info":
            _ = try? await model.coreClient()
            let info: [String: Any] = ["version": AppPaths.version, "language": language]
            return info
        case "launch_notice":
            _ = try? await model.coreClient()
            guard let check = model.takeLaunchNotice() else { break }
            let notice: [String: Any] = [
                "cleared": check.recovery == .clearProfile,
                "profileName": Wire.optional(check.profileName),
            ]
            return notice
        case "window_drag":
            MainWindow.shared.drag()
        case "window_zoom":
            MainWindow.shared.zoom()
        case "set_window_background":
            let red = try args.required("r", Wire.int)
            let green = try args.required("g", Wire.int)
            MainWindow.shared.setBackground(red: red, green: green, blue: try args.required("b", Wire.int))
        case "open_url":
            let address = try args.required("url", Wire.string)
            guard address.hasPrefix("https://") || address.hasPrefix("http://"), let url = URL(string: address),
                  NSWorkspace.shared.open(url)
            else { throw MessageError("not a web link: \(address)") }
        case "write_clipboard":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(try args.required("text", Wire.string), forType: .string)
        case "autostart_enabled":
            return LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval
        case "set_autostart":
            try LaunchAtLogin.set(try args.required("enabled", Wire.bool))
            if LaunchAtLogin.needsApproval { LaunchAtLogin.openSystemSettings() }
        case "hotkey_failures":
            return Hotkeys.shared.failed.map(Wire.name).sorted()
        case "pause_hotkeys":
            Hotkeys.shared.paused = try args.required("paused", Wire.bool)
        default:
            return nil
        }
        return Wire.unit
    }

    /// `zh`, `ja`, `ru` or `en`: the language chosen in the settings, or the system's when none is.
    private var language: String {
        let tag = (model.appSettings?.language ?? Locale.preferredLanguages.first ?? "").lowercased()
        return ["zh", "ja", "ru"].first { tag.hasPrefix($0) } ?? "en"
    }

    private func restoreScope(_ args: Fields) throws -> RestoreScope {
        try args.required("scopeName", Wire.string) == "profiles" ? .profiles : .all
    }

    /// A sheet rather than `runModal`, whose nested run loop would hold up the main actor this runs on.
    private func choose(_ panel: NSSavePanel) async -> URL? {
        activateApp()
        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            if let window = MainWindow.shared.window, window.isVisible {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        return response == .OK ? panel.url : nil
    }
}
