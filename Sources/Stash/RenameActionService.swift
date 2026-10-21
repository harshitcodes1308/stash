import Foundation

struct RenameConfiguration: Equatable {
    var prefix = ""
    var suffix = ""
    var find = ""
    var replace = ""
    var caseSensitive = false
    var sequentialNumbering = false
    var startingNumber = 1
    var increment = 1
    var zeroPadding = 3
    var numberSeparator = "-"
}

struct RenamePlanEntry: Identifiable {
    let source: URL
    let destination: URL
    let originalName: String
    let proposedName: String
    let isDirectory: Bool
    var error: String?
    var id: URL { source }
    var changesName: Bool { source.lastPathComponent != proposedName }
}

struct RenamePlan {
    let entries: [RenamePlanEntry]
    var errors: [String] { entries.compactMap(\.error) }
    var isValid: Bool { !entries.isEmpty && errors.isEmpty }
    var changedCount: Int { entries.filter(\.changesName).count }
}

struct RenameActionResult {
    let renamed: [URL: URL]
    let recovered: [String]
    let failures: [String]
}

enum RenameActionError: LocalizedError {
    case invalidPlan([String])
    case operationFailed(String, recovered: [String], failures: [String])

    var errorDescription: String? {
        switch self {
        case .invalidPlan(let errors): return errors.first ?? "The rename plan is invalid."
        case .operationFailed(let message, _, _): return message
        }
    }
}

struct RenameActionService: Sendable {

    func plan(inputs: [URL], configuration: RenameConfiguration) -> RenamePlan {
        var entries = inputs.enumerated().map { offset, source -> RenamePlanEntry in
            let source = source.standardizedFileURL
            let values = try? source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isDirectory = values?.isDirectory ?? false
            let name = source.lastPathComponent
            let proposed = proposedName(for: name, isDirectory: isDirectory, index: offset, configuration: configuration)
            return RenamePlanEntry(source: source, destination: source.deletingLastPathComponent().appendingPathComponent(proposed), originalName: name, proposedName: proposed, isDirectory: isDirectory, error: nil)
        }
        validate(&entries)
        return RenamePlan(entries: entries)
    }

    func execute(inputs: [URL], configuration: RenameConfiguration) async throws -> RenameActionResult {
        let currentPlan = plan(inputs: inputs, configuration: configuration)
        guard currentPlan.isValid else { throw RenameActionError.invalidPlan(currentPlan.errors) }
        return try await Task.detached(priority: .userInitiated) {
            let revalidated = RenameActionService().plan(inputs: inputs, configuration: configuration)
            guard revalidated.isValid else { throw RenameActionError.invalidPlan(revalidated.errors) }
            return try Self.executeSynchronously(plan: revalidated)
        }.value
    }

    /// Exposed for the disposable regression harness to verify staged swaps and cycles.
    func execute(plan: RenamePlan) async throws -> RenameActionResult {
        guard plan.isValid else { throw RenameActionError.invalidPlan(plan.errors) }
        return try await Task.detached(priority: .userInitiated) { try Self.executeSynchronously(plan: plan) }.value
    }

    private func proposedName(for original: String, isDirectory: Bool, index: Int, configuration: RenameConfiguration) -> String {
        let extensionPart = isDirectory ? "" : URL(fileURLWithPath: original).pathExtension
        let stem: String
        if extensionPart.isEmpty { stem = original }
        else { stem = URL(fileURLWithPath: original).deletingPathExtension().lastPathComponent }
        let replaced: String
        if configuration.find.isEmpty { replaced = stem }
        else {
            replaced = stem.replacingOccurrences(of: configuration.find, with: configuration.replace, options: configuration.caseSensitive ? [] : [.caseInsensitive], range: nil)
        }
        var result = configuration.prefix + replaced + configuration.suffix
        if configuration.sequentialNumbering {
            let value = configuration.startingNumber + (index * configuration.increment)
            let number = String(format: "%0*ld", Swift.max(0, configuration.zeroPadding), value)
            result += configuration.numberSeparator + number
        }
        return extensionPart.isEmpty ? result : result + "." + extensionPart
    }

