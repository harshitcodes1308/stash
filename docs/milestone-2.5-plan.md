# Milestone 2.5 plan: Native PDF merge

## Architecture

`PDFActionService` will use Apple PDFKit only. It will validate the UTI and open every selected document before constructing a new `PDFDocument` in the user-chosen order. It will write to `GeneratedFileStore`'s durable container, reopen the result, and confirm the expected page count before recording the owned generated path.

`ActionRegistry` will expose **Merge PDFs** only for two or more currently existing, readable, parseable, unlocked PDF file references. A mixed selection is rejected as a whole; no items are silently omitted. The initial order follows shelf order, and the SwiftUI sheet owns an ordered URL list with accessible up/down buttons as well as native drag reordering.

## Safety model

Sources are read only. Locked, corrupted, missing, zero-page, non-PDF, and unreadable inputs produce clear failures. The service checks for cancellation between source documents, removes an incomplete output on failure, and never overwrites a result. Generated output uses the same current-shelf, new-shelf, and export-folder behavior as existing actions.

PDFKit page insertion preserves pages in source and selected-document order. Document-level features such as signatures, forms, bookmarks, encryption, and source metadata are not promised in the merged document. Output verification reopens the PDF and checks the expected count; the disposable harness also checks the ordered media boxes and rotations of distinguishable test pages.

## Verification

A PDFKit harness will build disposable PDFs with distinct page dimensions/rotations, test normal and reversed merge order, invalid/missing/corrupt/locked inputs, source-byte preservation, generated-file retention, output collisions, and destination-copy behavior. Existing regression harnesses will run again before rebuilding `build/Stash.app`.
