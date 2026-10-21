# Phase 2 plan: milestones 2.1–2.2

## Scope

Milestones 2.1–2.4 are complete. PDF merging and Phase 2 final verification remain deliberately deferred.

## Design

`ActionRegistry` evaluates a selection of existing `ShelfItem` references. It uses a file URL's resource content type first and uses a filename-derived UTI only as a fallback. An action is offered only when every selected item satisfies that action's requirements.

`ImageActionService` performs conversion and resizing on a utility queue using ImageIO. It creates files in Stash's durable Application Support container rather than a temporary directory. A `GeneratedFileStore` records those owned paths separately from external shelf references.

The shelf gains lightweight item selection and an Actions menu. The image sheet offers JPEG/PNG and WebP only when ImageIO reports a WebP encoder, along with resize constraints and an output destination. Results default to the current shelf, while a new shelf and a user-selected export folder remain explicit alternatives.

## Safety

Source files are read-only inputs. Generated names are collision-safe and outputs are written to a Stash-owned run directory. Export is a copy from the durable generated result, not a move. Missing, inaccessible, malformed, and unsupported images return individual failures without deleting prior successful output.

Batch Rename is the intentional exception: it changes selected original file or folder names in place after a separate explicit confirmation. Its preview and execution share one plan. The service rejects links, missing sources, overlap between a selected folder and descendant, invalid paths, duplicates, and existing unrelated destinations. It stages names as hidden siblings before the final move and performs best-effort rollback after failures. Folder descendants are not recursively renamed.
