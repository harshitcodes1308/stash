import Foundation

@main
struct ActionEngineHarness {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("stash-action-harness-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let image = directory.appendingPathComponent("photo.png")
        try Data([0]).write(to: image)
        let registry = ActionRegistry()
        guard registry.actions(for: [ShelfItem(fileURL: image)]).map(\.id) == [.convertImages, .resizeImages, .createZip, .batchRename] else { throw HarnessError("Image selection did not offer all applicable actions") }
        let generic = directory.appendingPathComponent("document.bin")
        try Data([1]).write(to: generic)
        guard registry.actions(for: [ShelfItem(fileURL: generic)]).map(\.id) == [.createZip, .batchRename] else { throw HarnessError("Generic file selection did not offer ZIP and rename") }
        guard registry.actions(for: [ShelfItem(text: "notes")]).isEmpty else { throw HarnessError("Text selection incorrectly offered file actions") }
        let suiteName = "stash-store-harness-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { throw HarnessError("Could not create isolated preferences") }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var pinned = Shelf(title: "Pinned", isPinned: true)
        let store = ShelfStore(defaults: defaults)
        store.save(pinned)
        let frame = CGRect(x: 42, y: 43, width: 330, height: 260)
        store.saveFrame(frame, for: pinned)
        let restored = ShelfStore(defaults: defaults)
        guard restored.pinnedShelves == [pinned], restored.frame(for: pinned) == frame else { throw HarnessError("Pinned shelf frame was not persisted") }
        pinned.isPinned = false
        restored.save(pinned)
        guard restored.pinnedShelves.isEmpty, restored.frame(for: pinned) == nil else { throw HarnessError("Unpinned shelf state was not removed") }
        print("PASS: action applicability is selection-aware")
    }
}

struct HarnessError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
