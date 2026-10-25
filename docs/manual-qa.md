# Manual QA checklist

These checks require a real macOS GUI session.

## Shelf and windows

1. Launch Stash, press `Control–Option–Space`, and create several shelves.
2. Drag one file, many mixed files, a folder, text, and a URL into shelves; confirm no duplicate reference appears from a single drop.
3. Drag a normal, generated, renamed, and missing-reference item from a shelf into Finder; cancel a drag once.
4. Pin a shelf, move/resize it, quit and relaunch; confirm its frame remains on the active display. Disconnect an external display and confirm the restored frame is visible.
5. Unpin, dismiss, reopen from the menu bar, and verify no unexpected shelf movement.

## Project FLOW — Stage A top drop target

1. Launch Stash on a notched Mac and confirm there is no detached idle strip below the notch. On a non-notched display, confirm only the discreet fallback indicator appears without covering menu-bar controls.
2. From Finder, drag one file into the physical notch/target. Confirm the shelf begins unfolding on entry, remains a valid destination through the motion, accepts on release, and contains that file.
3. Repeat with a folder, a Finder multi-selection, a dragged URL, and plain text where the source app supports it. Confirm each creates a shelf with only the dropped items.
4. Drag an unsupported pasteboard type over the target and confirm it does not highlight or create a shelf.
5. Move a Finder drag across the rest of the display and confirm Stash does not claim global drag detection or react until the pointer enters the target.
6. Repeat a rapid Finder drag and confirm one shelf is created per intentional drop with no duplicate items from one drop.
7. Verify regular floating shelves, menu-bar controls, and `Control–Option–Space` continue to work independently of the top target.

## Project FLOW — Stages B–E

1. Drop files on the top target and confirm the notch shelf expands from that target without flicker or focus theft. Confirm the target stays valid during expansion.
2. Test 1, 5, 10, 25, and 50 items. Confirm bounded sizing, adaptive tiles, internal scrolling, and no footer overlap.
3. Select one and several files. Verify Preview, Reveal, Copy Path, and applicable Smart Actions; confirm inapplicable actions remain hidden or disabled.
4. Open Quick Look for an available file, move through a multi-file preview, close it, and test a missing reference and an unsupported type.
5. Enable automatic collapse. Confirm it does not collapse during pointer interaction, drag-out, Quick Look, a menu, a sheet, or a running action; confirm it collapses after becoming idle.
6. Verify the notch shelf Close control always collapses it. Confirm a later drop reuses the shelf and retains prior items without duplication.
7. In Settings, toggle Notch Mode, automatic collapse, all animation intensities, and both post-drop behaviors. Relaunch and confirm persistence.
8. Enable Reduce Motion and confirm expansion, collapse, insertion, hover, and selection avoid spring or scaling motion.
9. Connect or disconnect a display and change the primary display. Confirm one target per display, correct top-center placement, and a visible expanded shelf within the receiving display.
10. Test menu-bar auto-hide and a full-screen Space where macOS permits auxiliary windows. Confirm targets do not cover menu-bar controls.

## Smart actions and output

1. Convert and resize images; test Current Shelf, New Shelf, and Choose Folder.
2. Create ZIPs from files and folders, inspect entries, and confirm unrelated paths are absent.
3. Batch rename files, check preview/collision blocking, confirmation, Finder result, and cross-shelf reference updates.
4. Merge three PDFs, reorder them, inspect order in Preview, and test a real password-protected PDF.
5. Pin shelves with each generated output, relaunch, and drag outputs to Finder.

## UI and safety

1. Test the rounded glass shell over bright and dark wallpapers in light/dark mode and Increased Contrast; confirm text and borders remain readable.
2. Enable Reduce Motion and confirm tile hover, selection, insertion, and drag targeting do not scale or spring.
3. Test long and Unicode filenames, duplicate visible names, a narrow shelf, manual resizing, and 20+ items; confirm the tile grid adapts and scrolls.
4. Drag a supported item across the shell and transparent corners; confirm the target glow only occurs over the interactive rounded shelf and clears on exit.
5. Verify hover and selection remain visually distinct, full filenames appear as tooltips, and missing items remain clear.
6. Add shelves containing 1, 4, 10, 25, and 50 mixed files. Resize each shelf freely and confirm adaptive columns, real image previews, stable tile dimensions, and scrolling with no footer overlap.
7. Navigate controls with Tab, activate default actions with Return, dismiss sheets with Escape, and verify VoiceOver labels for pin, dismiss, contextual removal, tiles, and actions.
8. Confirm unavailable items are visibly marked; no action silently overwrites or deletes a source file.
9. Test on each connected display and verify shelves avoid the Dock/menu bar after restore.

## Release screenshot checklist

Capture only real app windows after the checks above pass. Before adding an image to `docs/assets/` or a public release, verify that it shows no personal filenames, folder paths, desktop content, account names, or notification banners.

1. Capture the compact empty shelf in both light and dark appearances.
2. Capture a populated shelf with several representative files, including at least one real image thumbnail and a long filename.
3. Capture a shelf with enough items to demonstrate scrolling without footer overlap.
4. Capture one Smart Action panel using disposable fixture files.
5. Review every capture at native resolution and retain only the screenshots that accurately match the shipping build.
