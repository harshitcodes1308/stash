# Project FLOW — Stage A: functional top drop target

Stage A established a compact AppKit `NSPanel` at the top centre of the display containing a real `NSDraggingDestination`. It registers the public pasteboard types for files, URLs, and plain text. When the pointer enters with a supported payload, the target highlights; on release it forwards normalized items through the existing shelf coordinator. Later FLOW stages now expand that foundation into the dedicated notch shelf described in `docs/project-flow.md`.

On a notched Mac, public auxiliary-area geometry identifies the physical notch. Because macOS owns the actual menu-bar/notch region, the registered AppKit destination is a completely transparent 52-point approach zone directly below it; every Finder drag headed to the notch crosses that destination. The shelf still animates from the physical notch geometry, so the larger functional target is never drawn as a second bar. On a display without a notch, Stash falls back to a discreet top-centre indicator. It uses no accessibility permission, event tap, screen recording permission, private API, or global drag monitor.

## Stage A platform boundaries

- Detect a drag anywhere on screen or outside the visible target. AppKit only sends dragging-destination callbacks once a Finder drag enters this app's panel.
- Claim a physical-notch-safe-area integration. The target uses public display geometry and is an intentionally neutral top-centre target on every display.

## Automated coverage

`Tools/notch-drop-harness.swift` verifies duplicate items inside one payload, supported file/URL/text payload handling, empty payload rejection, and repeated AppKit drag-sequence suppression. Real Finder dragging remains a manual GUI check.
