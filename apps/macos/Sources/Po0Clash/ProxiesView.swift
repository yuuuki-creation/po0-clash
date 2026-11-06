import Po0FFI
import SwiftUI

extension ProxiesDensity {
    var rowHeight: CGFloat {
        switch self {
        case .loose: return 40
        case .standard: return Ui.tableRow
        case .tight: return 26
        }
    }
}

/// `tabs` is the master-detail view of the design; `list` keeps the expandable groups, drawn as tables.
struct ProxiesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.compactContent) private var compact
    @State private var expanded: Set<String> = []
    @State private var selectedGroup: String?
    @State private var query = ""
    @State private var locateRequest = 0

    var body: some View {
        PageScaffold("Proxies", capped: false) {
            SearchField(text: $query)
            sortMenu
            IconButton(symbol: "scope", help: "Locate", action: locate)
                .disabled(model.primaryGroup?.now == nil)
            optionsMenu
            testButton
        } content: {
            if model.status?.mode == .direct {
                EmptyState(title: "Direct mode", symbol: "arrow.right")
            } else if model.groups.isEmpty {
                EmptyState(title: "No proxy groups", symbol: "globe")
            } else if arrangement == .tabs {
                masterDetail
            } else {
                groupList
            }
        }
        .background(WindowVisibility { model.setVisible(.proxies, $0) })
        .onDisappear { model.setVisible(.proxies, false) }
        .onAppear {
            if expanded.isEmpty, let first = model.primaryGroup { expanded.insert(first.name) }
        }
    }

    // MARK: Toolbar

    private var sortMenu: some View {
        MenuButton(placement: .below) {
            HStack(spacing: 8) {
                Text(verbatim: sortOptions.first { $0.value == sort }?.title ?? "")
                DownChevron()
            }
        } entries: {
            sortOptions.map { option in
                MenuEntry.action(option.title, checked: option.value == sort, perform: {
                    model.updateAppSettings { $0.proxiesSort = option.value }
                })
            }
        }
        .help("Sort by")
    }

    private var sortOptions: [Option<ProxiesSort>] {
        [
            Option(ProxiesSort.profile, String(localized: "Profile order")),
            Option(ProxiesSort.delay, String(localized: "Delay")),
            Option(ProxiesSort.name, String(localized: "Name")),
        ]
    }

    private var optionsMenu: some View {
        MenuButton(placement: .belowTrailing) {
            Image(systemName: "line.3.horizontal.decrease").font(.system(size: 15))
        } entries: {
            optionEntries
        }
        .buttonStyle(IconButtonStyle())
        .help("View options")
    }

    private var optionEntries: [MenuEntry] {
        let modes: [MenuEntry] = [modeEntry(.rule, "Rule"), modeEntry(.global, "Global"), modeEntry(.direct, "Direct")]
        let layouts: [Option<ProxiesLayout>] = [
            Option(.tabs, String(localized: "Tabs")),
            Option(.list, String(localized: "List")),
        ]
        let densities: [Option<ProxiesDensity>] = [
            Option(.loose, String(localized: "Loose")),
            Option(.standard, String(localized: "Standard")),
            Option(.tight, String(localized: "Tight")),
        ]
        let icons: [Option<GroupIconStyle>] = [
            Option(.standard, String(localized: "Standard")),
            Option(.iconOnly, String(localized: "Icon only")),
            Option(.hidden, String(localized: "Hidden")),
        ]
        let tiles: [Option<ProxyTileStyle>] = [
            Option(.detailed, String(localized: "Detailed")),
            Option(.compact, String(localized: "Compact")),
            Option(.minimal, String(localized: "Name only")),
        ]
        let testAll = MenuEntry.action(
            String(localized: "Test all"),
            enabled: model.testing.isEmpty && !model.groups.isEmpty,
            perform: { model.testAllDelays() }
        )
        return [
            MenuEntry.submenu(String(localized: "Mode"), modes),
            choice(String(localized: "Show groups as"), \.proxiesLayout, or: .tabs, layouts),
            choice(String(localized: "Spacing"), \.proxiesDensity, or: .standard, densities),
            choice(String(localized: "Group icons"), \.groupIconStyle, or: .standard, icons),
            choice(String(localized: "Node tiles"), \.proxyTileStyle, or: .detailed, tiles),
            MenuEntry.separator,
            testAll,
        ]
    }

    private func modeEntry(_ mode: Mode, _ title: String.LocalizationValue) -> MenuEntry {
        .action(String(localized: title), checked: model.status?.mode == mode, perform: { model.setMode(mode) })
    }

    private func choice<Value: Equatable>(
        _ title: String,
        _ key: WritableKeyPath<AppSettings, Value>,
        or fallback: Value,
        _ options: [Option<Value>]
    ) -> MenuEntry {
        let current = model.appSettings?[keyPath: key] ?? fallback
        return .submenu(title, options.map { option in
            MenuEntry.action(option.title, checked: option.value == current, perform: {
                model.updateAppSettings { $0[keyPath: key] = option.value }
            })
        })
    }

    private var testButton: some View {
        Button {
            if let group = testedGroup { model.testDelay(group.name) }
        } label: {
            ZStack {
                Text("Test delay").opacity(testing ? 0 : 1)
                HStack(spacing: 8) {
                    Ring()
                    Text("Testing…")
                }
                .opacity(testing ? 1 : 0)
            }
        }
        .disabled(testing || testedGroup == nil)
    }

    private var testedGroup: ProxyGroup? {
        arrangement == .tabs ? currentGroup : model.primaryGroup
    }

    private var testing: Bool {
        testedGroup.map { model.testingGroups.contains($0.name) } ?? false
    }

    // MARK: Layouts

    private var masterDetail: some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: Ui.block) {
                    groupPopUp
                    nodeTable
                }
            } else {
                HStack(alignment: .top, spacing: Ui.block) {
                    GroupPane(
                        groups: shownGroups,
                        selected: currentGroup?.name,
                        iconStyle: iconStyle,
                        locateRequest: locateRequest
                    ) { selectedGroup = $0 }
                    .frame(width: 230)
                    nodeTable
                }
            }
        }
        .pagePadding()
    }

    private var groupPopUp: some View {
        MenuButton(placement: .overChecked) {
            HStack(spacing: 12) {
                Text(verbatim: currentGroup?.name ?? "—")
                Text(verbatim: currentGroup?.now ?? "")
                    .foregroundStyle(Color.ink2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                DownChevron()
            }
            .frame(maxWidth: .infinity)
        } entries: {
            shownGroups.map { group in
                MenuEntry.action(group.name, detail: group.now, checked: group.name == currentGroup?.name, perform: {
                    selectedGroup = group.name
                })
            }
        }
        .frame(maxWidth: 480, alignment: .leading)
    }

    @ViewBuilder
    private var nodeTable: some View {
        if let group = currentGroup {
            NodeTable(
                group: group,
                nodes: nodes(of: group),
                columns: NodeColumns(style: tileStyle, compact: compact),
                rowHeight: density.rowHeight,
                locateRequest: locateRequest
            )
        } else {
            noMatch
        }
    }

    private var noMatch: some View {
        Text("No nodes match “\(trimmedQuery)”.")
            .foregroundStyle(Color.ink2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var groupList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Ui.block) {
                    ForEach(shownGroups, id: \.name) { group in
                        GroupSection(
                            group: group,
                            nodes: nodes(of: group),
                            expanded: trimmedQuery.isEmpty ? expanded.contains(group.name) : true,
                            collapsible: trimmedQuery.isEmpty,
                            columns: NodeColumns(style: tileStyle, compact: compact),
                            rowHeight: density.rowHeight,
                            iconStyle: iconStyle
                        ) {
                            toggle(group.name)
                        }
                        .id(group.name)
                    }
                    if shownGroups.isEmpty { noMatch.padding(.top, 40) }
                }
                .pagePadding()
            }
            .onChange(of: locateRequest) { _ in
                guard let group = model.primaryGroup, let now = group.now else { return }
                proxy.scrollTo(group.name, anchor: .top)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    proxy.scrollTo(nodeAnchor(group.name, now), anchor: .center)
                }
            }
        }
    }

    // MARK: Data

    private var arrangement: ProxiesLayout { model.appSettings?.proxiesLayout ?? .tabs }
    private var sort: ProxiesSort { model.appSettings?.proxiesSort ?? .profile }
    private var density: ProxiesDensity { model.appSettings?.proxiesDensity ?? .standard }
    private var tileStyle: ProxyTileStyle { model.appSettings?.proxyTileStyle ?? .detailed }
    private var iconStyle: GroupIconStyle { model.appSettings?.groupIconStyle ?? .standard }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private func hit(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(trimmedQuery)
    }

    private var shownGroups: [ProxyGroup] {
        guard !trimmedQuery.isEmpty else { return model.groups }
        return model.groups.filter { hit($0.name) || $0.nodes.contains { hit($0.name) } }
    }

    private var currentGroup: ProxyGroup? {
        shownGroups.first { $0.name == selectedGroup } ?? shownGroups.first
    }

    /// A group whose name matches shows all its nodes; any other shows only the nodes that match.
    private func nodes(of group: ProxyGroup) -> [Node] {
        let matching = trimmedQuery.isEmpty || hit(group.name) ? group.nodes : group.nodes.filter { hit($0.name) }
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

    private func toggle(_ name: String) {
        if expanded.contains(name) { expanded.remove(name) } else { expanded.insert(name) }
    }

    /// Back to the main group and the node in use.
    private func locate() {
        guard let group = model.primaryGroup else { return }
        query = ""
        selectedGroup = group.name
        expanded.insert(group.name)
        locateRequest += 1
    }
}

