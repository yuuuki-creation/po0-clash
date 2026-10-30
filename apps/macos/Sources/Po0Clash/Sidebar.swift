import AppKit
import SwiftUI

/// AppKit's source list, since a SwiftUI sidebar draws its selection in the system accent whatever the tint. The
/// selection is painted as the row background because macOS 14 and 15 never call a source list's selection drawing.
struct Sidebar: NSViewRepresentable {
    @Binding var page: Page
    let accent: NSColor

    func makeCoordinator() -> Coordinator { Coordinator(page: $page) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = SidebarTable()
        table.style = .sourceList
        table.rowSizeStyle = .default
        table.selectionHighlightStyle = .none
        table.headerView = nil
        table.backgroundColor = .clear
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("page"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.reloadData()
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.page = $page
        context.coordinator.accent = accent
        guard let table = scroll.documentView as? NSTableView else { return }
        let row = Page.allCases.firstIndex(of: page) ?? 0
        if table.selectedRow != row { table.selectRowIndexes([row], byExtendingSelection: false) }
        table.enumerateAvailableRowViews { view, _ in
            (view as? SidebarRow)?.accent = accent
            (view.view(atColumn: 0) as? SidebarCell)?.accent = accent
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var page: Binding<Page>
        var accent = NSColor.controlAccentColor

        init(page: Binding<Page>) {
            self.page = page
        }

        func numberOfRows(in tableView: NSTableView) -> Int { Page.allCases.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let cell = tableView.makeView(withIdentifier: SidebarCell.identifier, owner: nil) as? SidebarCell
                ?? SidebarCell(frame: .zero)
            cell.accent = accent
            cell.show(Page.allCases[row])
            return cell
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let view = SidebarRow()
            view.accent = accent
            return view
        }

        func tableView(_ tableView: NSTableView, typeSelectStringFor tableColumn: NSTableColumn?, row: Int) -> String? {
            Page.allCases[row].name
        }

        func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposed: IndexSet) -> IndexSet {
            proposed.isEmpty ? tableView.selectedRowIndexes : proposed
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let table = notification.object as? NSTableView,
                  Page.allCases.indices.contains(table.selectedRow) else { return }
            let selected = Page.allCases[table.selectedRow]
            if page.wrappedValue != selected { page.wrappedValue = selected }
        }
    }
}

/// The SwiftUI list it replaces held the focus when the window opened.
private final class SidebarTable: NSTableView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}

private final class SidebarRow: NSTableRowView {
    var accent = NSColor.controlAccentColor {
        didSet {
            if isSelected, accent != oldValue { needsDisplay = true }
        }
    }

    override var isSelected: Bool {
        didSet { needsDisplay = true }
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        isSelected ? .emphasized : .normal
    }

    /// Darkened a little, as the system darkens its accent for selections, so white text stays legible.
    override func drawBackground(in dirtyRect: NSRect) {
        guard isSelected else { return }
        (accent.blended(withFraction: 0.12, of: .black) ?? accent).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 0), xRadius: 8, yRadius: 8).fill()
    }
}

private final class SidebarCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("SidebarCell")

    var accent = NSColor.controlAccentColor {
        didSet { tint() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.identifier
        let image = NSImageView()
        let text = NSTextField(labelWithString: "")
        text.lineBreakMode = .byTruncatingTail
        for view in [image, text] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        imageView = image
        textField = text
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            image.centerYAnchor.constraint(equalTo: centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 18),
            text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
            text.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { tint() }
    }

    func show(_ page: Page) {
        imageView?.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: nil)
        textField?.stringValue = page.name
    }

    private func tint() {
        let selected = backgroundStyle == .emphasized
        imageView?.contentTintColor = selected ? .white : accent
        textField?.textColor = selected ? .white : .labelColor
    }
}
