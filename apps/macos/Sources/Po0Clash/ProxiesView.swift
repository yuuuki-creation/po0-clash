import Po0FFI
import SwiftUI

extension ProxiesDensity {
    var tileWidth: CGFloat {
        switch self {
        case .loose: return 220
        case .standard: return 170
        case .tight: return 130
        }
    }
}

struct ProxiesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var expanded: Set<String> = []
    @State private var tab: String?
    @State private var query = ""
    @State private var searching = false
    @State private var locateRequest = 0

    var body: some View {
        PageScaffold("Proxies", subtitle: model.status?.currentNode) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { searching.toggle() }
                if !searching { query = "" }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .help("Search")
            .keyboardShortcut("f")
            Button {
                locateRequest += 1
            } label: {
                Label("Locate", systemImage: "scope")
            }
            .help("Locate")
            .disabled(locatedGroup?.now == nil)
            options
            Button {
                for group in model.groups { model.testDelay(group.name) }
            } label: {
                Label("Test all", systemImage: "bolt")
            }
            .help("Test all")
            .disabled(model.groups.isEmpty || !model.testing.isEmpty)
        } content: {
            if model.status?.mode == .direct {
                EmptyState(
                    title: "Direct mode",
                    symbol: "arrow.right",
                    detail: "Traffic goes out directly, so no proxy is used."
                )
            } else if model.groups.isEmpty {
                EmptyState(
                    title: "No proxy groups",
                    symbol: "globe",
                    detail: "Connect with a subscription to load its proxy groups."
                )
            } else {
                ScrollViewReader { proxy in
                    // The search field and tabs ride in the scroll view: macOS 26 draws the old opaque toolbar over
                    // any page whose top edge is not a vertical scroll view.
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                groupCards
                            } header: {
                                VStack(spacing: 0) {
                                    if searching {
                                        SearchField(text: $query, prompt: "Search nodes")
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 6)
                                    }
                                    if arrangement == .tabs { tabBar }
                                }
                                .background(Color.pageBackground)
                            }
                        }
                    }
                    .onChange(of: locateRequest) { _ in locate(proxy) }
                }
            }
        }
        .background(WindowVisibility { model.setVisible(.proxies, $0) })
        .onDisappear { model.setVisible(.proxies, false) }
        .onAppear {
            if expanded.isEmpty, let first = model.primaryGroup { expanded.insert(first.name) }
        }
    }

    private var groupCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(shownGroups, id: \.name) { group in
                GroupCard(
                    group: group,
                    nodes: nodes(of: group),
                    expanded: isExpanded(group),
                    collapsible: arrangement == .list && query.isEmpty,
                    density: density,
                    tileStyle: tileStyle
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { toggle(group.name) }
                }
                .id(group.name)
            }
            if shownGroups.isEmpty {
                Text("No nodes match “\(query)”.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, arrangement == .tabs ? 8 : 6)
        .padding(.bottom, 20)
    }

    private var options: some View {
        Menu {
            Picker("Show groups as", selection: model.setting(\.proxiesLayout, or: .tabs)) {
                Text("Tabs").tag(ProxiesLayout.tabs)
                Text("List").tag(ProxiesLayout.list)
            }
            Picker("Sort by", selection: model.setting(\.proxiesSort, or: .profile)) {
                Text("Profile order").tag(ProxiesSort.profile)
                Text("Delay").tag(ProxiesSort.delay)
                Text("Name").tag(ProxiesSort.name)
            }
            Picker("Spacing", selection: model.setting(\.proxiesDensity, or: .standard)) {
                Text("Loose").tag(ProxiesDensity.loose)
                Text("Standard").tag(ProxiesDensity.standard)
                Text("Tight").tag(ProxiesDensity.tight)
            }
            Picker("Group icons", selection: model.setting(\.groupIconStyle, or: .standard)) {
                Text("Standard").tag(GroupIconStyle.standard)
                Text("Icon only").tag(GroupIconStyle.iconOnly)
                Text("Hidden").tag(GroupIconStyle.hidden)
            }
            Picker("Node tiles", selection: model.setting(\.proxyTileStyle, or: .detailed)) {
                Text("Detailed").tag(ProxyTileStyle.detailed)
                Text("Compact").tag(ProxyTileStyle.compact)
                Text("Name only").tag(ProxyTileStyle.minimal)
            }
        } label: {
            Label("View options", systemImage: "line.3.horizontal.decrease")
        }
        .help("View options")
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.groups, id: \.name) { group in
                    let selected = group.name == currentTab?.name
                    Button {
                        tab = group.name
                    } label: {
                        Text(verbatim: group.name)
                            .font(.system(size: 13, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? Color.accentColor : Color.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(selected ? Color.accentColor.opacity(0.12) : Color.controlFill, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
    }

    private var arrangement: ProxiesLayout { model.appSettings?.proxiesLayout ?? .tabs }
    private var sort: ProxiesSort { model.appSettings?.proxiesSort ?? .profile }
    private var density: ProxiesDensity { model.appSettings?.proxiesDensity ?? .standard }
    private var tileStyle: ProxyTileStyle { model.appSettings?.proxyTileStyle ?? .detailed }

    private var currentTab: ProxyGroup? {
        model.groups.first { $0.name == tab } ?? model.primaryGroup
    }

    private var locatedGroup: ProxyGroup? {
        arrangement == .tabs ? currentTab : model.primaryGroup
    }

    private var shownGroups: [ProxyGroup] {
        let groups = arrangement == .tabs ? currentTab.map { [$0] } ?? [] : model.groups
        return trimmedQuery.isEmpty ? groups : groups.filter { !nodes(of: $0).isEmpty }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private func isExpanded(_ group: ProxyGroup) -> Bool {
        arrangement == .tabs || !trimmedQuery.isEmpty || expanded.contains(group.name)
    }

    private func toggle(_ name: String) {
        if expanded.contains(name) { expanded.remove(name) } else { expanded.insert(name) }
    }

    private func nodes(of group: ProxyGroup) -> [Node] {
        let matching = trimmedQuery.isEmpty
            ? group.nodes : group.nodes.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
        switch sort {
        case .profile:
            return matching
        case .name:
            return matching.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .delay:
            return matching.enumerated()
                .sorted { (Self.rank($0.element), $0.offset) < (Self.rank($1.element), $1.offset) }
                .map { $0.element }
        }
    }

    /// Tested nodes fastest first, then untested ones, timeouts last.
    private static func rank(_ node: Node) -> UInt64 {
        switch node.delay {
        case 0?: return .max
        case let delay?: return UInt64(delay)
        case nil: return .max - 1
        }
    }

    private func locate(_ proxy: ScrollViewProxy) {
        guard let group = locatedGroup, let now = group.now else { return }
        query = ""
        if arrangement == .list { expanded.insert(group.name) }
        withAnimation { proxy.scrollTo(group.name, anchor: .top) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation { proxy.scrollTo(NodeAnchor(group: group.name, node: now), anchor: .center) }
        }
    }
}

private struct NodeAnchor: Hashable {
    let group: String
    let node: String
}

private struct GroupCard: View {
    @EnvironmentObject private var model: AppModel
    let group: ProxyGroup
    let nodes: [Node]
    let expanded: Bool
    let collapsible: Bool
    let density: ProxiesDensity
    let tileStyle: ProxyTileStyle
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if expanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: density.tileWidth), spacing: 8)], spacing: 8) {
                    ForEach(nodes, id: \.name) { node in
                        NodeTile(node: node, selected: node.name == group.now, style: tileStyle) {
                            if group.selectable { model.selectNode(group: group.name, node: node.name) }
                        }
                        .id(NodeAnchor(group: group.name, node: node.name))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardSurface()
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = group.icon.flatMap(URL.init(string:)), iconStyle != .hidden {
                GroupIcon(url: icon, framed: iconStyle == .standard).padding(.trailing, 2)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(verbatim: group.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(verbatim: group.kind)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(Color.controlFill, in: Capsule())
                }
                Text(verbatim: [group.now, Format.nodeCount(group.nodes.count)].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            CircleButton(symbol: "bolt", help: "Test delay", size: 28, busy: model.testing.contains(group.name)) {
                model.testDelay(group.name)
            }
            if collapsible {
                CircleButton(symbol: "chevron.down", help: expanded ? "Hide nodes" : "Show nodes", size: 28, action: toggle)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if collapsible { toggle() } }
    }

    private var iconStyle: GroupIconStyle { model.appSettings?.groupIconStyle ?? .standard }
}

/// The `icon` a profile gives a proxy group, in a tile or on its own as FlClash's icon styles draw it.
private struct GroupIcon: View {
    let url: URL
    let framed: Bool

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: framed ? 22 : 34, height: framed ? 22 : 34)
                    .padding(framed ? 6 : 0)
                    .background(
                        framed ? Color.controlFill : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
            }
        }
    }
}

private struct NodeTile: View {
    let node: Node
    let selected: Bool
    let style: ProxyTileStyle
    let select: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        content
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, style == .detailed ? 9 : 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.08) : Color.tileBackground, in: shape)
            .overlay(shape.strokeBorder(selected ? Color.accentColor : Color.cardEdge, lineWidth: selected ? 1.5 : 0.5))
            .contentShape(shape)
            .onTapGesture(perform: select)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .detailed:
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    name
                    Spacer(minLength: 0)
                    check
                }
                HStack(spacing: 6) {
                    Text(verbatim: node.kind).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    DelayButton(node: node)
                }
            }
        case .compact:
            HStack(spacing: 6) {
                name
                Spacer(minLength: 0)
                DelayButton(node: node)
                check
            }
        case .minimal:
            HStack(spacing: 6) {
                StatusDot(color: Format.delayTint(node.delay))
                name
                Spacer(minLength: 0)
                check
            }
        }
    }

    private var name: some View {
        Text(verbatim: node.name).lineLimit(1).truncationMode(.middle)
    }

    @ViewBuilder
    private var check: some View {
        if selected {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.accentColor)
        }
    }
}

/// FlClash tests a single node when its delay is clicked.
private struct DelayButton: View {
    @EnvironmentObject private var model: AppModel
    let node: Node

    var body: some View {
        Button {
            model.testNodeDelay(node.name)
        } label: {
            Group {
                if model.testing.contains(node.name) {
                    ProgressView().controlSize(.mini)
                } else if let delay = Format.delay(node) {
                    Text(verbatim: delay).foregroundStyle(Format.delayTint(node.delay))
                } else {
                    Image(systemName: "bolt").foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .frame(minWidth: 16, minHeight: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Test delay")
    }
}
