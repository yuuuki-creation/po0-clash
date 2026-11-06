import AppKit
import SwiftUI

/// The items of an `NSMenu`, which SwiftUI's `Menu` cannot style a label for on macOS 13.
enum MenuEntry {
    case action(
        String,
        detail: String? = nil,
        checked: Bool = false,
        enabled: Bool = true,
        destructive: Bool = false,
        perform: () -> Void
    )
    case submenu(String, [MenuEntry])
    case separator
}

private final class MenuTarget: NSObject {
    private let perform: () -> Void

    init(_ perform: @escaping () -> Void) {
        self.perform = perform
    }

    @objc func fire() {
        perform()
    }
}

@MainActor
private enum NativeMenu {
    static func make(_ entries: [MenuEntry]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.font = .systemFont(ofSize: 14)
        for entry in entries { menu.addItem(item(entry)) }
        return menu
    }

    private static func item(_ entry: MenuEntry) -> NSMenuItem {
        switch entry {
        case .separator:
            return .separator()
        case .submenu(let title, let children):
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = make(children)
            return item
        case .action(let title, let detail, let checked, let enabled, let destructive, let perform):
            let target = MenuTarget(perform)
            let item = NSMenuItem(title: title, action: #selector(MenuTarget.fire), keyEquivalent: "")
            item.target = target
            item.representedObject = target
            item.state = checked ? .on : .off
            item.isEnabled = enabled
            if detail != nil || destructive {
                item.attributedTitle = attributed(title, detail: detail, destructive: destructive)
            }
            return item
        }
    }

    private static func attributed(_ title: String, detail: String?, destructive: Bool) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: 14)
        var titleAttributes: [NSAttributedString.Key: Any] = [.font: font]
        if destructive { titleAttributes[.foregroundColor] = NSColor.badText }
        let text = NSMutableAttributedString(string: title, attributes: titleAttributes)
        if let detail {
            text.append(NSAttributedString(
                string: "    \(detail)",
                attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
            ))
        }
        return text
    }
}

private final class MenuAnchorBox {
    weak var view: NSView?
}

private struct MenuAnchor: NSViewRepresentable {
    let box: MenuAnchorBox

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        box.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        box.view = view
    }
}

/// A button that opens a native menu: below itself, or with the checked item over it as a pop-up button does.
struct MenuButton<Label: View>: View {
    enum Placement {
        case below, belowTrailing, overChecked
    }

    private let placement: Placement
    private let label: Label
    private let entries: () -> [MenuEntry]
    @State private var anchor = MenuAnchorBox()

    init(placement: Placement = .below, @ViewBuilder label: () -> Label, entries: @escaping () -> [MenuEntry]) {
        self.placement = placement
        self.label = label()
        self.entries = entries
    }

    var body: some View {
        Button(action: present) { label }
            .background(MenuAnchor(box: anchor))
    }

    private func present() {
        guard let view = anchor.view else { return }
        let menu = NativeMenu.make(entries())
        switch placement {
        case .overChecked:
            let checked = menu.items.first { $0.state == .on }
            menu.popUp(positioning: checked, at: NSPoint(x: 0, y: view.bounds.height), in: view)
        case .below:
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: view)
        case .belowTrailing:
            menu.popUp(positioning: nil, at: NSPoint(x: view.bounds.width - menu.size.width, y: -4), in: view)
        }
    }
}

/// The same entries as a right-click menu.
struct MenuEntries: View {
    let entries: [MenuEntry]

    var body: some View {
        ForEach(entries.indices, id: \.self) { index in
            switch entries[index] {
            case .separator:
                Divider()
            case .submenu(let title, let children):
                Menu(title) { MenuEntries(entries: children) }
            case .action(let title, _, let checked, let enabled, let destructive, let perform):
                if checked {
                    Toggle(title, isOn: Binding(get: { true }, set: { _ in perform() }))
                        .disabled(!enabled)
                } else {
                    Button(title, role: destructive ? .destructive : nil, action: perform)
                        .disabled(!enabled)
                }
            }
        }
    }
}

struct DownChevron: View {
    var body: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.ink2)
    }
}

struct Option<Value> {
    let value: Value
    let title: String

    init(_ value: Value, _ title: String) {
        self.value = value
        self.title = title
    }
}

struct OptionMenu<Value: Equatable>: View {
    @Binding var selection: Value
    let options: [Option<Value>]

    private var title: String {
        options.first { $0.value == selection }?.title ?? "—"
    }

    var body: some View {
        MenuButton(placement: .overChecked) {
            HStack(spacing: 8) {
                Text(verbatim: title).lineLimit(1).truncationMode(.middle)
                DownChevron()
            }
        } entries: {
            options.map { option in
                MenuEntry.action(option.title, checked: option.value == selection, perform: { selection = option.value })
            }
        }
    }
}

struct OptionRow<Value: Equatable>: View {
    private let title: LocalizedStringKey
    @Binding private var selection: Value
    private let options: [Option<Value>]

    init(_ title: LocalizedStringKey, selection: Binding<Value>, options: [Option<Value>]) {
        self.title = title
        _selection = selection
        self.options = options
    }

    var body: some View {
        Row {
            Text(title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            OptionMenu(selection: $selection, options: options)
        }
    }
}
