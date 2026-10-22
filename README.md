<div align="center">

# Stash

### Your files, right where you need them.

Stash is a native macOS floating shelf for collecting files, folders, text, and links while you work — then moving, exporting, or processing them without losing your place.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-native-F05138?logo=swift&logoColor=white)
![Version](https://img.shields.io/badge/version-0.1.1-6E56CF)

</div>

![An empty Stash shelf, captured from the app](docs/assets/stash-empty-shelf.png)

<p align="center"><sub>The real compact empty shelf in Stash 0.1.1. A populated-shelf capture is tracked in the release checklist before any public binary download.</sub></p>

## Why Stash?

Your desktop and Downloads folder are not a workflow. Stash gives you small, independent shelves that stay handy while you collect items from Finder, prepare an attachment, organize a batch, or perform a quick file operation.

- Keep several focused shelves open at once.
- Drop files in from Finder and drag them back out when you are ready.
- Pin important shelves so they come back after restarting Stash.
- Work locally: Stash does not upload your files or send analytics.

## What it does

### A floating file shelf

- Menu-bar access plus `Control` + `Option` + `Space` to open a shelf.
- Compact, resizable glass shelves with scrolling, adaptive file tiles, selection, and drag-and-drop.
- Native image thumbnails where macOS can provide them; clear file icons as a fallback.
- Text and web links can live beside file references.

### Smart actions, without leaving your workflow

| Action | What it does |
| --- | --- |
| Image conversion and resizing | Creates a new image output; source files stay intact. |
| ZIP creation | Archives only the selected files and folders with safe relative paths. |
| Batch rename | Shows a validated preview and asks for confirmation before renaming originals. |
| PDF merge | Combines selected, readable PDFs in the order you choose. |

Generated results are retained in `~/Library/Application Support/Stash/Generated Outputs` so they remain usable after a relaunch.

## Getting started

Stash currently ships as a source-build beta. There is no Developer ID-signed, notarized public download yet, so the recommended path is to build it from this checkout on a Mac running macOS 13 or later.

1. Install Apple’s Xcode Command Line Tools if they are not already installed:

   ```zsh
   xcode-select --install
   ```

2. In Terminal, from this project folder, build the app:

   ```zsh
   ./Packaging/package-release.sh
   ```

3. Launch it:

   ```zsh
   open -n build/Stash.app
   ```

4. Look for the Stash icon in the menu bar, or press `Control` + `Option` + `Space` to create a shelf.

The locally produced archive is `build/Stash-0.1.1.zip`. It is ad-hoc signed for local testing, not notarized for public distribution.

## A quick first shelf

1. Open a shelf from the menu bar or with `Control` + `Option` + `Space`.
2. Drag files or folders from Finder onto the shelf.
3. Drag an item from a tile directly back into Finder, an email attachment field, or another supported target.
4. Select files and choose a Smart Action from the shelf toolbar when you want to convert, archive, rename, or merge them.
5. Pin a shelf to restore it at its saved position and size the next time Stash launches.

For a complete hands-on pass, see the [manual QA checklist](docs/manual-qa.md).

## Privacy and file safety

- Stash is local-first. It has no network features, analytics, or telemetry.
- Shelves hold references to your existing files; they do not silently duplicate source files.
- Image, ZIP, and PDF actions create new outputs instead of overwriting originals.
- Batch Rename is the exception by design: it changes selected original names only after you review and confirm the plan.
- Missing file references are shown as unavailable rather than silently removed.

## Current release status

Version 0.1.1 is a polished local beta, not yet a public downloadable release. It is ad-hoc signed and has not been notarized. The remaining publication work is documented in the [release guide](docs/release.md), including Developer ID signing, notarization, a populated-shelf screenshot pass, and manual macOS QA.

## Contributing

Before sharing a change, run the full local checks:

```zsh
./Tools/run-regressions.sh
./Packaging/package-release.sh
```

The architecture and project decisions are outlined in [docs/architecture.md](docs/architecture.md).

## License

No license has been selected or included yet. Until a license is added, this repository does not provide a public open-source use grant.
