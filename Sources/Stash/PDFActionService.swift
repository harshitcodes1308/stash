import Foundation
import PDFKit
import UniformTypeIdentifiers

struct PDFInputInfo: Identifiable, Sendable {
    let url: URL
    let pageCount: Int
    let validationMessage: String?
    var id: URL { url }
    var isValid: Bool { validationMessage == nil }
}

struct PDFMergeRequest: Sendable {
    var outputName: String
}

struct PDFMergeResult: Sendable {
    let output: URL
    let pageCount: Int
}

enum PDFActionError: LocalizedError {
    case noInputs, invalidName, missing(URL), unreadable(URL), notPDF(URL), locked(URL), empty(URL), invalid(URL), writeFailed, verificationFailed, cancelled

    var errorDescription: String? {
        switch self {
        case .noInputs: return "Select at least two PDFs to merge."
        case .invalidName: return "Enter an output name without path separators or '..'."
        case .missing(let url): return "\(url.lastPathComponent) is no longer available."
        case .unreadable(let url): return "Stash cannot read \(url.lastPathComponent)."
        case .notPDF(let url): return "\(url.lastPathComponent) is not a valid PDF."
        case .locked(let url): return "\(url.lastPathComponent) is password protected and cannot be merged."
        case .empty(let url): return "\(url.lastPathComponent) has no pages."
        case .invalid(let url): return "\(url.lastPathComponent) could not be opened as a PDF."
        case .writeFailed: return "Stash could not write the merged PDF."
        case .verificationFailed: return "The merged PDF could not be verified."
        case .cancelled: return "PDF merge was cancelled."
        }
    }
}

struct PDFActionService: Sendable {
    let store: GeneratedFileStore

    func inspect(_ urls: [URL]) -> [PDFInputInfo] {
        urls.map { url in
            do { return PDFInputInfo(url: url, pageCount: try Self.validate(url).pageCount, validationMessage: nil) }
            catch { return PDFInputInfo(url: url, pageCount: 0, validationMessage: error.localizedDescription) }
        }
    }

    func run(inputs: [URL], request: PDFMergeRequest) async throws -> PDFMergeResult {
        guard inputs.count >= 2 else { throw PDFActionError.noInputs }
        let name = try validatedName(request.outputName)
        let output = try await store.makeOutputURL(named: name, pathExtension: "pdf")
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("stash-pdf-\(UUID().uuidString)", isDirectory: true)
        let staging = workspace.appendingPathComponent("merged.pdf")
        defer { try? FileManager.default.removeItem(at: workspace) }
        do {
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            let count = try await Task.detached(priority: .userInitiated) { try Self.merge(inputs: inputs, staging: staging) }.value
            try Task.checkCancellation()
            try FileManager.default.moveItem(at: staging, to: output)
            await store.record([output])
            return PDFMergeResult(output: output, pageCount: count)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            try? FileManager.default.removeItem(at: output)
            if error is CancellationError { throw PDFActionError.cancelled }
            throw error
        }
    }

    private func validatedName(_ name: String) throws -> String {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".pdf", with: "", options: [.caseInsensitive, .anchored])
        guard !base.isEmpty, !base.contains("/"), !base.contains("\\"), !base.contains(".."), base != "." else { throw PDFActionError.invalidName }
        return base
    }

    private static func validate(_ url: URL) throws -> PDFDocument {
        guard FileManager.default.fileExists(atPath: url.path) else { throw PDFActionError.missing(url) }
        guard FileManager.default.isReadableFile(atPath: url.path) else { throw PDFActionError.unreadable(url) }
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType) ?? UTType(filenameExtension: url.pathExtension)
        guard type?.conforms(to: .pdf) == true else { throw PDFActionError.notPDF(url) }
        guard let document = PDFDocument(url: url) else { throw PDFActionError.invalid(url) }
        guard !document.isLocked else { throw PDFActionError.locked(url) }
        guard document.pageCount > 0 else { throw PDFActionError.empty(url) }
        return document
    }

    private static func merge(inputs: [URL], staging: URL) throws -> Int {
        let result = PDFDocument()
        var expectedPageCount = 0
        for input in inputs {
            try Task.checkCancellation()
            let document = try Self.validate(input)
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { throw PDFActionError.invalid(input) }
                result.insert(page, at: result.pageCount)
                expectedPageCount += 1
            }
        }
        guard expectedPageCount > 0, result.write(to: staging) else { throw PDFActionError.writeFailed }
        guard let verified = PDFDocument(url: staging), !verified.isLocked, verified.pageCount == expectedPageCount else { throw PDFActionError.verificationFailed }
        return expectedPageCount
    }
}
