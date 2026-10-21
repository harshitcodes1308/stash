import Foundation
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

@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var pinnedShelves: [Shelf] = []
    private let key = "stash.pinned-shelves.v1"

    init() { load() }

    func save(_ shelf: Shelf) {
        guard shelf.isPinned else { remove(shelf.id); return }
        if let index = pinnedShelves.firstIndex(where: { $0.id == shelf.id }) { pinnedShelves[index] = shelf }
        else { pinnedShelves.append(shelf) }
        persist()
    }

    func remove(_ id: UUID) { pinnedShelves.removeAll { $0.id == id }; persist() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key), let shelves = try? JSONDecoder().decode([Shelf].self, from: data) else { return }
        pinnedShelves = shelves
    }

    private func persist() { UserDefaults.standard.set(try? JSONEncoder().encode(pinnedShelves), forKey: key) }
}
