# Stash 0.2.0 release guide

## Build the local release candidate

```zsh
./Tools/run-regressions.sh
./Packaging/package-release.sh
codesign --verify --deep --strict --verbose=2 build/Stash.app
open -n build/Stash.app
```

Artifacts: `build/Stash.app`, `build/Stash-0.2.0.zip`, `build/Stash-0.2.0.dmg`, and `build/Stash-0.2.0.dmg.sha256`.

Before sharing either artifact, inspect the archive contents and signature:

```zsh
unzip -l build/Stash-0.2.0.zip
hdiutil verify build/Stash-0.2.0.dmg
codesign -dv --verbose=4 build/Stash.app
cd build && shasum -a 256 -c Stash-0.2.0.dmg.sha256
```

The archive must contain only the application bundle and normal macOS archive metadata. It must not contain `.build`, source files, test fixtures, user files, or credentials. The DMG must contain only `Stash.app` and the `Applications` shortcut.

## Signing and notarization

The checked-in packaging process produces a valid **ad-hoc** local signature inside both `Stash.app` and the ZIP. It is not Developer ID signed and is not notarized. Public downloads may trigger Gatekeeper warnings.

For public distribution, a release maintainer must sign with a valid Developer ID Application certificate, submit the ZIP or DMG to Apple notarization with `notarytool`, staple the resulting ticket, then repeat signature and launch checks. Do not advise users to bypass Gatekeeper.

The public command is intentionally separate from the local ad-hoc builder:

```zsh
export STASH_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export STASH_NOTARY_PROFILE='stash-notary'
./Packaging/package-public-release.sh
```

`STASH_NOTARY_PROFILE` must refer to a preconfigured `notarytool` keychain profile. Do not commit certificate files, API keys, or passwords. The public script signs the app before placing it in the DMG, notarizes the DMG, staples the ticket, and validates the result.

## Public beta limitations

- The MIT `LICENSE` is present. Keep its copyright notice intact in distributed source archives.
- Capture and review real product screenshots, including a populated shelf with image thumbnails.
- Complete the GUI checklist in `docs/manual-qa.md`, including multiple displays and a real locked PDF.
- A Developer ID certificate and notarization credentials are required for a trusted macOS download. The public beta is explicitly labeled as unnotarized.

Stash remains unsandboxed to retain direct Finder file access. A future sandboxed distribution needs security-scoped bookmark design and regression testing before enabling App Sandbox.

## GitHub beta release

Suggested repository description:

> A native macOS floating shelf for collecting files, links, and quick local file actions.

Suggested topics: `macos`, `swift`, `swiftui`, `appkit`, `file-management`, `productivity`, `menu-bar-app`, `drag-and-drop`, `quicklook`.

Use the GitHub pre-release title **Stash v0.2.0** and [release-notes-v0.2.0.md](release-notes-v0.2.0.md) as the release body. Attach the DMG and its checksum there, and keep the pre-release labelled ad-hoc signed and not notarized until a Developer ID build replaces it. Do not commit the DMG into Git history.
