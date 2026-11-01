import SwiftUI

/// The dialogs of the main window, topmost last. AppKit sheets cannot take the design's 200 and 150 ms or its
/// surface on macOS 26, so these are drawn over the window from `DialogLayer`.
@MainActor
final class DialogCenter: ObservableObject {
    struct Entry: Identifiable {
        let id: UUID
        let content: AnyView
        let closesOnScrimClick: Bool
        let onClose: () -> Void
    }

    @Published private(set) var stack: [Entry] = []

    func present(_ entry: Entry) {
        stack.removeAll { $0.id == entry.id }
        stack.append(entry)
    }

    func remove(_ id: UUID) {
        stack.removeAll { $0.id == id }
    }

    func close(_ id: UUID) {
        guard let entry = stack.first(where: { $0.id == id }) else { return }
        remove(id)
        entry.onClose()
    }
}

struct DismissDialogAction {
    fileprivate let action: () -> Void

    func callAsFunction() {
        action()
    }
}

private struct DismissDialogKey: EnvironmentKey {
    static let defaultValue = DismissDialogAction(action: {})
}

extension EnvironmentValues {
    var dismissDialog: DismissDialogAction {
        get { self[DismissDialogKey.self] }
        set { self[DismissDialogKey.self] = newValue }
    }
}

private struct ItemDialog<Item: Identifiable, Dialog: View>: ViewModifier {
    @EnvironmentObject private var center: DialogCenter
    @Binding var item: Item?
    let closesOnScrimClick: Bool
    let dialog: (Item) -> Dialog
    @State private var key = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { sync() }
            .onChange(of: item?.id) { _ in sync() }
            .onDisappear { center.remove(key) }
    }

    private func sync() {
        guard let item else {
            center.remove(key)
            return
        }
        center.present(DialogCenter.Entry(
            id: key,
            content: AnyView(dialog(item)),
            closesOnScrimClick: closesOnScrimClick,
            onClose: { self.item = nil }
        ))
    }
}

private struct PresentedFlag: Identifiable {
    let id = 0
}

extension View {
    func dialog<Item: Identifiable, Dialog: View>(
        item: Binding<Item?>,
        closesOnScrimClick: Bool = false,
        @ViewBuilder content: @escaping (Item) -> Dialog
    ) -> some View {
        modifier(ItemDialog(item: item, closesOnScrimClick: closesOnScrimClick, dialog: content))
    }

    func dialog<Dialog: View>(
        isPresented: Binding<Bool>,
        closesOnScrimClick: Bool = false,
        @ViewBuilder content: @escaping () -> Dialog
    ) -> some View {
        dialog(
            item: Binding<PresentedFlag?>(
                get: { isPresented.wrappedValue ? PresentedFlag() : nil },
                set: { isPresented.wrappedValue = $0 != nil }
            ),
            closesOnScrimClick: closesOnScrimClick
        ) { _ in
            content()
        }
    }
}

struct DialogLayer: View {
    @EnvironmentObject private var center: DialogCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(Array(center.stack.enumerated()), id: \.element.id) { index, entry in
                Color.scrim
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if entry.closesOnScrimClick { center.close(entry.id) }
                    }
                    .transition(scrimTransition)
                    .zIndex(Double(index * 2))
                panel(entry, isTop: index == center.stack.count - 1)
                    .transition(panelTransition)
                    .zIndex(Double(index * 2 + 1))
            }
        }
        .animation(reduceMotion ? nil : Motion.dialogIn, value: center.stack.map(\.id))
    }

    private func panel(_ entry: DialogCenter.Entry, isTop: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return entry.content
            .environment(\.dismissDialog, DismissDialogAction { center.close(entry.id) })
            .disabled(!isTop)
            .padding(20)
            .background(Color.dialogSurface, in: shape)
            .overlay(shape.stroke(Color.black.opacity(0.2), lineWidth: 0.5))
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.32), radius: 24, y: 16)
            .padding(24)
    }

    private var scrimTransition: AnyTransition {
        reduceMotion
            ? .identity
            : .asymmetric(
                insertion: AnyTransition.opacity.animation(.linear(duration: 0.2)),
                removal: AnyTransition.opacity.animation(.linear(duration: 0.15))
            )
    }

    private var panelTransition: AnyTransition {
        if reduceMotion { return .identity }
        let moved = AnyTransition.opacity
            .combined(with: .scale(scale: 0.97))
            .combined(with: .offset(y: -6))
        return .asymmetric(insertion: moved.animation(Motion.dialogIn), removal: moved.animation(Motion.dialogOut))
    }
}

/// A dialog's heading, with what it applies to beside it.
struct DialogTitle: View {
    let title: LocalizedStringKey
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).font(.system(size: 15, weight: .semibold))
            if let detail {
                Text(verbatim: detail).foregroundStyle(Color.ink2).lineLimit(1).truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The right-aligned buttons at the foot of a dialog.
struct DialogActions<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) { content }
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct ConfirmDialog: View {
    let title: String
    var message: LocalizedStringKey?
    let confirm: LocalizedStringKey
    let action: () -> Void
    @Environment(\.dismissDialog) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: title).font(.system(size: 15, weight: .semibold))
            if let message { Text(message).fixedSize(horizontal: false, vertical: true) }
            DialogActions {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(confirm) {
                    dismiss()
                    action()
                }
                .buttonStyle(ActionButtonStyle(primary: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 440)
    }
}

/// A message with one button, in place of a system alert.
struct NoticeDialog: View {
    let text: String
    @Environment(\.dismissDialog) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            DialogActions {
                Button("OK") { dismiss() }
                    .buttonStyle(ActionButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: 440)
    }
}
