# Stash

Stash is a local-first native macOS floating shelf for temporarily collecting files, folders, text, and links, then moving or processing them without copying source files.

## Features

- Floating, independently movable shelves with menu-bar access and `Control–Option–Space`.
- Finder drag-in and drag-out, text and URL items, pinning, and pinned-shelf restoration.
- Smart actions for image conversion/resizing, ZIP creation, safe batch rename, and PDF merging.
- Durable generated files stored locally in `~/Library/Application Support/Stash/Generated Outputs`.

## Requirements and run

Stash targets macOS 13 or later. Build and launch locally:

```zsh
./Tools/run-regressions.sh
./Packaging/package-release.sh
open -n build/Stash.app
```

The packaged beta is `build/Stash-0.1.0.zip`. This local build is ad-hoc signed, not Developer ID signed or notarized.

## File safety and privacy

Stash stores references to external files; it does not silently duplicate or upload them. Image, ZIP, and PDF actions create new durable outputs. Batch Rename explicitly changes selected original names only after confirmation. Stash has no network features, analytics, or telemetry.

## Known limitations

Date naming and rename undo are not implemented. PDF document-level features (forms, signatures, bookmarks, encryption) are not guaranteed after merge. See [manual QA](docs/manual-qa.md) and [release notes](docs/release.md) before distribution.

## Contributing

Run the regression runner before opening a change. This repository currently has no license file; a license choice is required before public open-source distribution.

## Screenshots

No screenshots are included yet. Add real screenshots from a macOS GUI session before public release.
