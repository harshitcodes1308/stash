# Stash v0.2.0 — Project FLOW implementation

Project FLOW keeps regular floating shelves intact and adds an independent top-center workflow built entirely with public AppKit, SwiftUI, Quick Look, and pasteboard APIs.

## Stage A — Functional drag destination

`NotchShelfController` creates one compact `NSDraggingDestination` per connected display. On notched Macs it derives the real notch gap from `NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea`, then places a fully transparent approach destination directly below the system-owned menu-bar region. The shelf still unfolds from the physical notch, leaving no visible idle bar. Targets accept Finder file URLs, folders, web URLs, and plain text. AppKit drag-sequence IDs suppress duplicate delivery. There is no accessibility permission, event tap, screen recording permission, private API, or claim of global drag detection.

## Stage B — Expansion and collapse

A valid drag entering the notch starts expanding a dedicated reusable `ShelfWindowController` immediately. Destination exits do not close the shelf: AppKit can transfer the drag from the trigger to the newly opened shelf, which previously caused repeated opening and closing. Interrupted closing animations cannot hide a subsequently reopened shelf. The expanded shelf stays bounded and scrolls internally.

Hovering below the notch reveals an accessible Open Stash button. Clicking it opens the existing shelf and suppresses automatic collapse until explicitly closed. The button becomes Close Stash while open, in a dedicated strip above the shelf controls. Closing retains the shelf items for the next opening.

Automatic collapse is optional and disabled by default. When enabled, collapse waits five seconds and is suppressed while the pointer is inside, the shelf is key, an item drag is active, a sheet or action is active, or Quick Look is visible. Explicit Close always collapses immediately through the same controller.

## Stage C — Tiles and contextual actions

The existing thumbnail-first tile grid, Quick Look thumbnail cache, multi-selection, drag-out behavior, missing-file state, and Smart Action registry are reused. Selected files expose compact Preview, Reveal, and Copy Path controls. Tile context menus expose the same non-destructive utilities plus removal. Existing image, ZIP, rename, and PDF implementations remain the only filesystem action implementations.

## Stage D — Quick Look

`QuickLookCoordinator` uses `QLPreviewPanel` with existing file references. It filters missing files, previews one or several selected items, and reports visibility so automatic collapse cannot occur behind a preview. Unsupported files are left to Quick Look's native fallback behavior.

## Stage E — Settings, display handling, and motion

Settings persist in `UserDefaults` and apply immediately:

- Enable or disable Notch Mode.
- Enable optional automatic collapse.
- Choose Off, Subtle, or Standard animation intensity.
- Show drops in the notch shelf or send each drop to a new floating shelf.

Targets are recreated when screen parameters change. Layout uses each `NSScreen.visibleFrame` and `safeAreaInsets`; no notch dimensions are hardcoded. Reduce Motion overrides geometry animation. The implementation uses one reusable notch shelf, notifications only for display changes, asynchronous existing thumbnail generation, and no idle polling.

## Platform constraint

Finder only sends dragging-destination callbacks after the pointer enters one of Stash's visible target panels. Public macOS APIs do not provide the requested global pre-entry Finder-drag detection without broader monitoring techniques that Project FLOW intentionally does not use.
