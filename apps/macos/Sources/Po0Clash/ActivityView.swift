import AppKit
import Po0FFI
import SwiftUI

extension Connection: Identifiable {}

enum ActivityTab: String, CaseIterable {
    case requests, connections, logs

    var title: LocalizedStringKey {
        switch self {
        case .requests: return "Requests"
        case .connections: return "Connections"
        case .logs: return "Logs"
        }
    }
}

@MainActor
final class ActivityModel: ObservableObject {
    @Published private(set) var requests: [Connection] = []
    @Published private(set) var connections = Connections(uploadTotal: 0, downloadTotal: 0, items: [])
    @Published private(set) var logs: [LogEntry] = []

    func refresh(_ tab: ActivityTab, core: CoreClient?) async {
        if let sample = Showcase.sample {
            requests = sample.connections.items
            connections = sample.connections
            logs = sample.logs
            return
        }
        guard let core else { return }
        switch tab {
        case .requests: requests = (try? await core.requests()) ?? []
        case .connections:
            if let next = try? await core.connections() { connections = next }
        case .logs: logs = (try? await core.logs()) ?? []
        }
    }
}

/// FlClash's requests, connections and logs pages as one page with a segmented switch, newest first.
struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var activity = ActivityModel()
    @AppStorage("activityTab") private var storedTab = ActivityTab.requests
    @State private var search = ""
    @State private var minimumLevel = LogLevel.debug

    private var tabs: [ActivityTab] {
        model.appSettings?.captureLogs == true ? ActivityTab.allCases : [.requests, .connections]
    }

    private var tab: ActivityTab { tabs.contains(storedTab) ? storedTab : .requests }

    var body: some View {
        PageScaffold("Activity", capped: false) {
            actions
        } content: {
            VStack(alignment: .leading, spacing: Ui.block) {
                HStack(spacing: 12) {
                    SegmentedControl(
                        selection: Binding(get: { tab }, set: { storedTab = $0 }),
                        segments: tabs.map { Segment($0, $0.title) }
                    )
                    Spacer(minLength: 8)
                    SearchField(text: $search)
                }
                content
            }
            .pagePadding()
        }
        .task(id: tab) {
            while !Task.isCancelled {
                await activity.refresh(tab, core: model.core)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch tab {
        case .requests:
            Button("Clear") {
                run { try await $0.clearRequests() }
            }
            .disabled(activity.requests.isEmpty)
        case .connections:
            Button("Close all") {
                run { try await $0.closeAllConnections() }
            }
            .disabled(activity.connections.items.isEmpty)
        case .logs:
            MenuButton(placement: .belowTrailing) {
                HStack(spacing: 8) {
                    Text("Level")
                    DownChevron()
                }
            } entries: {
                levelEntries
            }
            Button("Clear") {
                run { try await $0.clearLogs() }
            }
            .disabled(activity.logs.isEmpty)
        }
    }

    private var levelEntries: [MenuEntry] {
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        return levels.map { level in
            MenuEntry.action(level.name, checked: level == minimumLevel, perform: { minimumLevel = level })
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .requests:
            if activity.requests.isEmpty {
                EmptyState(title: "No requests", symbol: "arrow.left.arrow.right")
            } else {
                ConnectionTable(rows: activity.requests.reversed().filter(matches), close: nil)
            }
        case .connections:
            if activity.connections.items.isEmpty {
                EmptyState(title: "No connections", symbol: "point.3.connected.trianglepath.dotted")
            } else {
                ConnectionTable(
                    rows: activity.connections.items.sorted { $0.start > $1.start }.filter(matches),
                    close: { id in run { try await $0.closeConnection(id) } }
                )
            }
        case .logs:
            if activity.logs.isEmpty {
                EmptyState(title: "No logs", symbol: "doc.plaintext")
            } else {
                LogTable(entries: activity.logs.reversed().filter { entry in
                    entry.level.rank >= minimumLevel.rank
                        && (query.isEmpty || entry.message.localizedCaseInsensitiveContains(query))
                })
            }
        }
    }

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    private func matches(_ row: Connection) -> Bool {
        guard !query.isEmpty else { return true }
        let fields = [row.host, row.destination, row.process ?? "", row.rule, row.rulePayload] + row.chains
        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    @MainActor
    private func run(_ body: @escaping (CoreClient) async throws -> Void) {
        guard let core = model.core else { return }
        Task {
            do { try await body(core) } catch { model.notice = describe(error) }
            await activity.refresh(tab, core: core)
        }
    }
}

private struct ConnectionTable: View {
    @Environment(\.compactContent) private var compact
    let rows: [Connection]
    let close: ((String) -> Void)?
    @State private var selection = Set<String>()
    @State private var anchor: String?

    private var columns: [ColumnWidth] {
        compact
            ? [.flex(1.6), .flex(1.6), .fixed(84)]
            : [.fixed(72), .flex(2), .flex(1.1), .flex(1.1), .flex(1.8), .fixed(84)]
    }

    var body: some View {
        ScrollingTable {
            ColumnsLayout(columns: columns) {
                if !compact { Text("Time") }
                Text("Host")
                if !compact {
                    Text("Process")
                    Text("Rule")
                }
                Text("Chain")
                Text("Traffic").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .tableHeader()
        } rows: {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                ColumnsLayout(columns: columns) {
                    if !compact {
                        Text(Format.date(row.start), format: .dateTime.hour().minute().second())
                            .foregroundStyle(Color.ink2)
                            .lineLimit(1)
                    }
                    Text(verbatim: row.host).lineLimit(1).truncationMode(.middle)
                    if !compact {
                        process(row)
                        Text(verbatim: row.rulePayload.isEmpty ? row.rule : "\(row.rule) · \(row.rulePayload)")
                            .foregroundStyle(Color.ink2)
                            .lineLimit(1)
                    }
                    Text(verbatim: row.chains.reversed().joined(separator: " › "))
                        .foregroundStyle(Color.ink2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(verbatim: Format.bytes(row.upload + row.download))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .allowsHitTesting(false)
                .tableRow(zebra: index % 2 == 0, hit: { click(row.id) })
                .overlay(Color.listSelection.opacity(selection.contains(row.id) ? 1 : 0).allowsHitTesting(false))
                .help(details(row))
                .contextMenu {
                    Button("Copy Host") { copyHosts(from: row.id) }
                    if let close {
                        Button("Close Connection") { targets(of: row.id).forEach(close) }
                    }
                }
            }
        }
    }

    private func process(_ row: Connection) -> some View {
        HStack(spacing: 6) {
            if let icon = ProcessIcon.image(row.processPath) {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            Text(verbatim: row.process ?? "—")
                .foregroundStyle(row.process == nil ? Color.ink2 : Color.ink)
                .lineLimit(1)
        }
    }

    /// The cells pass their clicks to the row, so the row carries what a narrow column cuts off.
    private func details(_ row: Connection) -> String {
        [row.host, row.processPath, "↑ \(Format.bytes(row.upload))  ↓ \(Format.bytes(row.download))"]
            .compactMap { $0 }
            .joined(separator: "
")
    }

    /// ⌘ adds a row and ⇧ extends from the last one clicked, as a table on macOS does.
    private func click(_ id: String) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
            anchor = id
        } else if flags.contains(.shift), let anchor,
                  let from = rows.firstIndex(where: { $0.id == anchor }),
                  let to = rows.firstIndex(where: { $0.id == id }) {
            selection = Set(rows[min(from, to)...max(from, to)].map(\.id))
        } else {
            selection = [id]
            anchor = id
        }
    }

    private func targets(of id: String) -> [String] {
        selection.contains(id) ? Array(selection) : [id]
    }

    private func copyHosts(from id: String) {
        let ids = targets(of: id)
        let hosts = rows.filter { ids.contains($0.id) }.map(\.host)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hosts.joined(separator: "\n"), forType: .string)
    }
}

private struct LogTable: View {
    let entries: [LogEntry]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(Format.date(entry.at), format: .dateTime.hour().minute().second())
                            .foregroundStyle(Color.ink2)
                            .lineLimit(1)
                            .frame(width: 72, alignment: .leading)
                        Text(entry.level.label)
                            .foregroundStyle(entry.level.tint)
                            .lineLimit(1)
                            .frame(width: 60, alignment: .leading)
                        Text(verbatim: entry.message)
                            .font(Ui.codeFont)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                    .tableRow(zebra: index % 2 == 1)
                }
            }
        }
        .cardSurface()
    }
}

