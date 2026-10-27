# Packaging

Run `./Packaging/build-app.sh` from the project root to compile the existing Swift target and create `build/Stash.app`. Run `./Packaging/package-release.sh` to also make versioned ZIP and Finder-friendly DMG artifacts such as `build/Stash-0.2.0.zip` and `build/Stash-0.2.0.dmg`.

The DMG contains `Stash.app` and an `Applications` shortcut so users can install by dragging Stash into Applications. The build copies `Packaging/Assets/Stash.icns` into the bundle and declares it with `CFBundleIconFile`; the menu bar continues to use a native SF Symbol.

The release script applies an ad-hoc signature for local testing; it is not Developer ID signed or notarized. Public beta releases must be labelled accordingly, as macOS may show a Gatekeeper warning.

For public distribution, use `./Packaging/package-public-release.sh` with `STASH_SIGNING_IDENTITY` and `STASH_NOTARY_PROFILE` set. The script signs the app with hardened runtime, creates the ZIP and DMG, submits the DMG to Apple, staples the result, and validates it. It deliberately fails if either credential setting is missing.
