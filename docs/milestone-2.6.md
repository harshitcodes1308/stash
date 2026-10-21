# Milestone 2.6: UI polish, stability, and beta preparation

## Implemented

- Pinned shelf frames now persist separately from shelf data and are clamped to an available visible screen at restore time.
- Shelf rows use native file icons, selected/hover states, filename truncation, missing-file treatment, and improved VoiceOver labels for icon controls and action status.
- The existing single-action gate remains in place; long-running services continue to run off the main UI task and failed staging outputs are removed by their services.
- Added a unified regression runner and reproducible `Stash.app` ZIP packaging script.
- Added README, release instructions, changelog, and a detailed manual QA checklist.

## Retention and security

Generated outputs are durable by policy and are not automatically deleted when a shelf closes. Temporary action workspaces are removed by the image, archive, PDF, and rename flows. No network, analytics, telemetry, sandbox entitlement, or new permissions were introduced. `.gitignore` now excludes common signing credentials and environment files in addition to references and builds.

## Performance

No performance values are claimed: Instruments was not available in this work session. The changes avoid new full-file reads in shelf rendering; native file icons are rendered only for visible lazy rows. PDF/image/ZIP/rename work remains in service tasks rather than the shelf body.

## Verification

Run `./Tools/run-regressions.sh`, then package with `./Packaging/package-release.sh`. The runner compiles and executes the action, image, ZIP, rename, and PDF harnesses, then builds release. Bundle metadata and signatures are verified in the release checklist.

## Remaining manual work

See `docs/manual-qa.md`. GUI drag/drop, external-display restore, VoiceOver, appearance modes, real permission failures, real locked PDFs, and public distribution signing/notarization cannot be confirmed by the command-line harnesses.
