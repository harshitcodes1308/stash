import AppKit
import Foundation
import PDFKit

@main
struct PDFActionHarness {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("stash-pdf-harness-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let first = root.appendingPathComponent("first.pdf")
        let second = root.appendingPathComponent("second.pdf")
        let third = root.appendingPathComponent("third.pdf")
        try makePDF(at: first, pages: [(NSSize(width: 200, height: 300), 0), (NSSize(width: 210, height: 310), 90)])
        try makePDF(at: second, pages: [(NSSize(width: 400, height: 500), 180)])
        try makePDF(at: third, pages: [(NSSize(width: 600, height: 700), 270)])
        let originalBytes = try Data(contentsOf: first)
        let storeRoot = root.appendingPathComponent("generated", isDirectory: true)
        let service = PDFActionService(store: GeneratedFileStore(root: storeRoot))
        let result = try await service.run(inputs: [first, second, third], request: PDFMergeRequest(outputName: "Merged Document"))
        try require(result.pageCount == 4, "Expected four merged pages")
        try verifyPages(result.output, expected: [(200, 300, 0), (210, 310, 90), (400, 500, 180), (600, 700, 270)])
        try require(try Data(contentsOf: first) == originalBytes, "Source PDF bytes changed")
        let manifest = try JSONDecoder().decode([String].self, from: Data(contentsOf: storeRoot.appendingPathComponent("owned-files.json")))
        try require(manifest.contains(result.output.path), "Generated PDF was not retained")

        let reversed = try await service.run(inputs: [third, second, first], request: PDFMergeRequest(outputName: "Merged Document"))
        try require(reversed.output != result.output, "Output collision was not resolved")
        try verifyPages(reversed.output, expected: [(600, 700, 270), (400, 500, 180), (200, 300, 0), (210, 310, 90)])
        let export = root.appendingPathComponent("export", isDirectory: true); try FileManager.default.createDirectory(at: export, withIntermediateDirectories: true)
        let exported = export.appendingPathComponent("Merged Document.pdf")
        try FileManager.default.copyItem(at: result.output, to: exported)
        try verifyPages(exported, expected: [(200, 300, 0), (210, 310, 90), (400, 500, 180), (600, 700, 270)])

        let corrupt = root.appendingPathComponent("corrupt.pdf"); try Data("not-a-pdf".utf8).write(to: corrupt)
        try await expectError({ _ = try await service.run(inputs: [first, corrupt], request: PDFMergeRequest(outputName: "bad")) }, contains: "could not be opened")
        try await expectError({ _ = try await service.run(inputs: [first, root.appendingPathComponent("missing.pdf")], request: PDFMergeRequest(outputName: "missing")) }, contains: "no longer available")

        let locked = root.appendingPathComponent("locked.pdf")
        let lockingDocument = try requireDocument(first)
        try require(lockingDocument.write(to: locked, withOptions: [.userPasswordOption: "secret"]), "Could not create encrypted fixture")
        if PDFDocument(url: locked)?.isLocked == true {
            try await expectError({ _ = try await service.run(inputs: [first, locked], request: PDFMergeRequest(outputName: "locked")) }, contains: "password protected")
        }

        let selection = [ShelfItem(fileURL: first), ShelfItem(fileURL: second)]
        try require(ActionRegistry().actions(for: selection).contains(where: { $0.id == .mergePDFs }), "Merge PDFs action was not registered for two valid PDFs")
        try require(!ActionRegistry().actions(for: [ShelfItem(fileURL: first)]).contains(where: { $0.id == .mergePDFs }), "Merge PDFs appeared for one PDF")
        let restored = try JSONDecoder().decode(Shelf.self, from: JSONEncoder().encode(Shelf(items: [ShelfItem(fileURL: result.output)], isPinned: true)))
        try require(restored.items.first?.fileURL == result.output, "Pinned shelf PDF reference was not codable")
        print("PASS: PDF merge order, pages, dimensions, rotation, source preservation, invalid/missing/locked rejection, retention, collision-safe output, export, action applicability, and shelf persistence")
    }

    static func makePDF(at url: URL, pages: [(NSSize, Int)]) throws {
        let document = PDFDocument()
        for (size, rotation) in pages {
            let image = NSImage(size: size)
            image.lockFocus(); NSColor.white.setFill(); NSRect(origin: .zero, size: size).fill(); image.unlockFocus()
            guard let page = PDFPage(image: image) else { throw HarnessError("Could not create PDF page") }
            page.rotation = rotation; document.insert(page, at: document.pageCount)
        }
        guard document.write(to: url) else { throw HarnessError("Could not write PDF fixture") }
    }

    static func verifyPages(_ url: URL, expected: [(CGFloat, CGFloat, Int)]) throws {
        let document = try requireDocument(url)
        try require(document.pageCount == expected.count, "Unexpected page count in \(url.lastPathComponent)")
        for (index, item) in expected.enumerated() {
            guard let page = document.page(at: index) else { throw HarnessError("Missing page \(index)") }
            let box = page.bounds(for: .mediaBox)
            try require(abs(box.width - item.0) < 1 && abs(box.height - item.1) < 1 && page.rotation == item.2, "Page sequence mismatch at \(index): \(box), rotation \(page.rotation)")
        }
    }

    static func requireDocument(_ url: URL) throws -> PDFDocument { guard let document = PDFDocument(url: url) else { throw HarnessError("Could not open \(url.lastPathComponent)") }; return document }
    static func expectError(_ work: () async throws -> Void, contains text: String) async throws {
        do { try await work() }
        catch { try require(error.localizedDescription.localizedCaseInsensitiveContains(text), "Unexpected error: \(error.localizedDescription)"); return }
        throw HarnessError("Expected failure containing \(text)")
    }
    static func require(_ condition: Bool, _ message: String) throws { if !condition { throw HarnessError(message) } }
}

struct HarnessError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
