# Milestone 2.3 plan: native ZIP creation

## Technical choice

Stash uses macOS’s bundled `/usr/bin/bsdtar` (libarchive 3.7.4 on the development host) via `Foundation.Process` with an argument array. Foundation has no complete ZIP-writing API, and this avoids a third-party dependency or custom archive encoder. No shell, command string, or filename interpolation is used.

## Architecture

`ArchiveActionService` validates inputs, rejects all symbolic links, plans top-level archive entries, and runs `bsdtar` off the main thread. `GeneratedFileStore` allocates and records a durable collision-safe ZIP path. The service reopens the output with `bsdtar -tf` before reporting success. The existing shelf output routing then adds the ZIP to the current shelf, opens it in a new shelf, or copies it to a user-selected folder.

The implementation now uses an isolated staged input tree and macOS `/usr/bin/zip` with structured arguments for creation; `bsdtar` remains the verifier. This avoids broad common-parent roots and prevents an application-support output path from being traversed with selected input folders.

## UI and scope

The existing Actions menu gains **Create ZIP** for selections consisting only of existing file/folder references. The compact sheet validates the archive name, exposes the real default libarchive compression behavior, lets a single selected directory omit its top-level folder, and reuses the Phase 2 output destination selector.

## Acceptance criteria

The harness will cover file/folder mixes, nested and empty folders, spaces/Unicode, basename collisions, missing files, symlink rejection, source preservation, verification listing, and durable output creation. Existing action and image harnesses will run again. Batch rename and PDF work remain out of scope.
