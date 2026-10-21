# Phase 1 audit

Audit date: 2026-10-21

## Verified in this environment

- The release target compiles with Swift 6.3.3 on macOS 26.6.2 (arm64).
- `build/Stash.app` has a valid application bundle structure, a valid Info.plist, an executable arm64 Mach-O payload, and a successful ad-hoc signature verification.
- A live launch created one visible Stash shelf window. A macOS event probe then sent Control–Option–Space and observed a second visible Stash shelf window.
- After Finder became active, both Stash shelf windows remained visible, confirming the no-hide-on-deactivation behavior.
- The bundle is an accessory/menu-bar app (`LSUIElement=true`) and declares only system AppKit, Carbon, Foundation, SwiftUI, and related system frameworks.
- No sandbox entitlement, privacy usage key, Accessibility API, Apple Events API, or network framework is present. The Phase 1 implementation therefore needs no permission prompt for its advertised behavior.
- Shelf references are serialized as `Codable` local metadata in `UserDefaults`; a file item persists a URL string and never copies, moves, or deletes the original source file.
- Ownership is bounded: the coordinator owns active window controllers; each controller holds a weak coordinator reference; closed panels notify the coordinator to release their controller. Pinned metadata is the only intended persistent state.

## Issues corrected during the audit

- A shelf no longer hides when Stash loses focus (`hidesOnDeactivate = false`).
- The current-shelf menu action now follows the last-focused shelf, not merely the last-created shelf.
- Reopening a shelf no longer re-centres a user-moved panel.
- A first-time shelf is placed on the display containing the pointer, with the primary display as fallback. This gives basic multi-monitor creation behavior.
- Closing a panel releases its controller from the active-coordinator collection.

## Requires manual GUI verification

The local native UI automation service could not attach to Stash’s accessibility tree, so the following are not claimed as executed tests:

1. Confirm the Stash menu-bar item is visibly present.
2. Drag one file and then several files from Finder to a shelf; confirm each is listed.
3. Drag one listed file from Stash back to a Finder folder; confirm Finder receives it and the source is unchanged.
4. Create two shelves, add different items, bring each forward, and use **Show Current Shelf** from the Stash menu.
5. Pin a shelf containing a file reference, quit Stash, reopen it, and confirm the shelf and its file reference return.
6. Repeat shelf creation with the pointer on each connected monitor. Verify the initial shelf appears on that monitor and a moved panel remains where placed when reopened.

## Known limitations retained for Phase 1

- Restored pinned shelves do not yet persist a specific window frame/display; they use the pointer-display placement rule on each launch.
- Sandboxed distribution will require security-scoped bookmarks for external file URLs. This current unsigned-sandbox-free bundle uses ordinary local file references.
- There is no automated XCTest target because the available Command Line Tools SDK does not provide XCTest or Swift Testing.
