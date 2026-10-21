# Reference analysis: Dropover

## Scope and boundaries

This is a read-only static inspection of the supplied `references/Dropover.app` bundle. It was not executed, modified, extracted for redistribution, or used as a source of code or artwork. Stash is an independent implementation using public macOS APIs.

## Evidence

REA inspected the bundle inventory (`ev_875918b2bea7e35c90dabcee4854dec5b9649bcc3924d2c06cb505f4e8bdcb20`) and its Info.plist (`ev_2e71b7abb4e5d19f06a2d8113ddf7bbf9c540ffef27ba359c0da7a24d85f70f6`). The native executable was statically loaded as an arm64 slice and examined through REA (`ev_a19aa52bdbd64fdd383ca4d8d88c8613a6bc68d519bcabc24a71a89626c95f9e`; shelf-related string search `ev_59358c373ffc7528ab95ad0d859346d440eb3e3011230c8eb137da2dfed8de96`). Static strings are implementation clues, not runtime proof.

## Directly observed facts

- The supplied bundle is a macOS menu-bar utility (`LSUIElement`) named Dropover, version 5.3.1, with macOS 13 as its declared minimum system version.
- Its metadata declares a generic file viewer document type, URL schemes, and a macOS Service accepting file contents, plain text, rich text, and URLs.
- Its static artifact inventory includes distinct identifiers for inbound and outbound drag handling, shelf panels, pinning, clearing, docking, shelf activation settings, and pinned window menus.
- The bundle declares cloud integrations and telemetry-related frameworks; Stash deliberately does not adopt these for Phase 1.

## Inferences, not verified behavior

The names `ShelfPanel…`, `InboundDropIndicator…`, `OutboundDrag…`, `pinnedWindow`, and hotkey/activation-setting strings suggest separate floating shelf panels, visual drop feedback, outbound dragging, pinnable shelves, and configurable activation. They do not establish exact visual behavior, accessibility, gesture thresholds, or any runtime interaction.

## User journeys worth carrying forward

1. Create a temporary collection quickly from a small, persistent menu-bar presence.
2. Drop one or many external items into a visible target.
3. Keep a useful collection available by pinning it.
4. Retrieve an item by dragging it to a destination.

## Stash Phase 1 decisions

Stash implements an original, compact AppKit floating panel per shelf; file, text, and URL intake; outbound native pasteboard dragging; a menu-bar entry point; `Control–Option–Space`; pinning; and local restoration of pinned shelf metadata. It stores external file URLs rather than copying source files.

## Explicit exclusions

Shake/edge detection, clouds, uploads, transformation actions, recipes, and automated lifecycle rules are excluded from Phase 1. Global drag interception is deferred because supported macOS APIs do not guarantee reliable universal cross-app drag-state access without accessibility-sensitive behavior.

## Technical constraints

The implementation uses AppKit `NSPanel`, SwiftUI hosting for content, `NSItemProvider` for drag/drop, Carbon’s supported global hotkey registration API, Foundation persistence, and Uniform Type Identifiers. External/sandboxed references may require security-scoped bookmark support before a sandboxed distribution build; this initial Swift Package target is not sandboxed.
