# Stash Phase 1 architecture

`AppDelegate` owns the menu-bar item and global hotkey. `ShelfCoordinator` manages independent floating `NSPanel` controllers. Each `ShelfWindowController` owns one mutable shelf and its presentation. `ShelfItem` represents a file URL, text, or URL without silently copying original files. `ShelfStore` persists only pinned shelves as local JSON in `UserDefaults`.

The boundary is intentional: windowing and pasteboard behavior stay in AppKit, while the shelf content is a SwiftUI view. Phase 2 actions and Phase 3 collections can attach to the model without changing file-reference semantics.

Milestone 2.3 adds `ArchiveActionService`, which streams ZIP creation through macOS's bundled `bsdtar`/libarchive process with structured arguments, validates and rejects symbolic links, and records verified generated archives through the existing `GeneratedFileStore`.

Milestone 2.4 adds `RenameActionService`. It produces one validated plan for the live UI preview and the actual in-place rename. Valid operations stage every changed path to a unique hidden sibling before moving to final paths, allowing case-only changes and cycles without overwriting. `ShelfCoordinator` rewrites file URLs in every open shelf, including descendant references when a folder is renamed, while preserving stable shelf item UUIDs. `GeneratedFileStore` rewrites owned-path manifest entries for renamed generated files.

The installed Command Line Tools SDK in the build environment does not include XCTest or Swift Testing, so automated tests are deferred rather than faked. The project does compile with `swift build`; UI drag/drop and hotkey behavior require the manual test pass described in the Phase 1 report.
