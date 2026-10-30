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
    @State private var searching = false
    @State private var minimumLevel = LogLevel.debug

    private var tabs: [ActivityTab] {
        model.appSettings?.captureLogs == true ? ActivityTab.allCases : [.requests, .connections]
    }

    private var tab: ActivityTab { tabs.contains(storedTab) ? storedTab : .requests }

    var body: some View {
        PageScaffold("Activity", subtitle: subtitle) {
            Picker("Activity", selection: Binding(get: { tab }, set: { storedTab = $0 })) {
                ForEach(tabs, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { searching.toggle() }
                if !searching { search = "" }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .help("Search")
            .keyboardShortcut("f")
            actions
        } content: {
            VStack(spacing: 0) {
                if searching {
                    SearchField(text: $search, prompt: "Search")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                }
                content
            }
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
            Button {
                run { try await $0.clearRequests() }
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .help("Clear")
            .disabled(activity.requests.isEmpty)
        case .connections:
            Button {
                run { try await $0.closeAllConnections() }
            } label: {
                Label("Close all", systemImage: "xmark.circle")
            }
            .help("Close all")
            .disabled(activity.connections.items.isEmpty)
        case .logs:
            Menu {
                Picker("Level", selection: $minimumLevel) {
                    ForEach([LogLevel.debug, .info, .warning, .error], id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Level", systemImage: "line.3.horizontal.decrease.circle")
            }
            .help("Level")
            Button {
                run { try await $0.clearLogs() }
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .help("Clear")
            .disabled(activity.logs.isEmpty)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .requests:
            if activity.requests.isEmpty {
                empty("No requests", symbol: "arrow.left.arrow.right")
            } else {
                ConnectionTable(rows: activity.requests.reversed().filter(matches), close: nil)
            }
        case .connections:
            if activity.connections.items.isEmpty {
                empty("No connections", symbol: "point.3.connected.trianglepath.dotted")
            } else {
                ConnectionTable(
                    rows: activity.connections.items.sorted { $0.start > $1.start }.filter(matches),
                    close: { id in run { try await $0.closeConnection(id) } }
                )
            }
        case .logs:
            if activity.logs.isEmpty {
                empty("No logs", symbol: "doc.plaintext")
            } else {
                LogList(entries: activity.logs.reversed().filter { entry in
                    entry.level.rank >= minimumLevel.rank
                        && (query.isEmpty || entry.message.localizedCaseInsensitiveContains(query))
                })
            }
        }
    }

    private func empty(_ title: LocalizedStringKey, symbol: String) -> some View {
        EmptyState(
            title: title,
            symbol: symbol,
            detail: model.isRunning
                ? LocalizedStringKey("New entries appear here as they happen.")
                : LocalizedStringKey("Connect to see what the engine is doing.")
        )
    }

    private var subtitle: String {
        switch tab {
        case .requests:
            let count = activity.requests.count
            return count == 1 ? String(localized: "1 request") : String(localized: "\(count) requests")
        case .connections:
            let count = activity.connections.items.count
            let up = Format.bytes(activity.connections.uploadTotal)
            let down = Format.bytes(activity.connections.downloadTotal)
            let total = count == 1 ? String(localized: "1 connection") : String(localized: "\(count) connections")
            return "\(total) · ↑ \(up) ↓ \(down)"
        case .logs:
            let count = activity.logs.count
            return count == 1 ? String(localized: "1 log line") : String(localized: "\(count) log lines")
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
    let rows: [Connection]
    let close: ((String) -> Void)?
    @State private var selection = Set<String>()

    var body: some View {
        Table(rows, selection: $selection) {
            TableColumn("Time") { row in
                Text(Format.date(row.start), format: .dateTime.hour().minute().second()).monospacedDigit()
            }
            .width(min: 86, ideal: 92, max: 110)
            TableColumn("Host") { row in
                Text(row.host).lineLimit(1).truncationMode(.middle).help(row.host)
            }
            .width(min: 140, ideal: 200)
            TableColumn("Process") { row in
                Text(row.process ?? "—").lineLimit(1).foregroundStyle(row.process == nil ? .secondary : .primary)
            }
            .width(min: 60, ideal: 80)
            TableColumn("Rule") { row in
                Text(row.rulePayload.isEmpty ? row.rule : "\(row.rule) · \(row.rulePayload)").lineLimit(1)
            }
            .width(min: 80, ideal: 110)
            TableColumn("Chain") { row in
                Text(row.chains.reversed().joined(separator: " → ")).lineLimit(1).truncationMode(.middle)
            }
            .width(min: 80, ideal: 140)
            TableColumn("Traffic") { row in
                Text(verbatim: "↑ \(Format.bytes(row.upload))  ↓ \(Format.bytes(row.download))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 110, ideal: 130)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            Button("Copy Host") {
                let hosts = rows.filter { ids.contains($0.id) }.map(\.host)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(hosts.joined(separator: "\n"), forType: .string)
            }
            if let close {
                Button("Close Connection") { ids.forEach(close) }
            }
        }
    }
}

private struct LogList: View {
    let entries: [LogEntry]

    var body: some View {
        List(Array(entries.enumerated()), id: \.offset) { _, entry in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Format.date(entry.at), format: .dateTime.hour().minute().second())
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(entry.level.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.level.tint)
                    .frame(width: 52, alignment: .leading)
                Text(entry.message)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
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

    var tint: Color {
        switch self {
        case .debug, .silent: return .secondary
        case .info: return .accentColor
        case .warning: return .orange
        case .error: return .red
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
