import AppKit
import Foundation

@main
struct ThumbnailHarness {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("stash-thumbnail-harness-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let imageURL = root.appendingPathComponent("preview.png")
        try writePNG(to: imageURL, width: 80, height: 50, color: .systemIndigo)

        let model = FileThumbnailModel()
        model.load(url: imageURL, size: CGSize(width: 64, height: 64))
        try await waitForThumbnail(model)
        guard let first = model.thumbnail else { throw HarnessError("Quick Look did not produce the first thumbnail") }

        try writePNG(to: imageURL, width: 96, height: 72, color: .systemOrange)
        model.load(url: imageURL, size: CGSize(width: 64, height: 64))
        try await waitForThumbnail(model, differentFrom: first)
        guard let second = model.thumbnail, first !== second else { throw HarnessError("A changed image reused its stale cached thumbnail") }
        model.cancel()
        print("PASS: asynchronous Quick Look thumbnail generation and modification-aware cache refresh")
    }

    @MainActor static func waitForThumbnail(_ model: FileThumbnailModel, differentFrom previous: NSImage? = nil) async throws {
        for _ in 0..<100 {
            if let image = model.thumbnail, previous == nil || image !== previous { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw HarnessError("Timed out waiting for Quick Look thumbnail")
    }

    static func writePNG(to url: URL, width: Int, height: Int, color: NSColor) throws {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { throw HarnessError("Could not create image fixture") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        color.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw HarnessError("Could not encode image fixture") }
        try data.write(to: url, options: .atomic)
    }
}

struct HarnessError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
