import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ShelfStore()
    private let notchPreferences = NotchPreferences.shared
    private var coordinator: ShelfCoordinator!
    private var notchShelfController: NotchShelfController!
    private var settingsWindowController: StashSettingsWindowController!
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private var hasLaunched = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        launchInterface()
    }

    func launchInterface() {
        guard !hasLaunched else { return }
        hasLaunched = true
        coordinator = ShelfCoordinator(store: store)
        notchShelfController = NotchShelfController(coordinator: coordinator, preferences: notchPreferences)
        coordinator.routeNewShelf = { [weak self] items in
            guard let self else { return false }
            DispatchQueue.main.async { self.notchShelfController.newTab(items: items) }
            return true
        }
        settingsWindowController = StashSettingsWindowController(preferences: notchPreferences)
        configureMenuBar(); registerGlobalHotKey()
        notchShelfController.show()
        // A menu-bar utility should launch quietly. Pinned shelves are the
        // user's explicit request to restore a visible workspace.
        notchShelfController.restoreTabs(store.pinnedShelves)
    }
    func applicationWillTerminate(_ notification: Notification) { if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) } }

    private func configureMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "Stash")
        rebuildMenu()
    }
    private func rebuildMenu(_ existingMenu: NSMenu? = nil) {
        let menu = existingMenu ?? NSMenu()
        menu.removeAllItems()
        menu.delegate = self
        menu.addItem(withTitle: "New Stash", action: #selector(newShelf), keyEquivalent: "n")
        menu.addItem(withTitle: "Show Current Stash", action: #selector(showCurrentShelf), keyEquivalent: "o")
        menu.addItem(withTitle: "Open Notch Workspace", action: #selector(showNotchDropTarget), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        if store.pinnedShelves.isEmpty { let item = NSMenuItem(title: "No pinned shelves", action: nil, keyEquivalent: ""); item.isEnabled = false; menu.addItem(item) }
        else { for shelf in store.pinnedShelves { let item = NSMenuItem(title: "Show \(shelf.title)", action: #selector(showPinned(_:)), keyEquivalent: ""); item.representedObject = shelf.id.uuidString; menu.addItem(item) } }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Stash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != nil && item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem.menu = menu
    }
    @objc private func newShelf() { coordinator.newShelf() }
    @objc private func showCurrentShelf() { notchShelfController.openCurrent() }
    @objc private func showNotchDropTarget() { notchShelfController.openCurrent() }
    @objc private func showSettings() { settingsWindowController.show() }
    @objc private func showPinned(_ sender: NSMenuItem) { guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw), let shelf = store.pinnedShelves.first(where: { $0.id == id }) else { return }; notchShelfController.openPinned(shelf) }
    func menuNeedsUpdate(_ menu: NSMenu) { rebuildMenu(menu) }

    private func registerGlobalHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }; let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue(); DispatchQueue.main.async { delegate.coordinator.newShelf() }; return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
        guard handlerStatus == noErr else {
            NSLog("Stash could not install its global hotkey handler (Carbon status: %d).", handlerStatus)
            return
        }
        let id = EventHotKeyID(signature: OSType(0x53544153), id: 1)
        let registrationStatus = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if registrationStatus != noErr {
            NSLog("Stash could not register Control-Option-Space (Carbon status: %d).", registrationStatus)
        }
    }
}
