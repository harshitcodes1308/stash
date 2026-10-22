# Stash 0.1.1 release guide

## Build the local release candidate

```zsh
./Tools/run-regressions.sh
./Packaging/package-release.sh
codesign --verify --deep --strict --verbose=2 build/Stash.app
open -n build/Stash.app
```

Artifacts: `build/Stash.app`, `build/Stash-0.1.1.zip`, and `build/Stash-0.1.1.dmg`.

Before sharing either artifact, inspect the archive contents and signature:

```zsh
unzip -l build/Stash-0.1.1.zip
hdiutil verify build/Stash-0.1.1.dmg
codesign -dv --verbose=4 build/Stash.app
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

## Publication blockers

- Choose and add an open-source `LICENSE`; none currently exists.
- Capture and review real product screenshots, including a populated shelf with image thumbnails.
- Complete the GUI checklist in `docs/manual-qa.md`, including multiple displays and a real locked PDF.
- Obtain Developer ID signing and notarization credentials.

Stash remains unsandboxed to retain direct Finder file access. A future sandboxed distribution needs security-scoped bookmark design and regression testing before enabling App Sandbox.

## GitHub release preparation (do not publish yet)

Suggested repository description:

> A native macOS floating shelf for collecting files, links, and quick local file actions.

Suggested topics: `macos`, `swift`, `swiftui`, `appkit`, `file-management`, `productivity`, `menu-bar-app`, `drag-and-drop`, `quicklook`.

Prepare the GitHub release title as **Stash v0.1.1** and use [release-notes-v0.1.1.md](release-notes-v0.1.1.md) as the release body. Do not create a public release, upload the ZIP, or claim public availability until the blockers above are closed.
