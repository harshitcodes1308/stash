# Changelog

## 0.2.0 — Project FLOW beta

- Added the official Stash application icon to the packaged macOS bundle and README branding.
- Added a native multi-display top-center drag destination and reusable notch-anchored shelf.
- Added bounded spring expansion, optional guarded automatic collapse, and Reduce Motion handling.
- Added contextual Preview, Reveal in Finder, and Copy Path actions while retaining the existing Smart Action registry.
- Added native Quick Look previews for available shelf file references.
- Added persistent Notch Mode, collapse, animation, and post-drop settings.
- Added regression coverage for drop deduplication, layout bounds, expansion state, collapse suppression, and settings persistence.

Distributed as an ad-hoc-signed, non-notarized GitHub beta release.

## 0.1.1 — Floating shelf polish

### Highlights

- Refined the floating shelf into a compact, neutral glass surface with a cleaner single-outline silhouette.
- Added compact adaptive file tiles, native image thumbnails, filename truncation, contextual removal controls, and a non-overlapping scroll region.
- Preserved free manual resizing, pinned shelf placement and size restoration, Finder drag-in/out, multi-selection, and Smart Actions.
- Added a dedicated window-drag handle so dragging a file tile transfers that item instead of moving the shelf.
- Expanded regression coverage with asynchronous thumbnail generation and cache-refresh checks.

### Smart Actions included

- Image conversion and resizing.
- Safe ZIP creation with verified selected-input paths.
- Confirmed batch renaming with collision protection.
- Native PDF merging.

### Distribution note

This is a locally buildable, ad-hoc-signed beta. It is not Developer ID signed or notarized, and it is not yet published as a public binary release. See [docs/release.md](docs/release.md).

## 0.1.0 — Beta foundation

- Floating local file shelves with menu-bar and global-hotkey access.
- Durable generated-output retention and pinned shelf restoration.
- Pinned shelf frame persistence with safe display clamping.
- Unified regression runner and reproducible app ZIP packaging.
