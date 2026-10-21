import Foundation
import ImageIO
import UniformTypeIdentifiers
import PDFKit

enum SmartActionID: String, CaseIterable, Identifiable {
    case convertImages, resizeImages, createZip, batchRename, mergePDFs
    var id: String { rawValue }
}

struct ActionDescriptor: Identifiable {
    let id: SmartActionID
    let title: String
    let systemImage: String
    let minimumSelectionCount: Int
}

struct ActionContext {
    let items: [ShelfItem]
    var fileURLs: [URL] { items.compactMap(\.fileURL) }

    func allFilesAreImages() -> Bool {
        !fileURLs.isEmpty && fileURLs.count == items.count && fileURLs.allSatisfy { url in
            guard FileManager.default.isReadableFile(atPath: url.path), let type = contentType(for: url) else { return false }
            return type.conforms(to: .image)
        }
    }

    func allItemsAreExistingFileReferences() -> Bool {
        !fileURLs.isEmpty && fileURLs.count == items.count && fileURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }

    func allFilesAreMergeablePDFs() -> Bool {
        !fileURLs.isEmpty && fileURLs.count == items.count && fileURLs.allSatisfy { url in
            guard FileManager.default.isReadableFile(atPath: url.path), let type = contentType(for: url), type.conforms(to: .pdf),
                  let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else { return false }
            return true
        }
    }

    private func contentType(for url: URL) -> UTType? {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType { return type }
        return UTType(filenameExtension: url.pathExtension)
    }
}

struct ActionRegistry {
    static let imageActions = [
        ActionDescriptor(id: .convertImages, title: "Convert Images", systemImage: "arrow.triangle.2.circlepath", minimumSelectionCount: 1),
        ActionDescriptor(id: .resizeImages, title: "Resize Images", systemImage: "arrow.down.right.and.arrow.up.left", minimumSelectionCount: 1)
    ]
    static let archiveAction = ActionDescriptor(id: .createZip, title: "Create ZIP", systemImage: "archivebox", minimumSelectionCount: 1)
    static let renameAction = ActionDescriptor(id: .batchRename, title: "Batch Rename", systemImage: "pencil.line", minimumSelectionCount: 1)
    static let mergePDFAction = ActionDescriptor(id: .mergePDFs, title: "Merge PDFs", systemImage: "doc.on.doc", minimumSelectionCount: 2)

    func actions(for items: [ShelfItem]) -> [ActionDescriptor] {
        let context = ActionContext(items: items)
        var result: [ActionDescriptor] = []
        if context.allFilesAreImages() { result += Self.imageActions.filter { items.count >= $0.minimumSelectionCount } }
        if context.allItemsAreExistingFileReferences() {
            result.append(Self.archiveAction)
            result.append(Self.renameAction)
        }
        if items.count >= Self.mergePDFAction.minimumSelectionCount, context.allFilesAreMergeablePDFs() { result.append(Self.mergePDFAction) }
        return result
    }
}

enum OutputDestination: String, CaseIterable, Identifiable {
    case currentShelf, newShelf, exportFolder
    var id: String { rawValue }
    var title: String {
        switch self { case .currentShelf: return "Current shelf"; case .newShelf: return "New shelf"; case .exportFolder: return "Choose folder…" }
    }
}
