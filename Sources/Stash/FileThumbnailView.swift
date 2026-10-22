import AppKit
import QuickLookThumbnailing
import SwiftUI

@MainActor
final class FileThumbnailModel: ObservableObject {
    @Published private(set) var thumbnail: NSImage?

    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 300
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    private var request: QLThumbnailGenerator.Request?
    private var preparationTask: Task<Void, Never>?
    private var generation = UUID()

    func load(url: URL, size: CGSize) {
        cancel()
        thumbnail = nil
        let token = UUID()
        generation = token
        preparationTask = Task { [weak self] in
            let signature = await Task.detached(priority: .utility) {
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
                return "\(url.standardizedFileURL.path)|\(modified)|\(fileSize)|\(Int(size.width))x\(Int(size.height))"
            }.value
            guard let self, self.generation == token, !Task.isCancelled else { return }
            if let cached = Self.cache.object(forKey: signature as NSString) {
                thumbnail = cached
                return
            }
            let scale = NSScreen.main?.backingScaleFactor ?? 2
            let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: [.thumbnail])
            self.request = request
            do {
                let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                guard generation == token, !Task.isCancelled else { return }
                let image = representation.nsImage
                let cost = max(1, Int(image.size.width * image.size.height * scale * scale * 4))
                Self.cache.setObject(image, forKey: signature as NSString, cost: cost)
                thumbnail = image
                self.request = nil
            } catch {
                guard generation == token else { return }
                self.request = nil
            }
        }
    }

    func cancel() {
        preparationTask?.cancel()
        preparationTask = nil
        if let request { QLThumbnailGenerator.shared.cancel(request) }
        request = nil
    }
}

struct FileThumbnailView: View {
    let item: ShelfItem
    let size: CGFloat
    @StateObject private var model = FileThumbnailModel()

    var body: some View {
        Group {
            if let thumbnail = model.thumbnail {
                Image(nsImage: thumbnail).resizable().scaledToFit()
            } else if let url = item.fileURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit()
            } else {
                Image(systemName: item.symbolName).resizable().scaledToFit().padding(8)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .onAppear { if let url = item.fileURL, item.isAvailable { model.load(url: url, size: CGSize(width: size, height: size)) } }
        .onDisappear { model.cancel() }
        .onChange(of: item.value) { _ in if let url = item.fileURL, item.isAvailable { model.load(url: url, size: CGSize(width: size, height: size)) } }
        .accessibilityHidden(true)
    }
}
