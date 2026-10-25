# GitHub release guide

Stash publishes source-build beta assets on GitHub Releases. Every ad-hoc release must be clearly marked as non-notarized.

## Release identity

- Tag: `v0.2.0`
- Title: `Stash v0.2.0`
- Assets: `Stash-0.2.0.dmg` and `Stash-0.2.0.zip`
- Release body: `docs/release-notes-v0.2.0.md`
- Status: **Pre-release** until it is Developer ID signed and notarized.

## Create an ad-hoc beta release

1. Run `./Tools/run-regressions.sh`.
2. Run `./Packaging/package-release.sh`.
3. Verify the bundle, ZIP, and DMG as described in `docs/release.md`.
4. Create a **pre-release** for the version tag and upload both artifacts.
5. Paste the matching release-notes document and state that the build is ad-hoc signed and not notarized.
6. Promote it to a normal release only after Developer ID signing, notarization, and the manual QA checklist have passed.

## README download link

Release downloads are listed at:

`https://github.com/harshitcodes1308/stash/releases`

Do not link to a versioned DMG until that asset has been uploaded to the corresponding GitHub Release.
