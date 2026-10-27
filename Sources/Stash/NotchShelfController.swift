import AppKit
import UniformTypeIdentifiers
import Combine

@MainActor
final class NotchShelfController: NSObject, ObservableObject {
    @Published private(set) var tabs: [Shelf] = []
    @Published private(set) var selectedTabID: UUID?
    private var tabControllers: [UUID: ShelfWindowController] = [:]

    func openCurrent() {
        if !preferences.isEnabled { preferences.isEnabled = true }
        heldOpen = true
        let screen = activeScreen ?? NSScreen.main
        guard let screen else { return }
        activeScreen = screen
        expand(on: screen)
        updateTargetControls()
    }

    func newTab(items: [ShelfItem] = []) {
        var number = 1
        let names = Set(tabs.map(\.title))
        while names.contains("Stash \(number)") { number += 1 }
        let shelf = Shelf(title: "Stash \(number)", items: items)
        selectTab(registerTab(shelf).shelf.id)
    }

    func restoreTabs(_ shelves: [Shelf]) {
        for shelf in shelves { _ = registerTab(shelf) }
    }

    func openPinned(_ shelf: Shelf) {
        if tabControllers[shelf.id] == nil { _ = registerTab(shelf) }
        selectTab(shelf.id)
    }

    func selectTab(_ id: UUID) {
        guard let next = tabControllers[id] else { return }
        // A sheet or Quick Look session belongs to its original tab.
        guard shelfController?.isPerformingAction != true,
              shelfController?.isPreviewing != true,
              shelfController?.window?.attachedSheet == nil else { return }
        if shelfController !== next {
            transitionID = UUID()
            layoutWorkItem?.cancel()
            let previousWindow = shelfController?.window
            let staysOpen = isExpanded && previousWindow?.isVisible == true
            if staysOpen, let previousWindow, let nextWindow = next.window {
                // Present the destination at the existing shell geometry before
                // hiding the old tab. Never restart the notch entrance animation.
                nextWindow.setFrame(previousWindow.frame, display: false)
                nextWindow.alphaValue = 1
                nextWindow.contentView?.layoutSubtreeIfNeeded()
                nextWindow.orderFrontRegardless()
                if previousWindow.isKeyWindow { nextWindow.makeKey() }
            } else {
                stateMachine.forceCollapse()
            }
            shelfController = next
            selectedTabID = id
            previousWindow?.orderOut(nil)
        }
        openCurrent()
    }

    func closeTab(_ id: UUID) {
        guard let controller = tabControllers[id], !controller.isPerformingAction,
              !controller.isPreviewing, controller.window?.attachedSheet == nil else { return }
        let wasSelected = selectedTabID == id
        if wasSelected {
            collapse(animated: false, respectingInteraction: false)
            shelfController = nil
            selectedTabID = nil
        }
        // Closing a pinned tab hides it for this session; its saved copy remains.
        controller.close()
        coordinator?.didDismiss(controller)
        tabControllers[id] = nil
        tabs.removeAll { $0.id == id }
        if wasSelected, let next = tabs.first { selectTab(next.id) }
    }

    private func registerTab(_ shelf: Shelf) -> ShelfWindowController {
        if let existing = tabControllers[shelf.id] { return existing }
        guard let coordinator else { fatalError("Missing shelf coordinator") }
        let controller = coordinator.makeNotchShelfController(shelf: shelf)
        controller.notchWorkspace = self
        controller.shelfDidChange = { [weak self, weak controller] in
            guard let self, let controller, let index = self.tabs.firstIndex(where: { $0.id == controller.shelf.id }) else { return }
            self.tabs[index] = controller.shelf
        }
        configure(controller)
        tabControllers[shelf.id] = controller
        tabs.append(shelf)
        return controller
    }
    private weak var coordinator: ShelfCoordinator?
    private let preferences: NotchPreferences
    private var targets: [CGDirectDisplayID: NotchTargetPanel] = [:]
    private var shelfController: ShelfWindowController?
    private var activeScreen: NSScreen?
    private var collapseWorkItem: DispatchWorkItem?
    private var dragPreviewCollapseWorkItem: DispatchWorkItem?
    private var dragPreviewActive = false
    private var wasExpandedBeforeDrag = false
    private var heldOpen = false
    private var transitionID = UUID()
    private var layoutWorkItem: DispatchWorkItem?
    private nonisolated(unsafe) var screenObserver: NSObjectProtocol?
    private var stateMachine = NotchShelfStateMachine()
    private var isExpanded: Bool { stateMachine.visibility == .expanded }

