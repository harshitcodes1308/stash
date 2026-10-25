import AppKit
@preconcurrency import QuickLookUI

@MainActor
final class QuickLookCoordinator: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var previewURLs: [URL] = []
    var onVisibilityChange: ((Bool) -> Void)?

    func preview(_ urls: [URL], startingAt index: Int = 0) {
        previewURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !previewURLs.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = min(max(index, 0), previewURLs.count - 1)
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        onVisibilityChange?(true)
    }

    func close() {
        if QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared() { panel.orderOut(nil) }
        previewURLs.removeAll()
        onVisibilityChange?(false)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURLs.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard previewURLs.indices.contains(index) else { return nil }
        return previewURLs[index] as NSURL
    }

    func previewPanelWillClose(_ panel: QLPreviewPanel!) {
        previewURLs.removeAll()
        onVisibilityChange?(false)
    }
}
