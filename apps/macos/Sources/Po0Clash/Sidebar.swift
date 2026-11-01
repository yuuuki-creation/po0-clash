import AppKit
import SwiftUI

struct Sidebar: NSViewRepresentable {
    @Binding var page: Page
    let accent: NSColor
    let onAccent: NSColor
    /// Off while a dialog is up, so the arrow keys cannot change the page behind it.
    let enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(page: $page, accent: accent, onAccent: onAccent) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = SidebarTable()
        table.style = .plain
        table.rowHeight = 32
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.selectionHighlightStyle = .regular
        table.focusRingType = .none
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
        context.coordinator.onAccent = onAccent
        guard let table = scroll.documentView as? NSTableView else { return }
        table.isEnabled = enabled
        let row = Page.allCases.firstIndex(of: page) ?? 0
        if table.selectedRow != row { table.selectRowIndexes([row], byExtendingSelection: false) }
        table.enumerateAvailableRowViews { view, _ in
            (view as? SidebarRow)?.accent = accent
            (view.view(atColumn: 0) as? SidebarCell)?.setColors(accent: accent, onAccent: onAccent)
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var page: Binding<Page>
        var accent: NSColor
        var onAccent: NSColor

        init(page: Binding<Page>, accent: NSColor, onAccent: NSColor) {
            self.page = page
            self.accent = accent
            self.onAccent = onAccent
        }

        func numberOfRows(in tableView: NSTableView) -> Int { Page.allCases.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let cell = tableView.makeView(withIdentifier: SidebarCell.identifier, owner: nil) as? SidebarCell
                ?? SidebarCell(frame: .zero)
            cell.setColors(accent: accent, onAccent: onAccent)
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

/// A solid accent pill, with no system highlight or fade.
private final class SidebarRow: NSTableRowView {
    var accent = NSColor.controlAccentColor {
        didSet { if isSelected { needsDisplay = true } }
    }

    override var isEmphasized: Bool {
        get { true }
        set {}
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        isSelected ? .emphasized : .normal
    }

    override func drawSelection(in dirtyRect: NSRect) {
        accent.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
    }
}

private final class SidebarCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("SidebarCell")

    private var accent = NSColor.controlAccentColor
    private var onAccent = NSColor.white

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.identifier
        let image = NSImageView()
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let text = NSTextField(labelWithString: "")
        text.font = .systemFont(ofSize: 14)
        text.lineBreakMode = .byTruncatingTail
        for view in [image, text] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        imageView = image
        textField = text
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            image.centerYAnchor.constraint(equalTo: centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 18),
            text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 10),
            text.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { tint() }
    }

    func setColors(accent: NSColor, onAccent: NSColor) {
        self.accent = accent
        self.onAccent = onAccent
        tint()
    }

    func show(_ page: Page) {
        imageView?.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: nil)
        textField?.stringValue = page.name
    }

    private func tint() {
        let selected = backgroundStyle == .emphasized
        imageView?.contentTintColor = selected ? onAccent : accent
        textField?.textColor = selected ? onAccent : .inkText
    }
}