    private func validate(_ entries: inout [RenamePlanEntry]) {
        let sourcePaths = Set(entries.map { $0.source.path })
        for index in entries.indices {
            let entry = entries[index]
            if !FileManager.default.fileExists(atPath: entry.source.path) { entries[index].error = "\(entry.originalName) is no longer available."; continue }
            let values = try? entry.source.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values?.isSymbolicLink == true { entries[index].error = "Symbolic links cannot be renamed by Stash."; continue }
            if let invalid = invalidNameReason(entry.proposedName) { entries[index].error = invalid; continue }
            if entry.proposedName.lengthOfBytes(using: .utf8) > 255 { entries[index].error = "\(entry.proposedName) exceeds the filesystem filename limit."; continue }
            let parent = entry.source.deletingLastPathComponent()
            if !FileManager.default.isWritableFile(atPath: parent.path) { entries[index].error = "You do not have permission to rename items in \(parent.lastPathComponent)."; continue }
            if FileManager.default.fileExists(atPath: entry.destination.path), !sameEntryIgnoringCase(entry.source, entry.destination), !sourcePaths.contains(entry.destination.path) {
                entries[index].error = "\(entry.proposedName) already exists."; continue
            }
        }

        let groups = Dictionary(grouping: entries.indices) { normalizedDestinationKey(entries[$0].destination) }
        for indices in groups.values where indices.count > 1 {
            for index in indices where entries[index].error == nil { entries[index].error = "Multiple selected items would use the same destination name." }
        }
        for parent in entries.filter(\.isDirectory) {
            let prefix = parent.source.path.hasSuffix("/") ? parent.source.path : parent.source.path + "/"
            for child in entries where child.source.path.hasPrefix(prefix) {
                if let index = entries.firstIndex(where: { $0.source == child.source }) { entries[index].error = "Do not rename a folder and one of its descendants in the same operation." }
            }
        }
    }

    private func invalidNameReason(_ name: String) -> String? {
        if name.isEmpty || name == "." || name == ".." { return "A filename cannot be empty, . or ..." }
        if name.contains("/") || name.unicodeScalars.contains(where: { $0.value == 0 }) { return "Filenames cannot contain path separators." }
        return nil
    }

    private func normalizedDestinationKey(_ url: URL) -> String {
        url.path.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private func sameEntryIgnoringCase(_ lhs: URL, _ rhs: URL) -> Bool {
        normalizedDestinationKey(lhs) == normalizedDestinationKey(rhs)
    }

    private static func executeSynchronously(plan: RenamePlan) throws -> RenameActionResult {
        let manager = FileManager.default
        var staged: [(RenamePlanEntry, URL)] = []
        var completed: [(RenamePlanEntry, URL)] = []
        var recovered: [String] = []
        do {
            for entry in plan.entries where entry.changesName {
                let stagingURL = try uniqueStagingURL(for: entry.source, fileManager: manager)
                try manager.moveItem(at: entry.source, to: stagingURL)
                staged.append((entry, stagingURL))
            }
            for (entry, stagingURL) in staged {
                try manager.moveItem(at: stagingURL, to: entry.destination)
                completed.append((entry, stagingURL))
            }
            return RenameActionResult(renamed: Dictionary(uniqueKeysWithValues: completed.map { ($0.0.source, $0.0.destination) }), recovered: [], failures: [])
        } catch {
            var failures: [String] = [error.localizedDescription]
            for (entry, _) in completed.reversed() {
                do { if manager.fileExists(atPath: entry.destination.path) { try manager.moveItem(at: entry.destination, to: entry.source); recovered.append(entry.originalName) } }
                catch { failures.append("Could not restore \(entry.originalName): \(error.localizedDescription)") }
            }
            for (entry, stagingURL) in staged.reversed() where !completed.contains(where: { $0.0.source == entry.source }) {
                do { if manager.fileExists(atPath: stagingURL.path) { try manager.moveItem(at: stagingURL, to: entry.source); recovered.append(entry.originalName) } }
                catch { failures.append("Could not restore staged \(entry.originalName): \(error.localizedDescription)") }
            }
            throw RenameActionError.operationFailed("Rename stopped. \(recovered.count) item(s) recovered.", recovered: recovered, failures: failures)
        }
    }

    private static func uniqueStagingURL(for source: URL, fileManager: FileManager) throws -> URL {
        let parent = source.deletingLastPathComponent()
        for _ in 0..<100 {
            let candidate = parent.appendingPathComponent(".stash-rename-\(UUID().uuidString)")
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        throw RenameActionError.operationFailed("Could not reserve a safe temporary filename.", recovered: [], failures: [])
    }
}
