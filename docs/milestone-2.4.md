# Milestone 2.4: Smart Batch Rename

## Feature overview

**Actions → Batch Rename** is available only when every selected shelf item is a currently existing file reference. Text, URLs, missing files, and mixed selections do not expose the action. Selected folders are renamed as entries, not recursively.

The compact native sheet provides prefix, suffix, literal find/replace (case-sensitive or insensitive), and sequential numbering with start, increment, padding, and separator. Extensions remain unchanged. Date naming is optional in the product specification and intentionally deferred; Stash does not silently choose creation or modification time.

## Preview and validation

The sheet preserves shelf ordering and renders original and proposed filenames from the same `RenameActionService` plan used at execution. It marks unchanged entries and shows an item-specific error for invalid plans. Confirmation is disabled when the plan has errors or changes nothing.

Validation rejects missing sources, symbolic links, a selected folder plus its descendant, empty or traversal-like names, separators, overlong names, duplicate names after case/Unicode normalization, unrelated existing destinations, and non-writable parents. Stash blocks case-insensitive collisions even on a case-sensitive volume as a conservative safety rule.

## Safety and recovery

The user must select **Review Rename…** and then **Rename Originals** in a confirmation dialog. Stash re-plans immediately before moving anything. It first stages each changed source under a unique hidden sibling name and then moves those staged entries to their final names. This handles case-only changes, swaps, and cycles without overwriting. Sources stay in their original parent directory and contents are never modified.

If a filesystem move fails, Stash attempts to restore completed and remaining staged entries, then reports how many recovered. Recovery is best effort; an app crash or forced termination during the operation cannot guarantee durable recovery and may leave a hidden staging filename, which is a known limitation. One-level Undo is deferred rather than implemented unsafely.

## Shelf and generated-file references

After success, every open shelf updates matching file URLs while preserving the `ShelfItem` UUID and timestamp. References to descendants update when a selected folder moves. Pinned shelves persist the revised URLs through `ShelfStore`. The generated-file manifest is updated for exact and descendant generated paths so Stash retains ownership after an in-place rename.

## Automated verification

`Tools/rename-action-harness.swift` uses only a temporary directory and covers prefix, suffix, stable numbering, zero padding, extension preservation, literal case-insensitive replacement, Unicode names, duplicate and existing-destination blocking, missing source handling, case-only rename, staged two-file swap, forced partial-failure rollback, folder rename, content preservation, and generated-file ownership manifest rewrite.

The existing action-registry, image-action, and ZIP regression harnesses also run before the release bundle is rebuilt.

## Manual QA checklist

1. Add two files to a shelf, select them, and confirm **Actions → Batch Rename** appears; select text or a URL and confirm it does not.
2. Change a prefix, suffix, find/replace, and sequence values; confirm preview changes immediately and preserves extensions.
3. Create a collision in Finder and confirm the Rename button disables with an explanation.
4. Confirm **Cancel** at the confirmation dialog leaves originals untouched; confirm **Rename Originals** updates Finder and shelf names.
5. Drag a renamed item from the shelf into Finder.
6. Pin a shelf containing renamed entries, relaunch Stash, and confirm the updated references remain valid.
7. Open two shelves referencing the same file; rename in one and confirm both update.
8. Repeat the existing image conversion and ZIP actions.

## Known limitations

- Date-based naming and one-level Undo are deferred.
- Permission-denied and mid-operation rollback failures are platform-dependent and require manual GUI/system-permission testing.
- Accessibility, Finder drag-out, cross-shelf UI refresh, and restoration after a real app relaunch require manual macOS verification.
