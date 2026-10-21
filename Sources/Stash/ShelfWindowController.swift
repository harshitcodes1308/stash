import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ShelfWindowController: NSWindowController, ObservableObject, NSWindowDelegate {
    @Published var shelf: Shelf
    private let store: ShelfStore
    private weak var coordinator: ShelfCoordinator?
    private let actionRegistry = ActionRegistry()
    private let generatedFileStore = GeneratedFileStore()
    private lazy var imageService = ImageActionService(store: generatedFileStore)
    private lazy var archiveService = ArchiveActionService(store: generatedFileStore)
    private lazy var pdfService = PDFActionService(store: generatedFileStore)
    private let renameService = RenameActionService()
    private var hasInitialPosition = false
    @Published var isPerformingAction = false
    @Published var actionMessage: String?

    init(shelf: Shelf, store: ShelfStore, coordinator: ShelfCoordinator) {
        self.shelf = shelf; self.store = store; self.coordinator = coordinator
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 330, height: 260), styleMask: [.titled, .closable, .fullSizeContentView, .resizable], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true; panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: panel)
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ShelfView(controller: self))
        panel.minSize = NSSize(width: 330, height: 230)
        if let savedFrame = store.frame(for: shelf) {
            panel.setFrame(clampedFrame(savedFrame), display: true)
            hasInitialPosition = true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func windowWillLoad() {}

    func show(at point: NSPoint? = nil) {
        if !hasInitialPosition, let screen = screenForInitialPosition() {
            let frame = window!.frame; let origin = point ?? NSPoint(x: screen.visibleFrame.midX - frame.width / 2, y: screen.visibleFrame.midY - frame.height / 2)
            window?.setFrameOrigin(origin)
            hasInitialPosition = true
        }
        showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func togglePin() { shelf.isPinned.toggle(); persistIfNeeded(); if shelf.isPinned, let frame = window?.frame { store.saveFrame(frame, for: shelf) } }
    func persistIfNeeded() { store.save(shelf) }
    func remove(_ item: ShelfItem) { shelf.items.removeAll { $0.id == item.id }; persistIfNeeded() }
    func clear() { shelf.items.removeAll(); persistIfNeeded() }
    func dismiss() { store.remove(shelf.id); close() }

    func acceptDrop(providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true; provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                    guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in self?.append(ShelfItem(fileURL: url)) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                accepted = true; provider.loadObject(ofClass: NSURL.self) { [weak self] object, _ in
                    guard let nsURL = object as? NSURL else { return }; let url = nsURL as URL; Task { @MainActor in self?.append(ShelfItem(text: url.absoluteString, isURL: true)) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
                accepted = true; provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
                    guard let source = object as? NSString else { return }
                    let text = String(source)
                    Task { @MainActor in self?.append(ShelfItem(text: text)) }
                }
            }
        }
        return accepted
    }
    private func append(_ item: ShelfItem) { guard !shelf.items.contains(where: { $0.kind == item.kind && $0.value == item.value }) else { return }; shelf.items.append(item); persistIfNeeded() }
    func appendFiles(_ urls: [URL]) { urls.forEach { append(ShelfItem(fileURL: $0)) } }
    func availableActions(for selectedIDs: Set<UUID>) -> [ActionDescriptor] { actionRegistry.actions(for: shelf.items.filter { selectedIDs.contains($0.id) }) }

    func performImageAction(selectedIDs: Set<UUID>, request: ImageActionRequest, destination: OutputDestination) {
        let inputs = shelf.items.filter { selectedIDs.contains($0.id) }.compactMap(\.fileURL)
        guard !inputs.isEmpty else { return }
        let exportDirectory = destination == .exportFolder ? chooseExportFolder() : nil
        guard destination != .exportFolder || exportDirectory != nil else { return }
        isPerformingAction = true; actionMessage = nil
        Task { [weak self] in
            guard let self else { return }
            let result = await imageService.run(inputs: inputs, request: request)
            await MainActor.run {
                self.isPerformingAction = false
                if let exportDirectory { self.export(result.outputs, to: exportDirectory) }
                else if destination == .newShelf { self.coordinator?.newShelf(with: result.outputs) }
                else { self.appendFiles(result.outputs) }
                self.actionMessage = result.failures.isEmpty ? "Created \(result.outputs.count) image\(result.outputs.count == 1 ? "" : "s")." : result.failures.joined(separator: "\n")
            }
        }
    }

    func performArchiveAction(selectedIDs: Set<UUID>, request: ArchiveRequest, destination: OutputDestination) {
        let inputs = shelf.items.filter { selectedIDs.contains($0.id) }.compactMap(\.fileURL)
        guard !inputs.isEmpty else { return }
        let exportDirectory = destination == .exportFolder ? chooseExportFolder() : nil
        guard destination != .exportFolder || exportDirectory != nil else { return }
        isPerformingAction = true; actionMessage = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await archiveService.run(inputs: inputs, request: request)
                await MainActor.run {
                    self.isPerformingAction = false
                    if let exportDirectory { self.export([result.output], to: exportDirectory) }
                    else if destination == .newShelf { self.coordinator?.newShelf(with: [result.output]) }
                    else { self.appendFiles([result.output]) }
                    self.actionMessage = "Created ZIP with \(result.entries.count) entries."
                }
            } catch {
                await MainActor.run { self.isPerformingAction = false; self.actionMessage = error.localizedDescription }
            }
        }
    }

    func renamePlan(selectedIDs: Set<UUID>, configuration: RenameConfiguration) -> RenamePlan {
        renameService.plan(inputs: shelf.items.filter { selectedIDs.contains($0.id) }.compactMap(\.fileURL), configuration: configuration)
    }

    func performRenameAction(selectedIDs: Set<UUID>, configuration: RenameConfiguration) {
        let inputs = shelf.items.filter { selectedIDs.contains($0.id) }.compactMap(\.fileURL)
        guard !inputs.isEmpty else { return }
        isPerformingAction = true; actionMessage = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await renameService.execute(inputs: inputs, configuration: configuration)
                await self.generatedFileStore.updateReferences(afterRenaming: result.renamed)
                await MainActor.run {
                    self.isPerformingAction = false
                    self.coordinator?.updateReferences(afterRenaming: result.renamed)
                    self.actionMessage = result.renamed.isEmpty ? "No filenames changed." : "Renamed \(result.renamed.count) item\(result.renamed.count == 1 ? "" : "s")."
                }
            } catch {
                await MainActor.run { self.isPerformingAction = false; self.actionMessage = error.localizedDescription }
            }
        }
    }

    func pdfInputs(selectedIDs: Set<UUID>) -> [PDFInputInfo] {
        pdfService.inspect(shelf.items.filter { selectedIDs.contains($0.id) }.compactMap(\.fileURL))
    }

    func performPDFMerge(orderedInputs: [URL], request: PDFMergeRequest, destination: OutputDestination) {
        guard orderedInputs.count >= 2 else { return }
        let exportDirectory = destination == .exportFolder ? chooseExportFolder() : nil
        guard destination != .exportFolder || exportDirectory != nil else { return }
        isPerformingAction = true; actionMessage = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await pdfService.run(inputs: orderedInputs, request: request)
                await MainActor.run {
                    self.isPerformingAction = false
                    if let exportDirectory { self.export([result.output], to: exportDirectory) }
                    else if destination == .newShelf { self.coordinator?.newShelf(with: [result.output]) }
                    else { self.appendFiles([result.output]) }
                    self.actionMessage = "Merged \(result.pageCount) PDF page\(result.pageCount == 1 ? "" : "s")."
                }
            } catch {
                await MainActor.run { self.isPerformingAction = false; self.actionMessage = error.localizedDescription }
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) { coordinator?.didFocus(self) }
    func windowDidMove(_ notification: Notification) { persistFrameIfPinned() }
    func windowDidResize(_ notification: Notification) { persistFrameIfPinned() }
    func windowWillClose(_ notification: Notification) { coordinator?.didDismiss(self) }

    private func screenForInitialPosition() -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
    }

    private func persistFrameIfPinned() { if shelf.isPinned, let frame = window?.frame { store.saveFrame(frame, for: shelf) } }

    private func clampedFrame(_ frame: NSRect) -> NSRect {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) ?? NSScreen.main else { return frame }
        let visible = screen.visibleFrame
        let width = min(max(frame.width, window?.minSize.width ?? 330), visible.width)
        let height = min(max(frame.height, window?.minSize.height ?? 230), visible.height)
        let x = min(max(frame.origin.x, visible.minX), visible.maxX - width)
        let y = min(max(frame.origin.y, visible.minY), visible.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func chooseExportFolder() -> URL? {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.prompt = "Export"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func export(_ urls: [URL], to directory: URL) {
        var errors: [String] = []
        for url in urls {
            var target = directory.appendingPathComponent(url.lastPathComponent); var suffix = 2
            while FileManager.default.fileExists(atPath: target.path) { target = directory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(suffix)").appendingPathExtension(url.pathExtension); suffix += 1 }
            do { try FileManager.default.copyItem(at: url, to: target) } catch { errors.append(error.localizedDescription) }
        }
        if !errors.isEmpty { actionMessage = errors.joined(separator: "\n") }
    }
}

@MainActor
final class ShelfCoordinator {
    let store: ShelfStore
    private var controllers: [ShelfWindowController] = []
    private var currentController: ShelfWindowController?
    init(store: ShelfStore) { self.store = store }
    func newShelf() { let controller = ShelfWindowController(shelf: Shelf(), store: store, coordinator: self); controllers.append(controller); currentController = controller; controller.show() }
    func newShelf(with urls: [URL]) { let controller = ShelfWindowController(shelf: Shelf(items: urls.map(ShelfItem.init(fileURL:))), store: store, coordinator: self); controllers.append(controller); currentController = controller; controller.show() }
    func restorePinnedShelves() { for shelf in store.pinnedShelves { let controller = ShelfWindowController(shelf: shelf, store: store, coordinator: self); controllers.append(controller); currentController = controller; controller.show() } }
    func showCurrentShelf() { currentController?.show() }
    func didFocus(_ controller: ShelfWindowController) { currentController = controller }
    func showPinned(_ shelf: Shelf) { if let existing = controllers.first(where: { $0.shelf.id == shelf.id }) { currentController = existing; existing.show() } else { let controller = ShelfWindowController(shelf: shelf, store: store, coordinator: self); controllers.append(controller); currentController = controller; controller.show() } }
    func didDismiss(_ controller: ShelfWindowController) { controllers.removeAll { $0 === controller }; if currentController === controller { currentController = controllers.last } }
    func updateReferences(afterRenaming renamed: [URL: URL]) {
        for controller in controllers {
            controller.shelf.items = controller.shelf.items.map { item in
                guard let url = item.fileURL else { return item }
                for (old, new) in renamed {
                    if url.standardizedFileURL == old.standardizedFileURL { return item.updatingFileURL(new) }
                    let oldPath = old.standardizedFileURL.path
                    let prefix = oldPath.hasSuffix("/") ? oldPath : oldPath + "/"
                    if url.standardizedFileURL.path.hasPrefix(prefix) {
                        let suffix = String(url.standardizedFileURL.path.dropFirst(prefix.count))
                        return item.updatingFileURL(new.appendingPathComponent(suffix))
                    }
                }
                return item
            }
            controller.persistIfNeeded()
        }
    }
}