extension LogLevel {
    var label: LocalizedStringKey {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .silent: return "Silent"
        }
    }

    /// For AppKit menus, which cannot take a `LocalizedStringKey`.
    var name: String {
        switch self {
        case .debug: return String(localized: "Debug")
        case .info: return String(localized: "Info")
        case .warning: return String(localized: "Warning")
        case .error: return String(localized: "Error")
        case .silent: return String(localized: "Silent")
        }
    }

    var tint: Color {
        switch self {
        case .debug, .silent: return .ink2
        case .info: return .accentColor
        case .warning: return .warn
        case .error: return .bad
        }
    }

    var rank: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .silent: return 4
        }
    }
}

/// The outermost app bundle around the executable gives the icon, so a browser's helper processes show the browser.
enum ProcessIcon {
    private static var cache: [String: NSImage] = [:]

    static func image(_ path: String?) -> NSImage? {
        guard let path, !path.isEmpty else { return nil }
        if let icon = cache[path] { return icon }
        let components = (path as NSString).pathComponents
        let bundle = components.firstIndex { $0.hasSuffix(".app") }
            .map { NSString.path(withComponents: Array(components[...$0])) }
        let icon = NSWorkspace.shared.icon(forFile: bundle ?? path)
        cache[path] = icon
        return icon
    }
}
