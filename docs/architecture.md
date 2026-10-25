# Stash Phase 1 architecture

`AppDelegate` owns the menu-bar item and global hotkey. `ShelfCoordinator` manages independent floating `NSPanel` controllers. Each `ShelfWindowController` owns one mutable shelf and its presentation. `ShelfItem` represents a file URL, text, or URL without silently copying original files. `ShelfStore` persists only pinned shelves as local JSON in `UserDefaults`.

The boundary is intentional: windowing and pasteboard behavior stay in AppKit, while the shelf content is a SwiftUI view. Phase 2 actions and Phase 3 collections can attach to the model without changing file-reference semantics.

Milestone 2.3 adds `ArchiveActionService`, which streams ZIP creation through macOS's bundled `bsdtar`/libarchive process with structured arguments, validates and rejects symbolic links, and records verified generated archives through the existing `GeneratedFileStore`.

Milestone 2.4 adds `RenameActionService`. It produces one validated plan for the live UI preview and the actual in-place rename. Valid operations stage every changed path to a unique hidden sibling before moving to final paths, allowing case-only changes and cycles without overwriting. `ShelfCoordinator` rewrites file URLs in every open shelf, including descendant references when a folder is renamed, while preserving stable shelf item UUIDs. `GeneratedFileStore` rewrites owned-path manifest entries for renamed generated files.

Milestone 2.5 adds `PDFActionService`, a PDFKit-only merge pipeline. It validates every selected document's UTI, readability, lock state, and page count; creates a staged merged document in explicit sheet order; reopens it to verify its page count; then records the finalized durable output through `GeneratedFileStore`. The shelf controller uses the same output destination path as images and ZIPs.

Milestone 2.7 keeps that architecture intact while replacing the presentation layer. `ShelfWindowController` configures a transparent, shadowed, resizable panel; `ShelfView` provides the material shell, adaptive lazy tile grid, integrated toolbar, and Reduce Motion-aware interaction system. Stable shelf IDs, `NSItemProvider` drag payloads, selection semantics, and all action services are unchanged.

Project FLOW adds `NotchShelfController` as a separate multi-display AppKit drag-destination coordinator. It maintains one compact target per `NSScreen` and one reusable notch-specific `ShelfWindowController`. Accepted `NotchDropPayload` values flow into that normal shelf model, preserving thumbnails, selection, drag-out, generated-output semantics, and the existing Smart Action services. `NotchPreferences` persists immediate settings, while `QuickLookCoordinator` owns the native `QLPreviewPanel`. Pure layout, state-machine, and collapse-policy types keep display bounds and suppression behavior regression-testable without unsupported global drag detection.

The installed Command Line Tools SDK in the build environment does not include XCTest or Swift Testing, so automated tests are deferred rather than faked. The project does compile with `swift build`; UI drag/drop and hotkey behavior require the manual test pass described in the Phase 1 report.
