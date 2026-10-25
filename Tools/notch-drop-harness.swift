import Foundation

@main
struct NotchDropHarness {
    static func main() {
        let source = URL(fileURLWithPath: "/tmp/Stash Fixture.png")
        let duplicateFiles = NotchDropPayload(items: [ShelfItem(fileURL: source), ShelfItem(fileURL: source)])
        precondition(duplicateFiles.items.count == 1, "Duplicate file references must collapse within one drop.")

        let mixed = NotchDropPayload(items: [ShelfItem(fileURL: source), ShelfItem(text: "https://example.com", isURL: true), ShelfItem(text: "A note")])
        precondition(mixed.items.count == 3 && !mixed.isEmpty, "Supported file, URL, and text payloads must be retained.")

        var deduplicator = NotchDropDeduplicator()
        precondition(deduplicator.shouldAccept(sequence: 42, payload: mixed), "The first drag sequence must be accepted.")
        precondition(!deduplicator.shouldAccept(sequence: 42, payload: mixed), "A repeated AppKit drag sequence must not create another shelf.")
        precondition(deduplicator.shouldAccept(sequence: 43, payload: mixed), "A later intentional drag must remain valid.")
        precondition(!deduplicator.shouldAccept(sequence: 44, payload: NotchDropPayload(items: [])), "Empty or unsupported payloads must be rejected.")

        let display = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let visible = CGRect(x: 1440, y: 80, width: 1920, height: 968)
        let notch = CGRect(x: 2310, y: 1048, width: 180, height: 32)
        let target = NotchLayout.targetFrame(screenFrame: display, visibleFrame: visible, notchFrame: notch)
        precondition(target.midX == notch.midX && target.maxY == visible.maxY && target.height == 52 && target.width == notch.width + 32, "The invisible trigger must sit below the menu bar and be large enough for notch-bound drags to cross.")
        precondition(NotchLayout.collapsedShelfFrame(targetFrame: target, notchFrame: notch) == notch, "The visual shelf must still animate from the physical notch rather than the larger invisible trigger.")
        let manyItems = NotchLayout.expandedFrame(visibleFrame: visible, anchorMaxY: notch.minY + 3, itemCount: 50)
        precondition(manyItems.width <= 576 && manyItems.height <= 440 && manyItems.minX >= visible.minX && manyItems.maxX <= visible.maxX && manyItems.minY >= visible.minY && manyItems.maxY <= visible.maxY + 4, "Large shelves must remain bounded and visually connected to the notch.")

        let idle = NotchCollapsePolicy(isPerformingAction: false, isPreviewing: false, isPointerInside: false, isDraggingItem: false, hasAttachedSheet: false, isKeyWindow: false)
        let oneRow = NotchLayout.expandedFrame(visibleFrame: visible, anchorMaxY: notch.minY, itemCount: 3)
        let sixOnOneRow = NotchLayout.expandedFrame(visibleFrame: visible, anchorMaxY: notch.minY, itemCount: 6)
        let secondRow = NotchLayout.expandedFrame(visibleFrame: visible, anchorMaxY: notch.minY, itemCount: 7)
        precondition(sixOnOneRow.width > oneRow.width && sixOnOneRow.height == oneRow.height && sixOnOneRow.maxY == oneRow.maxY, "Files four through six must grow the shelf sideways while retaining one row.")
        precondition(secondRow.height > sixOnOneRow.height && secondRow.width == sixOnOneRow.width && secondRow.maxY == sixOnOneRow.maxY, "Only the seventh file may add a new row below the six-column layout.")
        let previewing = NotchCollapsePolicy(isPerformingAction: false, isPreviewing: true, isPointerInside: false, isDraggingItem: false, hasAttachedSheet: false, isKeyWindow: false)
        let dragging = NotchCollapsePolicy(isPerformingAction: false, isPreviewing: false, isPointerInside: false, isDraggingItem: true, hasAttachedSheet: false, isKeyWindow: false)
        var state = NotchShelfStateMachine()
        state.expand()
        precondition(!state.collapse(if: previewing) && state.visibility == .expanded, "Preview must suppress collapse.")
        precondition(!state.collapse(if: dragging) && state.visibility == .expanded, "Drag-out must suppress collapse.")
        precondition(state.collapse(if: idle) && state.visibility == .collapsed, "An idle expanded shelf may collapse.")
        print("PASS: notch payloads, duplicate protection, display geometry, expansion state, and collapse suppression")
    }
}
