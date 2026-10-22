# GitHub release checklist

This document prepares the assets and copy for a future public Stash release. It does not authorize publishing an ad-hoc build.

## Release identity

- Tag: `v0.1.1`
- Title: `Stash v0.1.1`
- Primary asset: `Stash-0.1.1.dmg`
- Optional source-build asset: `Stash-0.1.1.zip`
- Release body: `docs/release-notes-v0.1.1.md`

## Upload steps after notarization

1. Run `./Tools/run-regressions.sh`.
2. Set the Developer ID and `notarytool` keychain-profile environment variables described in `docs/release.md`.
3. Run `./Packaging/package-public-release.sh`; it signs the app before creating the DMG, notarizes the DMG, staples the ticket, and validates it.
4. Re-run the signature and DMG checks in `docs/release.md`.
5. Create the `v0.1.1` GitHub Release and upload the notarized `build/Stash-0.1.1.dmg`.
6. Paste `docs/release-notes-v0.1.1.md` as the release notes.
7. Mark the release public only after the manual QA checklist has passed.

## README download link

Once a verified release exists, the README download destination is:

`https://github.com/harshitcodes1308/stash/releases/latest`

Do not link to a versioned DMG until that asset has been uploaded to the corresponding GitHub Release.
