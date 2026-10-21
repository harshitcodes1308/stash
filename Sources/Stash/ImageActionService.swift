import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageOutputFormat: String, CaseIterable, Identifiable {
    case jpeg, png, webP
    var id: String { rawValue }
    var title: String { rawValue == "webP" ? "WebP" : rawValue.uppercased() }
    var type: UTType {
        switch self { case .jpeg: return .jpeg; case .png: return .png; case .webP: return UTType("org.webmproject.webp")! }
    }
    static var available: [ImageOutputFormat] {
        let encoders = Set(CGImageDestinationCopyTypeIdentifiers() as NSArray as! [String])
        return allCases.filter { encoders.contains($0.type.identifier) }
    }
}

struct ImageActionRequest {
    let format: ImageOutputFormat
    let resizeMode: ImageResizeMode?
    let resizeValue: Double?
    let jpegQuality: Double
    let stripMetadata: Bool
    let allowUpscaling: Bool
}

enum ImageResizeMode: String, CaseIterable, Identifiable {
    case maximumWidth, maximumHeight, percentage
    var id: String { rawValue }
    var title: String { switch self { case .maximumWidth: return "Maximum width"; case .maximumHeight: return "Maximum height"; case .percentage: return "Percentage" } }
}

struct ImageActionResult {
    let outputs: [URL]
    let failures: [String]
}

enum ImageActionError: LocalizedError {
    case outputFormatUnavailable, unreadable(URL), encodingFailed(URL)
    var errorDescription: String? {
        switch self {
        case .outputFormatUnavailable: return "This macOS installation cannot encode the selected format."
        case .unreadable(let url): return "Could not read \(url.lastPathComponent)."
        case .encodingFailed(let url): return "Could not create an output for \(url.lastPathComponent)."
        }
    }
}

actor GeneratedFileStore {
    private let root: URL
    private let manifestURL: URL

    init(root overrideRoot: URL? = nil, fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        root = overrideRoot ?? support.appendingPathComponent("Stash/Generated Outputs", isDirectory: true)
        manifestURL = root.appendingPathComponent("owned-files.json")
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func makeOutputURL(for source: URL, format: ImageOutputFormat) throws -> URL {
        try makeOutputURL(named: source.deletingPathExtension().lastPathComponent, pathExtension: format.type.preferredFilenameExtension ?? format.rawValue)
    }

    func makeOutputURL(named base: String, pathExtension: String) throws -> URL {
        let runDirectory = root.appendingPathComponent(Self.runName(), isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        var candidate = runDirectory.appendingPathComponent(base).appendingPathExtension(pathExtension)
        var count = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = runDirectory.appendingPathComponent("\(base)-\(count)").appendingPathExtension(pathExtension)
            count += 1
        }
        return candidate
    }

    func record(_ urls: [URL]) {
        let existing = (try? JSONDecoder().decode([String].self, from: Data(contentsOf: manifestURL))) ?? []
        let values = Array(Set(existing + urls.map(\.path))).sorted()
        try? JSONEncoder().encode(values).write(to: manifestURL, options: .atomic)
    }

    func updateReferences(afterRenaming renamed: [URL: URL]) {
        let existing = (try? JSONDecoder().decode([String].self, from: Data(contentsOf: manifestURL))) ?? []
        let updated = existing.map { path -> String in
            for (old, new) in renamed {
                if path == old.path { return new.path }
                let prefix = old.path.hasSuffix("/") ? old.path : old.path + "/"
                if path.hasPrefix(prefix) { return new.appendingPathComponent(String(path.dropFirst(prefix.count))).path }
            }
            return path
        }
        try? JSONEncoder().encode(Array(Set(updated)).sorted()).write(to: manifestURL, options: .atomic)
    }

    private static func runName() -> String { ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-") }
}

struct ImageActionService {
    let store: GeneratedFileStore

    func run(inputs: [URL], request: ImageActionRequest) async -> ImageActionResult {
        guard ImageOutputFormat.available.contains(request.format) else { return ImageActionResult(outputs: [], failures: [ImageActionError.outputFormatUnavailable.localizedDescription]) }
        return await Task.detached(priority: .userInitiated) {
            var outputs: [URL] = []; var failures: [String] = []
            for input in inputs {
                do { outputs.append(try await convert(input, request: request, store: store)) }
                catch { failures.append(error.localizedDescription) }
            }
            await store.record(outputs)
            return ImageActionResult(outputs: outputs, failures: failures)
        }.value
    }

    private func convert(_ input: URL, request: ImageActionRequest, store: GeneratedFileStore) async throws -> URL {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil) else { throw ImageActionError.unreadable(input) }
        let output = try await store.makeOutputURL(for: input, format: request.format)
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, request.format.type.identifier as CFString, 1, nil) else { throw ImageActionError.encodingFailed(input) }
        var properties: [CFString: Any] = [:]
        if request.format == .jpeg { properties[kCGImageDestinationLossyCompressionQuality] = request.jpegQuality }

        if let maximumDimension = resizeMaximumDimension(source: source, request: request) {
            let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let width = sourceProperties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = sourceProperties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            let needsResize = request.allowUpscaling || maximumDimension < Swift.max(width, height)
            if needsResize, let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
                kCGImageSourceShouldCacheImmediately: false
            ] as CFDictionary) {
                CGImageDestinationAddImage(destination, image, request.stripMetadata ? properties as CFDictionary : properties.merging(sourceProperties ?? [:]) { _, new in new } as CFDictionary)
            } else {
                CGImageDestinationAddImageFromSource(destination, source, 0, request.stripMetadata ? properties as CFDictionary : properties as CFDictionary)
            }
        } else {
            CGImageDestinationAddImageFromSource(destination, source, 0, request.stripMetadata ? properties as CFDictionary : properties as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { try? FileManager.default.removeItem(at: output); throw ImageActionError.encodingFailed(input) }
        return output
    }

    private func resizeMaximumDimension(source: CGImageSource, request: ImageActionRequest) -> Int? {
        guard let mode = request.resizeMode, let value = request.resizeValue, value > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let requestedScale: Double
        switch mode {
        case .maximumWidth: requestedScale = value / Double(width)
        case .maximumHeight: requestedScale = value / Double(height)
        case .percentage: requestedScale = value / 100
        }
        let scale = request.allowUpscaling ? requestedScale : Swift.min(1, requestedScale)
        guard scale < 0.999 else { return nil }
        return Swift.max(1, Int((Double(Swift.max(width, height)) * scale).rounded(.up)))
    }
}
