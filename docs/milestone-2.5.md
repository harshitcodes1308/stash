# Milestone 2.5: Native PDF Smart Actions

## Implemented

**Merge PDFs** appears only for a selection of at least two existing, readable, parseable, unlocked PDF references. It does not appear for images, text, URLs, a single PDF, or a mixed file selection. The selection order is retained initially.

The native configuration sheet displays names, page counts, validation status, output filename, and current-shelf/new-shelf/export-folder choices. Up/down buttons provide keyboard-accessible document reordering. The user-selected order is the merge order. The output filename receives `.pdf` automatically and is made collision-safe by the generated-output store.

## PDFKit pipeline and safety

`PDFActionService` validates the file UTI and opens each document through PDFKit. It rejects missing, unreadable, non-PDF, corrupt, locked, and zero-page inputs without silently omitting any selection. Locked/password-protected PDFs are rejected; Stash neither asks for passwords nor attempts to bypass protection.

Pages are inserted in document and page order into a new PDFKit document. Work happens away from the UI task, checks cancellation between documents, writes to a temporary staging file, reopens the result, verifies the expected page count, and only then moves it to durable Stash storage and records ownership. Sources are never modified. A failure removes incomplete staged or durable output.

## Output and retention

The existing output destinations are reused:

- **Current Shelf:** add the durable generated PDF reference to the active shelf.
- **New Shelf:** create a shelf containing the generated PDF reference.
- **Choose folder:** copy the verified durable result to a collision-safe destination.

Generated PDFs use `GeneratedFileStore`, so pinned shelves retain ordinary file references across relaunch just as they do for ZIP and image outputs.

## Limitations

- The merge preserves page sequence, media boxes, rotation, and page rendering through PDFKit. It does not promise preservation of signatures, form behavior, bookmarks, source metadata, document-level encryption, or a cryptographically equivalent copy.
- Cancellation is cooperative between source documents; a merge already inserting pages may finish that current document first.
- The test host's PDFKit writer can create an encrypted fixture that it immediately unlocks in-process, so the locked-input branch is exercised conditionally in automation. The service still explicitly rejects any PDFKit document reported as locked; manual testing with a real password-protected PDF remains required.
- Live GUI ordering, Finder drag-out, current/new shelf visual delivery, export panel behavior, and restart restoration need manual macOS verification.

## Automated verification

`Tools/pdf-action-harness.swift` creates disposable PDFs with distinct page dimensions and rotations. It passed normal and reversed three-document merges, verifies all four output page positions, source byte preservation, corrupt and missing-input rejection, durable generated-file manifest retention, collision-safe output naming, export copy readability, action applicability, and shelf JSON persistence.

The existing action registry, image-action, ZIP, and batch-rename harnesses are also run before packaging.

## Manual QA checklist

1. Add three PDFs to a shelf, select them, and confirm **Actions → Merge PDFs** appears only when all selected entries are PDFs.
2. Confirm displayed page counts, use up/down controls to reorder, merge, and inspect the resulting page order in Preview.
3. Test Current Shelf, New Shelf, and Choose Folder destinations; drag each output into Finder.
4. Try a corrupt and a real password-protected PDF; confirm Merge is unavailable or reports a clear error with no output.
5. Pin a shelf containing a merged PDF, quit and relaunch, then verify the output reference.
6. Re-run image conversion, ZIP creation, and batch rename from the same shelf.
