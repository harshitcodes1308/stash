# Manual QA checklist

These checks require a real macOS GUI session.

## Shelf and windows

1. Launch Stash, press `Control–Option–Space`, and create several shelves.
2. Drag one file, many mixed files, a folder, text, and a URL into shelves; confirm no duplicate reference appears from a single drop.
3. Drag a normal, generated, renamed, and missing-reference item from a shelf into Finder; cancel a drag once.
4. Pin a shelf, move/resize it, quit and relaunch; confirm its frame remains on the active display. Disconnect an external display and confirm the restored frame is visible.
5. Unpin, dismiss, reopen from the menu bar, and verify no unexpected shelf movement.

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
6. Navigate controls with Tab, activate default actions with Return, dismiss sheets with Escape, and verify VoiceOver labels for pin, dismiss, remove, tiles, and actions.
7. Confirm unavailable items are visibly marked; no action silently overwrites or deletes a source file.
8. Test on each connected display and verify shelves avoid the Dock/menu bar after restore.