private func nodeAnchor(_ group: String, _ node: String) -> String {
    "\(group)/\(node)"
}

/// Which columns a node row draws: the `Node tiles` setting, narrowed further when the content area is small.
private struct NodeColumns {
    let showsKind: Bool
    let showsDelay: Bool

    init(style: ProxyTileStyle, compact: Bool) {
        showsKind = style == .detailed && !compact
        showsDelay = style != .minimal
    }

    var widths: [ColumnWidth] {
        var widths: [ColumnWidth] = [.flex(1)]
        if showsKind { widths.append(.fixed(110)) }
        if showsDelay { widths.append(.fixed(72)) }
        return widths
    }
}

private struct GroupPaneHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// The group list scrolls on its own and hugs its rows, so a short list leaves no empty card.
private struct GroupPane: View {
    let groups: [ProxyGroup]
    let selected: String?
    let iconStyle: GroupIconStyle
    let locateRequest: Int
    let select: (String) -> Void
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groups, id: \.name) { group in
                        Button {
                            select(group.name)
                        } label: {
                            GroupPaneRow(group: group, iconStyle: iconStyle)
                        }
                        .buttonStyle(GroupPaneRowStyle(selected: group.name == selected))
                        .help(group.name)
                        .id(group.name)
                    }
                    if groups.isEmpty {
                        Text("No match")
                            .foregroundStyle(Color.ink2)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 46)
                    }
                }
                .padding(4)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(key: GroupPaneHeightKey.self, value: geometry.size.height)
                    }
                )
            }
            .frame(maxHeight: contentHeight > 0 ? contentHeight : nil)
            .onPreferenceChange(GroupPaneHeightKey.self) { height in
                contentHeight = height
            }
            .cardSurface()
            .onAppear { reveal(proxy) }
            .onChange(of: locateRequest) { _ in reveal(proxy) }
        }
    }

    private func reveal(_ proxy: ScrollViewProxy) {
        guard let selected else { return }
        DispatchQueue.main.async { proxy.scrollTo(selected) }
    }
}

