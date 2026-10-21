import Foundation

@main
struct RenameActionHarness {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("stash-rename-harness-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let one = root.appendingPathComponent("one", isDirectory: true)
        let two = root.appendingPathComponent("two", isDirectory: true)
        try FileManager.default.createDirectory(at: one, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: two, withIntermediateDirectories: true)
        let photo = one.appendingPathComponent("Photo.PNG")
        let screenshot = one.appendingPathComponent("Screenshot 2026.png")
        let unicode = two.appendingPathComponent("café.txt")
        for (url, contents) in [(photo, "photo"), (screenshot, "screen"), (unicode, "unicode")] { try Data(contents.utf8).write(to: url) }

        let service = RenameActionService()
        let configured = RenameConfiguration(prefix: "project-", suffix: "-final", find: "photo", replace: "image", caseSensitive: false, sequentialNumbering: true, startingNumber: 7, increment: 3, zeroPadding: 3, numberSeparator: "-")
        let preview = service.plan(inputs: [photo, screenshot, unicode], configuration: configured)
        try require(preview.isValid, "Expected valid preview: \(preview.errors)")
        try require(preview.entries.map(\.proposedName) == ["project-image-final-007.PNG", "project-Screenshot 2026-final-010.png", "project-café-final-013.txt"], "Prefix/suffix/replace/sequence/extension preview was wrong")
        let actual = try await service.execute(inputs: [photo, screenshot, unicode], configuration: configured)
        try require(actual.renamed.count == 3, "Expected three renamed items")
        let renamedPhoto = one.appendingPathComponent("project-image-final-007.PNG")
        try require((try String(contentsOf: renamedPhoto, encoding: .utf8)) == "photo", "Rename changed file contents")

        let collision = root.appendingPathComponent("taken.txt")
        let source = root.appendingPathComponent("source.txt")
        try Data("taken".utf8).write(to: collision); try Data("source".utf8).write(to: source)
        let collisionPlan = service.plan(inputs: [source], configuration: RenameConfiguration(find: "source", replace: "taken", caseSensitive: true))
        try require(!collisionPlan.isValid && collisionPlan.errors.joined().contains("already exists"), "Existing destination collision was not blocked")
        try require(FileManager.default.fileExists(atPath: source.path), "Invalid plan changed a source")

        let duplicateA = root.appendingPathComponent("A.txt"); let duplicateB = root.appendingPathComponent("a.txt")
        try Data("A".utf8).write(to: duplicateA)
        if !FileManager.default.fileExists(atPath: duplicateB.path) { try Data("a".utf8).write(to: duplicateB) }
        let duplicatePlan = service.plan(inputs: [duplicateA, duplicateB], configuration: RenameConfiguration(prefix: "same-"))
        try require(!duplicatePlan.isValid, "Case/Unicode-safe duplicate destination was not blocked")

        let caseOnly = root.appendingPathComponent("case.txt"); try Data("case".utf8).write(to: caseOnly)
        _ = try await service.execute(inputs: [caseOnly], configuration: RenameConfiguration(find: "case", replace: "CASE", caseSensitive: true))
        try require(FileManager.default.fileExists(atPath: root.appendingPathComponent("CASE.txt").path), "Case-only rename failed")

        let swapA = root.appendingPathComponent("swap-a.txt"); let swapB = root.appendingPathComponent("swap-b.txt")
        try Data("A".utf8).write(to: swapA); try Data("B".utf8).write(to: swapB)
        let swapPlan = RenamePlan(entries: [
            RenamePlanEntry(source: swapA, destination: swapB, originalName: "swap-a.txt", proposedName: "swap-b.txt", isDirectory: false, error: nil),
            RenamePlanEntry(source: swapB, destination: swapA, originalName: "swap-b.txt", proposedName: "swap-a.txt", isDirectory: false, error: nil)
        ])
        _ = try await service.execute(plan: swapPlan)
        try require((try String(contentsOf: swapA, encoding: .utf8)) == "B" && (try String(contentsOf: swapB, encoding: .utf8)) == "A", "Staged filename swap was unsafe")

        let rollbackA = root.appendingPathComponent("rollback-a.txt"); let rollbackB = root.appendingPathComponent("rollback-b.txt")
        let occupied = root.appendingPathComponent("occupied.txt")
        try Data("rollback-A".utf8).write(to: rollbackA); try Data("rollback-B".utf8).write(to: rollbackB); try Data("occupied".utf8).write(to: occupied)
        let rollbackPlan = RenamePlan(entries: [
            RenamePlanEntry(source: rollbackA, destination: root.appendingPathComponent("rollback-a-new.txt"), originalName: "rollback-a.txt", proposedName: "rollback-a-new.txt", isDirectory: false, error: nil),
            RenamePlanEntry(source: rollbackB, destination: occupied, originalName: "rollback-b.txt", proposedName: "occupied.txt", isDirectory: false, error: nil)
        ])
        do { _ = try await service.execute(plan: rollbackPlan); throw HarnessError("Forced partial failure unexpectedly succeeded") }
        catch is RenameActionError { }
        try require((try String(contentsOf: rollbackA, encoding: .utf8)) == "rollback-A" && (try String(contentsOf: rollbackB, encoding: .utf8)) == "rollback-B", "Partial failure did not restore sources")
        let namesAfterRollback = try FileManager.default.contentsOfDirectory(atPath: root.path)
        try require(!namesAfterRollback.contains(where: { $0.hasPrefix(".stash-rename-") }), "Partial failure left a staging name behind")

        let folder = root.appendingPathComponent("folder", isDirectory: true); let nested = folder.appendingPathComponent("nested.txt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); try Data("nested".utf8).write(to: nested)
        _ = try await service.execute(inputs: [folder], configuration: RenameConfiguration(prefix: "renamed-"))
        try require(FileManager.default.fileExists(atPath: root.appendingPathComponent("renamed-folder/nested.txt").path), "Folder rename did not preserve descendants")
        let overlap = service.plan(inputs: [root.appendingPathComponent("renamed-folder"), root.appendingPathComponent("renamed-folder/nested.txt")], configuration: RenameConfiguration(prefix: "x-"))
        try require(!overlap.isValid, "Folder/descendant overlap was not blocked")

        let missing = service.plan(inputs: [root.appendingPathComponent("missing.txt")], configuration: RenameConfiguration(prefix: "x-"))
        try require(!missing.isValid && missing.errors.joined().contains("no longer available"), "Missing source was not blocked")
        let generatedRoot = root.appendingPathComponent("generated", isDirectory: true)
        let generated = generatedRoot.appendingPathComponent("owned.txt")
        try FileManager.default.createDirectory(at: generatedRoot, withIntermediateDirectories: true)
        try Data("owned".utf8).write(to: generated)
        let store = GeneratedFileStore(root: generatedRoot)
        await store.record([generated])
        let renamedGenerated = generatedRoot.appendingPathComponent("renamed-owned.txt")
        _ = try await service.execute(inputs: [generated], configuration: RenameConfiguration(prefix: "renamed-"))
        await store.updateReferences(afterRenaming: [generated: renamedGenerated])
        let manifest = try String(contentsOf: generatedRoot.appendingPathComponent("owned-files.json"), encoding: .utf8)
        try require(manifest.contains("renamed-owned.txt") && !manifest.contains("\"\(generated.path)\""), "Generated-file ownership manifest was not updated")
        print("PASS: rename preview rules, collisions, Unicode, stable ordering, case-only rename, staged swap, rollback, folders, missing sources, and content preservation")
    }

    static func require(_ condition: Bool, _ message: String) throws { if !condition { throw HarnessError(message) } }
}

struct HarnessError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