    init(coordinator: ShelfCoordinator, preferences: NotchPreferences) {
        self.coordinator = coordinator
        self.preferences = preferences
        super.init()
        preferences.onChange = { [weak self] in self?.preferencesDidChange() }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refreshTargets() } }
    }

    deinit { if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) } }

    func show() {
        guard preferences.isEnabled else { return }
        refreshTargets()
    }

    func collapse(animated: Bool = true, respectingInteraction: Bool = true) {
        collapseWorkItem?.cancel()
        dragPreviewCollapseWorkItem?.cancel()
        guard isExpanded, let shelfController, let window = shelfController.window else { return }
        if respectingInteraction && heldOpen { return }
        if animated && respectingInteraction {
            let policy = NotchCollapsePolicy(
                isPerformingAction: shelfController.isPerformingAction,
                isPreviewing: shelfController.isPreviewing,
                isPointerInside: false,
                isDraggingItem: NSEvent.pressedMouseButtons != 0,
                hasAttachedSheet: window.attachedSheet != nil,
                isKeyWindow: false
            )
            guard stateMachine.collapse(if: policy) else { scheduleCollapse(); return }
        } else { stateMachine.forceCollapse() }
        heldOpen = false
        dragPreviewActive = false
        transitionID = UUID()
        let closingID = transitionID
        updateTargetControls()
        let screen = activeScreen ?? window.screen ?? NSScreen.main
        let destination = screen.map(collapsedShelfFrame(on:)) ?? window.frame
        let duration = motionDuration(animated: animated)
        if duration == 0 {
            window.orderOut(nil)
            window.setFrame(destination, display: false)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0.2
            window.animator().setFrame(destination, display: true)
        } completionHandler: {
            Task { @MainActor [weak self] in
                guard let self, self.transitionID == closingID, !self.isExpanded else { return }
                window.orderOut(nil)
                window.alphaValue = 1
            }
        }
    }

    private func preferencesDidChange() {
        if preferences.isEnabled { refreshTargets() }
        else {
            targets.values.forEach { $0.panel.orderOut(nil) }
            shelfController?.window?.orderOut(nil)
            stateMachine.forceCollapse()
        }
        scheduleCollapse()
    }

    private func refreshTargets() {
        guard preferences.isEnabled else { return }
        let currentIDs = Set(NSScreen.screens.compactMap(displayID(for:)))
        let removedIDs = targets.keys.filter { !currentIDs.contains($0) }
        for id in removedIDs { targets[id]?.panel.close(); targets[id] = nil }

        for screen in NSScreen.screens {
            guard let id = displayID(for: screen) else { continue }
            let target = targets[id] ?? makeTarget(for: screen, displayID: id)
            target.screen = screen
            target.panel.setFrame(targetFrame(on: screen), display: true)
            target.panel.orderFrontRegardless()
        }
        if isExpanded, let activeScreen { positionExpandedShelf(on: activeScreen, animated: false) }
    }

    private func makeTarget(for screen: NSScreen, displayID: CGDirectDisplayID) -> NotchTargetPanel {
        let frame = targetFrame(on: screen)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let hasHardwareNotch = notchFrame(on: screen) != nil
        let view = NotchDropTargetView(frame: NSRect(origin: .zero, size: frame.size), hasHardwareNotch: hasHardwareNotch)
        let target = NotchTargetPanel(panel: panel, view: view, screen: screen)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = view
        view.onDrop = { [weak self, weak target] payload, _ in
            guard let self, let screen = target?.screen else { return false }
            return self.accept(payload, on: screen)
        }
        view.onDragValidityChange = { [weak self, weak target] isValid in
            guard let self, let screen = target?.screen else { return }
            self.dragValidityChanged(isValid, on: screen)
        }
        view.onToggle = { [weak self, weak target] in
            guard let self, let screen = target?.screen else { return }
            if self.isExpanded && self.heldOpen {
                self.collapse(animated: true, respectingInteraction: false)
            } else {
                self.heldOpen = true
                self.activeScreen = screen
                self.expand(on: screen)
                self.updateTargetControls()
            }
        }
        targets[displayID] = target
        return target
    }

    private func accept(_ payload: NotchDropPayload, on screen: NSScreen) -> Bool {
        guard preferences.isEnabled, !payload.isEmpty else { return false }
        dragPreviewActive = false
        dragPreviewCollapseWorkItem?.cancel()
        if preferences.postDropBehavior == .newFloatingShelf {
            coordinator?.newShelf(with: payload.items)
            return true
        }

        let controller = notchShelfController()
        controller.appendItems(payload.items)
        activeScreen = screen
        expand(on: screen)
        scheduleCollapse()
        return true
    }

    private func dragValidityChanged(_ isValid: Bool, on screen: NSScreen) {
        guard preferences.postDropBehavior == .notchShelf else { return }
        if isValid {
            guard !dragPreviewActive else { return }
            dragPreviewCollapseWorkItem?.cancel()
            dragPreviewActive = true
            wasExpandedBeforeDrag = isExpanded
            activeScreen = screen
            expand(on: screen)
        } else {
            // Opening the shelf transfers AppKit destination ownership from
            // this trigger to the shelf. Exit is not cancellation: closing here
            // caused an endless enter/exit loop underneath a stationary drag.
            dragPreviewActive = false
        }
    }

    private func notchShelfController() -> ShelfWindowController {
        if let shelfController { return shelfController }
        let controller = tabs.first.flatMap { tabControllers[$0.id] } ?? registerTab(Shelf(title: "Stash 1"))
        shelfController = controller
        selectedTabID = controller.shelf.id
        return controller
    }

    private func configure(_ controller: ShelfWindowController) {
        controller.dismissHandler = { [weak self] in self?.collapse(animated: true, respectingInteraction: false) }
        controller.itemsDidChange = { [weak self] in
            guard let self else { return }
            self.layoutWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isExpanded, let screen = self.activeScreen else { return }
                self.expand(on: screen)
                self.scheduleCollapse()
            }
            self.layoutWorkItem = work
            // Coalesce asynchronously delivered files into one geometry change.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
        }
    }

    private func expand(on screen: NSScreen) {
        collapseWorkItem?.cancel()
        dragPreviewCollapseWorkItem?.cancel()
        let controller = notchShelfController()
        guard let window = controller.window else { return }
        let start = collapsedShelfFrame(on: screen)
        let destination = expandedFrame(on: screen, itemCount: controller.shelf.items.count)
        if isExpanded && window.frame == destination { return }
        transitionID = UUID()
        if !isExpanded {
            window.setFrame(start, display: false)
            window.alphaValue = 0.2
            window.orderFrontRegardless()
        }
        stateMachine.expand()
        scheduleCollapse()
        updateTargetControls()
        let duration = motionDuration(animated: true)
        if duration == 0 {
            window.alphaValue = 1
            window.setFrame(destination, display: true)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                window.animator().alphaValue = 1
                window.animator().setFrame(destination, display: true)
            }
        }
    }

    private func positionExpandedShelf(on screen: NSScreen, animated: Bool) {
        guard let controller = shelfController, let window = controller.window else { return }
        let destination = expandedFrame(on: screen, itemCount: controller.shelf.items.count)
        window.setFrame(destination, display: true, animate: animated && motionDuration(animated: true) > 0)
    }

    private func scheduleCollapse() {
        collapseWorkItem?.cancel()
        guard isExpanded, !heldOpen else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.collapse(animated: true)
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func targetFrame(on screen: NSScreen) -> NSRect {
        NotchLayout.targetFrame(screenFrame: screen.frame, visibleFrame: screen.visibleFrame, notchFrame: notchFrame(on: screen))
    }

    private func updateTargetControls() {
        for target in targets.values {
            guard let screen = target.screen else { continue }
            let isActive = isExpanded && displayID(for: screen) == activeScreen.flatMap(displayID(for:))
            target.view.isShelfOpen = isActive && heldOpen
            var frame = targetFrame(on: screen)
            if isActive {
                // Only the visible pill sits above the shelf. The wider drag
                // approach zone would otherwise steal clicks from the tabs.
                frame.origin.x = frame.midX - 45
                frame.origin.y = frame.maxY - 22
                frame.size = NSSize(width: 90, height: 22)
            }
            target.panel.setFrame(frame, display: true)
            target.panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
            target.panel.orderFrontRegardless()
        }
    }

    private func expandedFrame(on screen: NSScreen, itemCount: Int) -> NSRect {
        let anchor = notchFrame(on: screen).map { $0.minY + 3 } ?? screen.visibleFrame.maxY
        return NotchLayout.expandedFrame(visibleFrame: screen.visibleFrame, anchorMaxY: anchor, itemCount: itemCount)
    }

    private func collapsedShelfFrame(on screen: NSScreen) -> NSRect {
        NotchLayout.collapsedShelfFrame(targetFrame: targetFrame(on: screen), notchFrame: notchFrame(on: screen))
    }

    private func notchFrame(on screen: NSScreen) -> NSRect? {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              right.minX > left.maxX else { return nil }
        return NSRect(x: left.maxX, y: min(left.minY, right.minY), width: right.minX - left.maxX, height: max(left.height, right.height))
    }

    private func motionDuration(animated: Bool) -> TimeInterval {
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return 0 }
        return preferences.animationIntensity.duration
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}

