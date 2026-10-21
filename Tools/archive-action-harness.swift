import Foundation

@main
struct ArchiveActionHarness {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("stash-archive-harness-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input", isDirectory: true)
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        let documents = input.appendingPathComponent("Documents", isDirectory: true)
        let nested = documents.appendingPathComponent("nested", isDirectory: true)
        let empty = documents.appendingPathComponent("empty", isDirectory: true)
        let one = input.appendingPathComponent("one", isDirectory: true)
        let two = input.appendingPathComponent("two", isDirectory: true)
        for directory in [nested, empty, one, two] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        let report = documents.appendingPathComponent("report with spaces.txt")
        let unicode = input.appendingPathComponent("café.txt")
        let sameOne = one.appendingPathComponent("same.txt")
        let sameTwo = two.appendingPathComponent("same.txt")
        for (url, text) in [(report, "report"), (nested.appendingPathComponent("note.txt"), "nested"), (unicode, "unicode"), (sameOne, "one"), (sameTwo, "two")] { try Data(text.utf8).write(to: url) }

        let service = ArchiveActionService(store: GeneratedFileStore(root: root.appendingPathComponent("generated", isDirectory: true)))
        let result = try await service.run(inputs: [documents, unicode, sameOne, sameTwo], request: ArchiveRequest(archiveName: "deliverables", omitSingleTopLevelFolder: false))
        let joined = result.entries.joined(separator: "\n")
        try require(joined.contains("Documents/") && joined.contains("Documents/empty/") && joined.contains("Documents/nested/note.txt") && joined.precomposedStringWithCanonicalMapping.contains("café.txt") && joined.contains("same.txt") && joined.contains("same-2.txt"), "Archive did not preserve expected hierarchy: \(joined)")
        try require((try String(contentsOf: report, encoding: .utf8)) == "report", "Source file was modified")

        let second = try await service.run(inputs: [documents], request: ArchiveRequest(archiveName: "deliverables", omitSingleTopLevelFolder: false))
        try require(result.output != second.output, "Output collision was not resolved")
        do { _ = try await service.run(inputs: [input.appendingPathComponent("missing.txt")], request: ArchiveRequest(archiveName: "missing", omitSingleTopLevelFolder: false)); throw HarnessError("Missing input unexpectedly succeeded") } catch let error as ArchiveActionError { try require(error.localizedDescription.contains("no longer available"), "Wrong missing-file error") }

        let link = input.appendingPathComponent("unsafe-link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: report.path)
        do { _ = try await service.run(inputs: [link], request: ArchiveRequest(archiveName: "unsafe", omitSingleTopLevelFolder: false)); throw HarnessError("Symlink unexpectedly succeeded") } catch let error as ArchiveActionError { try require(error.localizedDescription.contains("symbolic links"), "Wrong symlink error") }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let managedOutput = library.appendingPathComponent("Application Support/Stash/Generated Outputs", isDirectory: true)
        let exportFolder = root.appendingPathComponent("export", isDirectory: true)
        for directory in [downloads, managedOutput, exportFolder] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        let selectedA = downloads.appendingPathComponent("first.png"); let selectedB = downloads.appendingPathComponent("second.png")
        let unrelated = library.appendingPathComponent("unrelated.txt")
        let oldOutput = managedOutput.appendingPathComponent("old-output.zip")
        for (url, text) in [(selectedA, "a"), (selectedB, "b"), (unrelated, "unrelated"), (oldOutput, "old")] { try Data(text.utf8).write(to: url) }
        let libraryService = ArchiveActionService(store: GeneratedFileStore(root: managedOutput))
        let downloadsResult = try await libraryService.run(inputs: [selectedA, selectedB], request: ArchiveRequest(archiveName: "downloads-only", omitSingleTopLevelFolder: false))
        let expectedEntries = ["first.png", "second.png"]
        try require(downloadsResult.entries.sorted() == expectedEntries, "Unexpected Downloads archive entries: \(downloadsResult.entries)")
        try require(!downloadsResult.entries.joined(separator: "\n").contains("Library") && !downloadsResult.entries.joined(separator: "\n").contains("unrelated") && !downloadsResult.entries.joined(separator: "\n").contains("old-output"), "Archive leaked unrelated Library or managed-output content")
        let exported = exportFolder.appendingPathComponent("downloads-only.zip")
        try FileManager.default.copyItem(at: downloadsResult.output, to: exported)
        let exportedEntries = try await libraryService.run(inputs: [exported], request: ArchiveRequest(archiveName: "export-validation", omitSingleTopLevelFolder: false)).entries
        try require(exportedEntries == ["downloads-only.zip"], "Exported ZIP could not be re-archived as a shelf/new-shelf reference")
        print("PASS: ZIP files/folders, nesting, empty folders, Unicode, collision names, source preservation, verification, missing-file and symlink handling; Downloads-only archive excluded Library and managed output")
    }

    static func require(_ condition: Bool, _ message: String) throws { if !condition { throw HarnessError(message) } }
}

struct HarnessError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
