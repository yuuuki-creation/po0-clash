import AppKit
import Po0FFI
import SwiftUI
import UniformTypeIdentifiers

struct DashboardDropTarget: DropDelegate {
    let card: DashboardCard
    @Binding var dragged: DashboardCard?
    @Binding var cards: [DashboardCard]
    let save: ([DashboardCard]) -> Void

    func validateDrop(info: DropInfo) -> Bool { dragged != nil }

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != card,
              let source = cards.firstIndex(of: dragged),
              let destination = cards.firstIndex(of: card) else { return }
        var next = cards
        next.insert(next.remove(at: source), at: destination)
        cards = next
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        guard dragged != nil else { return false }
        save(cards)
        dragged = nil
        return true
    }
}

struct DashboardDragHandle: NSViewRepresentable {
    let started: () -> Void
    let ended: () -> Void

    func makeNSView(context: Context) -> DragHandleView { DragHandleView() }

    func updateNSView(_ view: DragHandleView, context: Context) {
        view.started = started
        view.ended = ended
    }

    final class DragHandleView: NSImageView, NSDraggingSource {
        var started: () -> Void = {}
        var ended: () -> Void = {}

        init() {
            super.init(frame: .zero)
            image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)
            contentTintColor = .secondaryLabelColor
            setAccessibilityLabel(String(localized: "Drag to reorder"))
            toolTip = String(localized: "Drag to reorder")
        }

        required init?(coder: NSCoder) { nil }

        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

        override func mouseDown(with event: NSEvent) {}

        override func mouseDragged(with event: NSEvent) {
            let item = NSDraggingItem(pasteboardWriter: "po0-clash-dashboard" as NSString)
            item.setDraggingFrame(bounds, contents: image)
            started()
            beginDraggingSession(with: [item], event: event, source: self)
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            .move
        }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            ended()
        }
    }
}
