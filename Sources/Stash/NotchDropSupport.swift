import Foundation
import CoreGraphics

/// The value accepted by the Stage A notch drop destination. Keeping this
/// independent of AppKit makes duplicate filtering deterministic and testable.
struct NotchDropPayload: Equatable {
    let items: [ShelfItem]

    init(items: [ShelfItem]) {
        var seen = Set<String>()
        self.items = items.filter { item in
            let key = "\(item.kind.rawValue)|\(item.value)"
            return seen.insert(key).inserted
        }
    }

    var isEmpty: Bool { items.isEmpty }

    var fingerprint: String {
        items.map { "\($0.kind.rawValue)|\($0.value)" }.sorted().joined(separator: "\n")
    }
}

struct NotchDropDeduplicator {
    private var handledSequences = Set<Int>()

    mutating func shouldAccept(sequence: Int, payload: NotchDropPayload) -> Bool {
        guard !payload.isEmpty, handledSequences.insert(sequence).inserted else { return false }
        // AppKit sequence numbers are short-lived. Retaining only a bounded
        // history prevents an accidental duplicate callback without treating a
        // later, intentional drop of the same file as a duplicate.
        if handledSequences.count > 64 { handledSequences.removeAll(keepingCapacity: true); handledSequences.insert(sequence) }
        return true
    }
}

enum NotchShelfVisibility: Equatable { case collapsed, expanded }

struct NotchCollapsePolicy {
    let isPerformingAction: Bool
    let isPreviewing: Bool
    let isPointerInside: Bool
    let isDraggingItem: Bool
    let hasAttachedSheet: Bool
    let isKeyWindow: Bool

    var allowsCollapse: Bool {
        !isPerformingAction && !isPreviewing && !isPointerInside && !isDraggingItem && !hasAttachedSheet && !isKeyWindow
    }
}

struct NotchShelfStateMachine {
    private(set) var visibility: NotchShelfVisibility = .collapsed
    mutating func expand() { visibility = .expanded }
    mutating func collapse(if policy: NotchCollapsePolicy) -> Bool {
        guard visibility == .expanded, policy.allowsCollapse else { return false }
        visibility = .collapsed
        return true
    }
    mutating func forceCollapse() { visibility = .collapsed }
}

enum NotchLayout {
    static func targetFrame(screenFrame: CGRect, visibleFrame: CGRect, notchFrame: CGRect?) -> CGRect {
        if let notchFrame {
            let width = notchFrame.width + 32
            let height: CGFloat = 52
            return CGRect(x: notchFrame.midX - width / 2, y: visibleFrame.maxY - height, width: width, height: height)
        }
        let width: CGFloat = 96
        let height: CGFloat = 14
        return CGRect(x: screenFrame.midX - width / 2, y: visibleFrame.maxY - 10, width: width, height: height)
    }

    static func collapsedShelfFrame(targetFrame: CGRect, notchFrame: CGRect?) -> CGRect { notchFrame ?? targetFrame }

    static func expandedFrame(visibleFrame: CGRect, anchorMaxY: CGFloat, itemCount: Int) -> CGRect {
        // Match the adaptive grid's 82-point tiles, 8-point spacing and
        // 40-point combined shell/grid insets. Keep columns stable on arrival.
        let width = min(360, visibleFrame.width - 24)
        let columns = max(1, Int((width - 40 + 8) / 90))
        let rows = ceil(CGFloat(max(itemCount, 1)) / CGFloat(max(columns, 1)))
        let height = min(max(220, rows * 106 + 146), min(440, visibleFrame.height - 36))
        return CGRect(x: visibleFrame.midX - width / 2, y: anchorMaxY - height, width: width, height: height)
    }
}
