# Milestone 2.4 plan: Smart Batch Rename

## Existing boundaries

`ShelfItem` keeps an external file URL and a stable UUID. Pinned shelves serialize those values through `ShelfStore`. `ActionRegistry` already makes file-only actions selection-aware, while image and archive actions use separate services. Generated outputs are owned by `GeneratedFileStore` and must not be treated as copies for an in-place rename.

## Proposed design

- Add **Batch Rename** only when every selected item is an existing file reference. Mixed selections are rejected by the action registry rather than silently filtered.
- Add `RenameActionService` as the single source of truth for transformation, preview, validation, and execution. The SwiftUI sheet consumes its plan directly, so execution cannot use a different naming algorithm than the preview.
- The initial rule set supports prefix, suffix, literal find/replace with case sensitivity, and stable sequential numbering. Original extensions are retained by default. Date naming is deliberately deferred because it is optional and would need a user-visible choice of creation versus modification date.
- The preview keeps shelf order, shows proposed names and item-specific errors, and blocks confirmation until the entire plan is valid.

## Safety model

Rename operations never change parent directories or file contents. Selected folders rename only their own entry; descendants are not individually renamed. Symbolic links and overlapping selections (a folder together with an item inside it) are rejected.

The service validates missing sources, invalid names, filename length, Unicode/case-folded duplicate destinations, existing unrelated destinations, and parent writability. It performs validation again immediately before work starts.

For execution, every changed source first moves to a unique hidden temporary name in its original parent directory. Only then are staged entries moved to their final names. This supports cycles and case-only renames without overwriting. A failure triggers best-effort rollback of completed and staged moves, and the result explicitly reports any paths that could not be recovered. Durable recovery after forced termination is not promised.

## Reference updates

After a successful operation, `ShelfCoordinator` updates all open shelf items whose URL is the renamed entry or a descendant of a renamed folder. It preserves each item UUID and timestamps, persists pinned shelves, and leaves generated-file ownership unchanged because the generated path itself remains valid and is merely renamed in place.

## Verification

A disposable command-line harness will cover name rules, preview validation, case-only rename, cycles, Unicode, separate folders, source-content preservation, and rollback-safe preflight failures. Existing action, image, and archive harnesses will also run before rebuilding the signed app bundle. GUI interaction, Finder drag-out, and restart restoration remain manual macOS checks.
