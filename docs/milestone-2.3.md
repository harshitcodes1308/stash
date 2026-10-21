# Milestone 2.3: ZIP creation

## Implemented

- **Create ZIP** appears only when the selection contains one or more existing file/folder references. It remains unavailable for text, URLs, missing references, and mixed unsupported selections.
- ZIP configuration supports a validated archive name, the genuine default ZIP compression supplied by libarchive, top-level-folder omission for one folder, and the existing current-shelf/new-shelf/export-folder destinations.
- Generated ZIPs use Stash’s durable Application Support storage and are recorded as owned generated outputs before being added to a shelf.
- Archive entries are planned relative to the selected inputs’ deepest common parent. This preserves nested hierarchy and disambiguates duplicate basenames from different directories.

## ZIP engine and dependency

`ArchiveActionService` invokes `/usr/bin/bsdtar`, macOS’s bundled libarchive utility (3.7.4 on the development host), using `Foundation.Process` plus an argument array. No shell is used. libarchive is BSD-licensed; no dependency is bundled or redistributed by Stash.

The service creates ZIPs in a durable generated-output directory, lists entries with `bsdtar -tf` to verify the archive can be reopened, then records the output. It uses libarchive’s default ZIP compression; there are no fake fast/small controls.

## ZIP content bug fix (2026-10-22)

The original implementation derived one common parent for all selected URLs and passed paths from that broad location into the archiver. That meant selections spanning user folders could create top-level `Downloads/` and `Library/` roots; a stale selected generated item or a selected directory containing Stash’s output location could therefore pull managed-output content into the ZIP. The implementation did not otherwise enumerate unrelated paths: every archived path originated in the resolved selection or a selected directory traversal.

The fix removes common-parent archive roots entirely. Each selected item is staged under its own explicit, collision-safe root, then `/usr/bin/zip` receives only those staged roots. The ZIP is created in an isolated temporary workspace and moved to durable generated storage only after its entry list is verified. As a result, Stash’s Application Support output and the destination ZIP can never be traversed as part of a source tree.

Regression result for a simulated home folder:

```
Selected inputs: Downloads/first.png, Downloads/second.png
Actual ZIP entries: first.png, second.png
Excluded: Library/unrelated.txt, Library/Application Support/Stash/Generated Outputs/old-output.zip
```

## File safety

- Inputs are read-only; Stash never changes or deletes originals.
- Missing sources fail before creation.
- All symbolic links, including nested links, are rejected. Stash does not follow them outside the selected tree.
- Absolute/traversal archive names are rejected.
- Output names are collision-safe. Exporting copies a generated ZIP to a non-overwriting destination name.
- Failed or cancelled operations remove the incomplete generated output.

## Limitations

- The bundled libarchive command is macOS-specific, so this target remains macOS-only.
- Progress is indeterminate and cancellation is cooperative before/after the currently running libarchive process; a per-process cancel button is not yet exposed.
- Restored pinned shelves retain ZIP URL references like other file references; manual restart verification is still required.

## Automated results

- Archive harness: passed files/folders, nested folders, empty folders, spaces/Unicode, collision-safe duplicate names, source preservation, output verification, missing input, and symlink rejection. The regression case confirmed that Downloads-only selection excludes unrelated Library and managed-output paths.
- Image harness: passed JPEG conversion, PNG resize, and durable generated output.
- Action registry harness: passed image-only, generic-file ZIP, and text exclusion applicability.
- Release build and ad-hoc signature verification: passed.

## Manual verification

1. Select files/folders in a shelf and choose **Actions → Create ZIP**.
2. Confirm the default current-shelf ZIP can be dragged into Finder.
3. Test New Shelf and Choose Folder output destinations.
4. Test a folder with nested and empty subfolders, then inspect it in Finder or Archive Utility.
5. Pin a shelf containing a generated ZIP, quit, relaunch, and confirm the ZIP reference remains available.

Launch the current build with:

```zsh
open -n /Users/harshitsingh/Documents/stash/build/Stash.app
```