private final class NotchTargetPanel {
    let panel: NSPanel
    let view: NotchDropTargetView
    weak var screen: NSScreen?
    init(panel: NSPanel, view: NotchDropTargetView, screen: NSScreen) { self.panel = panel; self.view = view; self.screen = screen }
}

private final class NotchDropTargetView: NSView {
    var onToggle: (() -> Void)?
    var isShelfOpen = false { didSet { needsDisplay = true; setAccessibilityLabel(isShelfOpen ? "Close notch shelf" : "Open notch shelf") } }
    private var hovered = false { didSet { needsDisplay = true } }
    private var hoverTracking: NSTrackingArea?
    var onDrop: ((NotchDropPayload, Int) -> Bool)?
    var onDragValidityChange: ((Bool) -> Void)?
    private let hasHardwareNotch: Bool
    private enum State: Equatable { case idle, valid, invalid }
    private var state: State = .idle { didSet { needsDisplay = true } }
    private var deduplicator = NotchDropDeduplicator()

    init(frame frameRect: NSRect, hasHardwareNotch: Bool) {
        self.hasHardwareNotch = hasHardwareNotch
        super.init(frame: frameRect)
        wantsLayer = true
        registerForDraggedTypes([.fileURL, .URL, .string])
        setAccessibilityLabel("Stash top-center drop target")
        setAccessibilityRole(.button)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverTracking = area
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    private var buttonFrame: NSRect { NSRect(x: bounds.midX - 45, y: bounds.maxY - 22, width: 90, height: 20) }

    override func mouseDown(with event: NSEvent) {
        guard buttonFrame.contains(convert(event.locationInWindow, from: nil)) else { return }
        onToggle?()
    }
    override func accessibilityPerformPress() -> Bool { onToggle?(); return true }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        if hovered || isShelfOpen {
            let button = buttonFrame
            NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
            NSBezierPath(roundedRect: button, xRadius: 10, yRadius: 10).fill()
            let title = isShelfOpen ? "Close Stash" : "Open Stash"
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.labelColor]
            let size = (title as NSString).size(withAttributes: attributes)
            (title as NSString).draw(at: NSPoint(x: button.midX - size.width / 2, y: button.midY - size.height / 2), withAttributes: attributes)
            return
        }
        // On notched Macs the real feedback is the shelf unfolding from the
        // notch. Keeping this trigger fully transparent avoids a second bar.
        if hasHardwareNotch { return }
        let targetBounds: NSRect
        if hasHardwareNotch { targetBounds = bounds.insetBy(dx: 0, dy: 0) }
        else { targetBounds = NSRect(x: bounds.midX - 28, y: bounds.midY - 3, width: 56, height: 6) }
        let capsule = NSBezierPath(roundedRect: targetBounds, xRadius: hasHardwareNotch ? 13 : 3, yRadius: hasHardwareNotch ? 13 : 3)
        let color: NSColor
        switch state {
        case .idle: color = .labelColor.withAlphaComponent(0.22)
        case .valid: color = hasHardwareNotch ? .black.withAlphaComponent(0.96) : .controlAccentColor.withAlphaComponent(0.92)
        case .invalid: color = .systemRed.withAlphaComponent(0.72)
        }
        color.setFill(); capsule.fill()
        if state != .idle { (state == .valid ? NSColor.controlAccentColor : NSColor.white).withAlphaComponent(0.72).setStroke(); capsule.lineWidth = 1.5; capsule.stroke() }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { updateDragState(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { updateDragState(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { state = .idle; onDragValidityChange?(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { payload(from: sender.draggingPasteboard) != nil }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { state = .idle }
        guard let payload = payload(from: sender.draggingPasteboard), deduplicator.shouldAccept(sequence: sender.draggingSequenceNumber, payload: payload) else { return false }
        return onDrop?(payload, sender.draggingSequenceNumber) ?? false
    }

    private func updateDragState(_ sender: NSDraggingInfo) -> NSDragOperation {
        let valid = payload(from: sender.draggingPasteboard) != nil
        let nextState: State = valid ? .valid : .invalid
        if state != nextState { state = nextState; onDragValidityChange?(valid) }
        return valid ? .copy : []
    }

    private func payload(from pasteboard: NSPasteboard) -> NotchDropPayload? {
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let fileURLs = (pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) ?? []).compactMap { ($0 as? NSURL).map { $0 as URL } }
        if !fileURLs.isEmpty { return NotchDropPayload(items: fileURLs.map(ShelfItem.init(fileURL:))) }
        if let rawURL = pasteboard.string(forType: .URL), let url = URL(string: rawURL), url.scheme != nil { return NotchDropPayload(items: [ShelfItem(text: url.absoluteString, isURL: true)]) }
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return NotchDropPayload(items: [ShelfItem(text: text)]) }
        return nil
    }
}