private struct GroupPaneRowStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.ink)
            .background(
                configuration.isPressed ? Color.press : selected ? Color.listSelection : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
    }
}

private struct GroupPaneRow: View {
    let group: ProxyGroup
    let iconStyle: GroupIconStyle

    var body: some View {
        HStack(spacing: 8) {
            GroupIcon(group: group, style: iconStyle)
            Text(verbatim: group.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(verbatim: group.now ?? group.kind)
                .font(.system(size: 13))
                .foregroundStyle(Color.ink2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
    }
}

/// The `icon` a profile gives a proxy group, framed or on its own as FlClash's icon styles draw it.
private struct GroupIcon: View {
    let group: ProxyGroup
    let style: GroupIconStyle

    var body: some View {
        if style != .hidden, let url = group.icon.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: style == .standard ? 20 : 30, height: style == .standard ? 20 : 30)
                }
            }
            .frame(width: 30, height: 30)
            .background(
                style == .standard ? Color.track : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
    }
}

private struct NodeTable: View {
    @EnvironmentObject private var model: AppModel
    let group: ProxyGroup
    let nodes: [Node]
    let columns: NodeColumns
    let rowHeight: CGFloat
    let locateRequest: Int

    private var groupBusy: Bool { model.testingGroups.contains(group.name) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollingTable {
                ColumnsLayout(columns: columns.widths) {
                    Text("Name")
                    if columns.showsKind { Text("Type") }
                    if columns.showsDelay { Text("Delay").frame(maxWidth: .infinity, alignment: .trailing) }
                }
                .tableHeader()
            } rows: {
                ForEach(Array(nodes.enumerated()), id: \.element.name) { index, node in
                    let busy = groupBusy || model.testingNodes.contains(node.name)
                    NodeRow(
                        node: node,
                        selected: node.name == group.now,
                        busy: busy,
                        columns: columns,
                        height: rowHeight,
                        zebra: index % 2 == 0,
                        select: group.selectable ? { model.selectNode(group: group.name, node: node.name) } : nil,
                        testNode: { model.testNodeDelay(node.name) }
                    )
                    .id(nodeAnchor(group.name, node.name))
                }
            }
            .onAppear { reveal(proxy) }
            .onChange(of: locateRequest) { _ in reveal(proxy) }
            .onChange(of: group.name) { _ in reveal(proxy) }
        }
    }

