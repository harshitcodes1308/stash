# Packaging

Run `./Packaging/build-app.sh` from the project root to compile the existing Swift target and create `build/Stash.app`. Run `./Packaging/package-release.sh` to also make `build/Stash-0.1.1.zip` and the Finder-friendly `build/Stash-0.1.1.dmg`.

The DMG contains `Stash.app` and an `Applications` shortcut so users can install by dragging Stash into Applications. There is no original Stash icon asset in this repository, so the bundle intentionally uses the standard macOS application appearance until an original `.icns` asset is supplied.

The release script applies an ad-hoc signature for local testing; it is not Developer ID signed or notarized. Do not distribute it publicly until the signing and notarization steps in `docs/release.md` are complete.

For public distribution, use `./Packaging/package-public-release.sh` with `STASH_SIGNING_IDENTITY` and `STASH_NOTARY_PROFILE` set. The script signs the app with hardened runtime, creates the ZIP and DMG, submits the DMG to Apple, staples the result, and validates it. It deliberately fails if either credential setting is missing.
