import Foundation
import CoreGraphics
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case file, text, url }

    let id: UUID
    let kind: Kind
    let value: String
    let displayName: String
    let createdAt: Date

    init(fileURL: URL) {
        id = UUID(); kind = .file; value = fileURL.absoluteString
        displayName = fileURL.lastPathComponent; createdAt = Date()
    }

    init(text: String, isURL: Bool = false) {
        id = UUID(); kind = isURL ? .url : .text; value = text
        displayName = isURL ? text : String(text.prefix(80)); createdAt = Date()
    }

    func updatingFileURL(_ url: URL) -> ShelfItem {
        ShelfItem(id: id, kind: kind, value: url.absoluteString, displayName: url.lastPathComponent, createdAt: createdAt)
    }

    private init(id: UUID, kind: Kind, value: String, displayName: String, createdAt: Date) {
        self.id = id; self.kind = kind; self.value = value; self.displayName = displayName; self.createdAt = createdAt
    }

    var fileURL: URL? { kind == .file ? URL(string: value) : nil }
    var isAvailable: Bool { fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? true }
    var symbolName: String {
        switch kind { case .file: return "doc"; case .text: return "text.alignleft"; case .url: return "link" }
    }
}

struct Shelf: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var items: [ShelfItem]
    var isPinned: Bool
    var createdAt: Date

    init(title: String = "New Shelf", items: [ShelfItem] = [], isPinned: Bool = false) {
        id = UUID(); self.title = title; self.items = items; self.isPinned = isPinned; createdAt = Date()
    }
}

struct ShelfFrame: Codable, Hashable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    init(_ frame: CGRect) { x = frame.origin.x; y = frame.origin.y; width = frame.size.width; height = frame.size.height }
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var pinnedShelves: [Shelf] = []
    private let key = "stash.pinned-shelves.v1"
    private let frameKey = "stash.pinned-shelf-frames.v1"
    private var pinnedFrames: [UUID: ShelfFrame] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults; load() }

    func save(_ shelf: Shelf) {
        guard shelf.isPinned else { remove(shelf.id); return }
        if let index = pinnedShelves.firstIndex(where: { $0.id == shelf.id }) { pinnedShelves[index] = shelf }
        else { pinnedShelves.append(shelf) }
        persist()
    }

    func remove(_ id: UUID) { pinnedShelves.removeAll { $0.id == id }; pinnedFrames[id] = nil; persist() }

    func saveFrame(_ frame: CGRect, for shelf: Shelf) {
        guard shelf.isPinned else { return }
        pinnedFrames[shelf.id] = ShelfFrame(frame)
        persist()
    }

    func frame(for shelf: Shelf) -> CGRect? { pinnedFrames[shelf.id]?.rect }

    private func load() {
        guard let data = defaults.data(forKey: key), let shelves = try? JSONDecoder().decode([Shelf].self, from: data) else { return }
        pinnedShelves = shelves
        if let frameData = defaults.data(forKey: frameKey), let frames = try? JSONDecoder().decode([UUID: ShelfFrame].self, from: frameData) { pinnedFrames = frames }
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(pinnedShelves), forKey: key)
        defaults.set(try? JSONEncoder().encode(pinnedFrames), forKey: frameKey)
    }
}