    private func reveal(_ proxy: ScrollViewProxy) {
        guard let now = group.now else { return }
        DispatchQueue.main.async { proxy.scrollTo(nodeAnchor(group.name, now)) }
    }
}

private struct NodeRow: View {
    let node: Node
    let selected: Bool
    let busy: Bool
    let columns: NodeColumns
    let height: CGFloat
    let zebra: Bool
    let select: (() -> Void)?
    let testNode: () -> Void

    var body: some View {
        ColumnsLayout(columns: columns.widths) {
            HStack(spacing: 8) {
                CheckMark(visible: selected)
                if !columns.showsDelay { StatusDot(color: Format.delayTint(node.delay), size: 8) }
                Text(verbatim: node.name).lineLimit(1).truncationMode(.middle)
            }
            .allowsHitTesting(false)
            if columns.showsKind {
                Text(verbatim: node.kind).foregroundStyle(Color.ink2).lineLimit(1).allowsHitTesting(false)
            }
            if columns.showsDelay {
                DelayCell(node: node, busy: busy, action: testNode)
            }
        }
        .tableRow(height: height, zebra: zebra, hit: select)
        .contextMenu {
            Button("Test delay", action: testNode)
                .disabled(busy)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Clicking the delay tests that one node; clicking the rest of the row selects it.
private struct DelayCell: View {
    let node: Node
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: Format.delay(node) ?? "—")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Format.delayTint(node.delay))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(minWidth: 56, minHeight: 22)
                .opacity(busy ? 0.4 : 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .help("Test delay")
        .accessibilityLabel(busy ? Text("Testing…") : Text("Test delay"))
        .motion(Motion.hairline, value: busy)
    }
}

private struct GroupSection: View {
    @EnvironmentObject private var model: AppModel
    let group: ProxyGroup
    let nodes: [Node]
    let expanded: Bool
    let collapsible: Bool
    let columns: NodeColumns
    let rowHeight: CGFloat
    let iconStyle: GroupIconStyle
    let toggle: () -> Void

    private var testing: Bool { model.testingGroups.contains(group.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if expanded {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(nodes.enumerated()), id: \.element.name) { index, node in
                        let busy = testing || model.testingNodes.contains(node.name)
                        NodeRow(
                            node: node,
                            selected: node.name == group.now,
                            busy: busy,
                            columns: columns,
                            height: rowHeight,
                            zebra: index % 2 == 0,
                            select: group.selectable ? { model.selectNode(group: group.name, node: node.name) } : nil,
                            testNode: { model.testNodeDelay(node.name) }
                        )
                        .id(nodeAnchor(group.name, node.name))
                    }
                }
                .transition(.rowFold)
            }
        }
        .cardSurface()
        .motion(expanded ? Motion.rowIn : Motion.rowOut, value: expanded)
    }

    private var header: some View {
        Row {
            GroupIcon(group: group, style: iconStyle)
            Text(verbatim: group.name).font(Ui.boldFont).lineLimit(1)
            Text(verbatim: group.kind).foregroundStyle(Color.ink2).lineLimit(1)
            Text(verbatim: group.now ?? "")
                .foregroundStyle(Color.ink2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
            IconButton(symbol: "bolt", help: "Test delay", busy: testing) { model.testDelay(group.name) }
            if collapsible {
                IconButton(
                    symbol: "chevron.down",
                    help: expanded ? LocalizedStringKey("Hide nodes") : LocalizedStringKey("Show nodes"),
                    action: toggle
                )
                .rotationEffect(.degrees(expanded ? 180 : 0))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if collapsible { toggle() } }
    }
}
