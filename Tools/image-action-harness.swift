import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct ImageActionHarness {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("stash-image-harness-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("fixture.png")
        try makeFixture(at: source, width: 100, height: 50)

        let service = ImageActionService(store: GeneratedFileStore(root: root.appendingPathComponent("generated", isDirectory: true)))
        let conversion = await service.run(inputs: [source], request: ImageActionRequest(format: .jpeg, resizeMode: nil, resizeValue: nil, jpegQuality: 0.8, stripMetadata: false, allowUpscaling: false))
        guard conversion.failures.isEmpty, conversion.outputs.count == 1, let converted = CGImageSourceCreateWithURL(conversion.outputs[0] as CFURL, nil), let convertedType = CGImageSourceGetType(converted), UTType(convertedType as String) == .jpeg else { throw HarnessError("JPEG conversion failed: \(conversion.failures)") }

        let resized = await service.run(inputs: [source], request: ImageActionRequest(format: .png, resizeMode: .maximumWidth, resizeValue: 25, jpegQuality: 0.9, stripMetadata: false, allowUpscaling: false))
        guard resized.failures.isEmpty, let output = resized.outputs.first, let image = CGImageSourceCreateWithURL(output as CFURL, nil), let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any], let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw HarnessError("Resize did not produce a readable result") }
        guard width <= 25, height <= 25, abs((Double(width) / Double(height)) - 2.0) < 0.12 else { throw HarnessError("Resize returned unexpected dimensions \(width)×\(height)") }
        print("PASS: JPEG conversion, PNG resizing, and durable generated output creation")
    }

    static func makeFixture(at url: URL, width: Int, height: Int) throws {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw HarnessError("Could not create fixture context") }
        context.setFillColor(red: 0.15, green: 0.45, blue: 0.9, alpha: 1); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw HarnessError("Could not create PNG fixture") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw HarnessError("Could not write PNG fixture") }
    }
}

struct HarnessError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
