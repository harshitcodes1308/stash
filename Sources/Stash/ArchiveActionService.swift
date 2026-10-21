import Foundation

struct ArchiveRequest {
    var archiveName: String
    var omitSingleTopLevelFolder: Bool
}

struct ArchiveActionResult {
    let output: URL
    let entries: [String]
}

enum ArchiveActionError: LocalizedError {
    case invalidName, missing(URL), symbolicLink(URL), noInputs, processFailed(String), verificationFailed, cancelled, stagingFailed
    var errorDescription: String? {
        switch self {
        case .invalidName: return "Enter an archive name without path separators or '..'."
        case .missing(let url): return "Couldn't create archive because \(url.lastPathComponent) is no longer available."
        case .symbolicLink(let url): return "Stash does not archive symbolic links for safety (\(url.lastPathComponent))."
        case .noInputs: return "Select at least one file or folder to archive."
        case .processFailed(let message): return "Couldn't create archive: \(message)"
        case .verificationFailed: return "The archive was created but could not be verified."
        case .cancelled: return "Archive creation was cancelled."
        case .stagingFailed: return "Couldn't safely stage the archive output."
        }
    }
}

struct ArchiveActionService {
    let store: GeneratedFileStore

    func run(inputs: [URL], request: ArchiveRequest) async throws -> ArchiveActionResult {
        let archiveName = try validatedName(request.archiveName)
        let uniqueInputs = Array(Set(inputs.map { $0.standardizedFileURL })).sorted { $0.path < $1.path }
        guard !uniqueInputs.isEmpty else { throw ArchiveActionError.noInputs }
        for input in uniqueInputs { try validateTree(at: input) }
        try Task.checkCancellation()
        let output = try await store.makeOutputURL(named: archiveName, pathExtension: "zip")
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("stash-archive-\(UUID().uuidString)", isDirectory: true)
        let staging = workspace.appendingPathComponent("archive.zip")
        defer { try? FileManager.default.removeItem(at: workspace) }
        do {
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            try await Task.detached(priority: .userInitiated) {
                try createArchive(inputs: uniqueInputs, output: staging, stagingRoot: workspace.appendingPathComponent("inputs", isDirectory: true), omitTopLevel: request.omitSingleTopLevelFolder)
                return ()
            }.value
            try Task.checkCancellation()
            let entries = try await Task.detached(priority: .utility) { try listEntries(in: staging) }.value
            guard !entries.isEmpty else { throw ArchiveActionError.verificationFailed }
            try FileManager.default.moveItem(at: staging, to: output)
            await store.record([output])
            return ArchiveActionResult(output: output, entries: entries)
        } catch {
            try? FileManager.default.removeItem(at: output)
            try? FileManager.default.removeItem(at: workspace)
            if error is CancellationError { throw ArchiveActionError.cancelled }
            throw error
        }
    }

    private func validatedName(_ name: String) throws -> String {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".zip", with: "", options: [.caseInsensitive, .anchored])
        guard !base.isEmpty, !base.contains("/"), !base.contains("\\"), !base.contains(".."), base != "." else { throw ArchiveActionError.invalidName }
        return base
    }

    private func validateTree(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw ArchiveActionError.missing(url) }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        if values.isSymbolicLink == true { throw ArchiveActionError.symbolicLink(url) }
        guard values.isDirectory == true else { return }
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [], errorHandler: { _, _ in false }) else { return }
        for case let child as URL in enumerator {
            if (try? child.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { throw ArchiveActionError.symbolicLink(child) }
        }
    }

    private func createArchive(inputs: [URL], output: URL, stagingRoot: URL, omitTopLevel: Bool) throws {
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        let roots: [String]
        if omitTopLevel, inputs.count == 1, let values = try? inputs[0].resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true {
            roots = try stageDirectoryContents(of: inputs[0], into: stagingRoot)
        } else {
            roots = try entryPlans(for: inputs).map { plan in
                let target = stagingRoot.appendingPathComponent(plan.archiveRoot)
                try stageItem(at: plan.source, to: target)
                return plan.archiveRoot
            }
        }
        _ = try runZip(["-q", "-r", "-y", output.path, "--"] + roots, currentDirectory: stagingRoot)
    }

    private func listEntries(in archive: URL) throws -> [String] {
        let output = try runTool(["-t", "-f", archive.path])
        return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    private func stageDirectoryContents(of source: URL, into target: URL) throws -> [String] {
        let children = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        guard !children.isEmpty else {
            let emptyFolder = target.appendingPathComponent(source.lastPathComponent, isDirectory: true)
            try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
            return [emptyFolder.lastPathComponent]
        }
        return try children.map { child in
            try stageItem(at: child, to: target.appendingPathComponent(child.lastPathComponent))
            return child.lastPathComponent
        }
    }

    private func stageItem(at source: URL, to target: URL) throws {
        let values = try source.resourceValues(forKeys: [.isDirectoryKey])
        if values.isDirectory == true {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            for child in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
                try stageItem(at: child, to: target.appendingPathComponent(child.lastPathComponent))
            }
        } else {
            do { try FileManager.default.linkItem(at: source, to: target) }
            catch { try FileManager.default.copyItem(at: source, to: target) }
        }
    }

    private func runTool(_ arguments: [String]) throws -> String {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/bsdtar"); process.arguments = arguments
        let standardOutput = Pipe(); let standardError = Pipe(); process.standardOutput = standardOutput; process.standardError = standardError
        try process.run(); process.waitUntilExit()
        let output = String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else { throw ArchiveActionError.processFailed(error.isEmpty ? "libarchive returned status \(process.terminationStatus)." : error.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return output
    }

    private func runZip(_ arguments: [String], currentDirectory: URL) throws -> String {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/zip"); process.arguments = arguments; process.currentDirectoryURL = currentDirectory
        let standardOutput = Pipe(); let standardError = Pipe(); process.standardOutput = standardOutput; process.standardError = standardError
        try process.run(); process.waitUntilExit()
        let output = String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else { throw ArchiveActionError.processFailed(error.isEmpty ? "zip returned status \(process.terminationStatus)." : error.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return output
    }

    private func entryPlans(for inputs: [URL]) -> [(source: URL, archiveRoot: String)] {
        var usedNames: Set<String> = []
        return inputs.map { input in
            let base = input.lastPathComponent
            var candidate = base; var suffix = 2
            while usedNames.contains(candidate.lowercased()) {
                candidate = "\(input.deletingPathExtension().lastPathComponent)-\(suffix)"
                if !input.pathExtension.isEmpty { candidate += ".\(input.pathExtension)" }
                suffix += 1
            }
            usedNames.insert(candidate.lowercased())
            return (input, candidate)
        }
    }

}
