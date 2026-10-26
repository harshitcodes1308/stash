import AppKit

@main
struct NotchTabsHarness {
    @MainActor static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let suite = "stash-tabs-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShelfStore(defaults: defaults)
        let preferences = NotchPreferences(defaults: defaults)
        preferences.animationIntensity = .off
        let coordinator = ShelfCoordinator(store: store)
        let workspace = NotchShelfController(coordinator: coordinator, preferences: preferences)
        let saved = Shelf(title: "Saved", items: [ShelfItem(text: "saved content")], isPinned: true)
        store.save(saved)
        workspace.restoreTabs(store.pinnedShelves)
        precondition(workspace.tabs.count == 1 && workspace.selectedTabID == nil, "Restore quietly without opening windows")
        workspace.newTab(items: [ShelfItem(text: "converted output")])
        let outputID = workspace.selectedTabID!
        precondition(workspace.tabs.count == 2 && workspace.tabs.last?.items.first?.value == "converted output")
        let oldWindow = NSApp.windows.first { $0.isVisible && $0.frame.height > 100 }!
        let openFrame = oldWindow.frame
        preferences.animationIntensity = .standard
        workspace.selectTab(saved.id)
        let newWindow = NSApp.windows.first { $0.isVisible && $0.frame.height > 100 }!
        precondition(newWindow !== oldWindow && !oldWindow.isVisible)
        precondition(newWindow.frame == openFrame && newWindow.alphaValue == 1, "Switching open tabs must keep the full-size opaque shell without replaying entrance")
        preferences.animationIntensity = .off
        precondition(workspace.selectedTabID == saved.id && workspace.tabs.first?.items.first?.value == "saved content")
        workspace.closeTab(outputID)
        precondition(workspace.tabs.count == 1 && workspace.selectedTabID == saved.id)
        workspace.closeTab(saved.id)
        precondition(workspace.tabs.isEmpty && store.pinnedShelves.count == 1, "Closing a pinned tab must preserve saved files")
        workspace.openPinned(store.pinnedShelves[0])
        precondition(workspace.selectedTabID == saved.id && workspace.tabs.count == 1)
        workspace.collapse(animated: false, respectingInteraction: false)
        print("PASS: notch tab creation, independent contents, selection, close, quiet restore, and pinned reopen")
    }
}
