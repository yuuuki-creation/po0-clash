import SwiftUI

enum ColumnWidth {
    case fixed(CGFloat)
    case flex(CGFloat)
}

/// One table row: fixed columns keep their width and the rest share what is left by weight.
struct ColumnsLayout: Layout {
    let columns: [ColumnWidth]
    var spacing: CGFloat = 12

    private func widths(for total: CGFloat) -> [CGFloat] {
        var fixed: CGFloat = 0
        var weights: CGFloat = 0
        for column in columns {
            switch column {
            case .fixed(let width): fixed += width
            case .flex(let weight): weights += weight
            }
        }
        let free = max(total - fixed - spacing * CGFloat(max(columns.count - 1, 0)), 0)
        return columns.map { column in
            switch column {
            case .fixed(let width): return width
            case .flex(let weight): return weights > 0 ? free * weight / weights : 0
            }
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposed = proposal.width ?? 480
        let total = proposed.isFinite ? proposed : 480
        let columnWidths = widths(for: total)
        var height: CGFloat = 0
        for (index, subview) in subviews.enumerated() where index < columnWidths.count {
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidths[index], height: nil))
            height = max(height, size.height)
        }
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (index, width) in widths(for: bounds.width).enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: nil)
            )
            x += width + spacing
        }
    }
}

extension View {
    /// `hit` sits under the cells, so a control in a cell still takes its own clicks.
    func tableRow(height: CGFloat = Ui.tableRow, zebra: Bool = false, hit: (() -> Void)? = nil) -> some View {
        padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .background(
                Group {
                    if let hit {
                        Button(action: hit) {
                            Rectangle().fill(Color.clear)
                        }
                        .buttonStyle(RowPressStyle())
                    }
                }
            )
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.line).frame(height: 1)
            }
    }

    func tableHeader() -> some View {
        foregroundStyle(Color.ink2)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: Ui.tableRow, alignment: .leading)
            .background(Color.card)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.line).frame(height: 1)
            }
    }
}

/// A scrolling table in a card, with a header that stays while the rows pass under it.
struct ScrollingTable<Header: View, Rows: View>: View {
    private let header: Header
    private let rows: Rows

    init(@ViewBuilder header: () -> Header, @ViewBuilder rows: () -> Rows) {
        self.header = header()
        self.rows = rows()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    rows
                } header: {
                    header
                }
            }
        }
        .cardSurface()
    }
}

private struct PageScrolledKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

private struct CompactContentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var pageScrolled: Binding<Bool> {
        get { self[PageScrolledKey.self] }
        set { self[PageScrolledKey.self] = newValue }
    }

    /// The content area is at most 700 wide: tables drop columns and the group list becomes a pop-up.
    var compactContent: Bool {
        get { self[CompactContentKey.self] }
        set { self[CompactContentKey.self] = newValue }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func pagePadding() -> some View {
        padding(.horizontal, Ui.pageInset)
            .padding(.top, 6)
            .padding(.bottom, Ui.pageInset)
    }
}

/// A page's scrolling content, at most 1100 wide, which tells the toolbar when it has left the top.
struct PageScroll<Content: View>: View {
    private let content: Content
    @Environment(\.pageScrolled) private var scrolled

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Ui.block) { content }
                .frame(maxWidth: Ui.maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .pagePadding()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: proxy.frame(in: .named("page-scroll")).minY
                        )
                    }
                )
        }
        .coordinateSpace(name: "page-scroll")
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            scrolled.wrappedValue = offset < -0.5
        }
    }
}

/// Side by side when each column can be 340 wide, otherwise stacked.
struct TwoColumns: Layout {
    var spacing: CGFloat = Ui.block

    private func isWide(_ width: CGFloat) -> Bool {
        width >= Ui.columnWidth * 2 + spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposed = proposal.width ?? Ui.columnWidth * 2 + spacing
        let total = proposed.isFinite ? proposed : Ui.columnWidth * 2 + spacing
        if isWide(total) {
            let width = (total - spacing) / 2
            let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }.max() ?? 0
            return CGSize(width: total, height: height)
        }
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: total, height: nil)).height }
        return CGSize(width: total, height: heights.reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if isWide(bounds.width) {
            let width = (bounds.width - spacing) / 2
            for (index, subview) in subviews.enumerated() {
                subview.place(
                    at: CGPoint(x: bounds.minX + (width + spacing) * CGFloat(index), y: bounds.minY),
                    proposal: ProposedViewSize(width: width, height: nil)
                )
            }
            return
        }
        var y = bounds.minY
        for subview in subviews {
            let proposed = ProposedViewSize(width: bounds.width, height: nil)
            subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: proposed)
            y += subview.sizeThatFits(proposed).height + spacing
        }
    }
}
