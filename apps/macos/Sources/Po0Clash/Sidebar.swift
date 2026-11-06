import AppKit
import SwiftUI

struct Sidebar: View {
    @Binding var page: Page
    let accent: Color
    let onAccent: Color
    let enabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Page.allCases) { item in
                SidebarItemButton(
                    item: item,
                    selected: page == item,
                    accent: accent,
                    onAccent: onAccent
                ) {
                    if page != item { page = item }
                }
            }
            Spacer(minLength: 0)
        }
        .disabled(!enabled)
    }
}

private struct SidebarItemButton: View {
    let item: Page
    let selected: Bool
    let accent: Color
    let onAccent: Color
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? onAccent : accent)
                    .frame(width: 18, alignment: .center)
                Text(verbatim: item.name)
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? onAccent : Color.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: Ui.control, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: Ui.controlRadius, style: .continuous))
        }
        .buttonStyle(SidebarButtonStyle(selected: selected, hovered: hovered, accent: accent))
        .onHover { hovered = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    let selected: Bool
    let hovered: Bool
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Ui.controlRadius, style: .continuous)
        configuration.label
            .background(
                selected
                    ? accent
                    : configuration.isPressed
                        ? Color.press
                        : hovered ? Color.hover : Color.clear,
                in: shape
            )
    }
}
