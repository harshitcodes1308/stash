# Phase 1 status

## Implemented

- Original native macOS menu-bar executable.
- `Control–Option–Space` global shortcut that creates a new floating shelf.
- Separate draggable floating shelves with dismissal, renaming, clearing, and pinning.
- File, URL, and plain-text drop intake with duplicate suppression.
- Native file/URL/text dragging from a shelf through `NSItemProvider`.
- Local persistence and restoration of pinned shelf metadata; source files remain references.

## Verified

`swift build` succeeds using Swift 6.3.3 on macOS 26.6.2 (arm64).

See [the Phase 1 audit](phase-1-audit.md) for the current evidence, fixes, and GUI verification checklist.

## Not yet GUI-verified

The environment has Command Line Tools but no full Xcode IDE/runtime test harness. Launch the generated executable, then: press `Control–Option–Space`; drag one file and multiple Finder files into a shelf; drag an item back to Finder; drop text and a URL; pin the shelf; quit and relaunch; confirm the pinned shelf returns. Verify the original test file remains unchanged.

## Known Phase 1 limitations

The configurable shortcut UI, sandbox security-scoped bookmarks, thumbnails, collapse control, and full settings pane remain follow-up work. Shake/edge activation is intentionally deferred to Phase 4 because universal cross-application drag observation is not a dependable Phase 1 API surface.
