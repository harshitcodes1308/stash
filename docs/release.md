# Beta release process

## Local reproducible artifacts

```zsh
./Tools/run-regressions.sh
./Packaging/package-release.sh
codesign --verify --deep --strict --verbose=2 build/Stash.app
open -n build/Stash.app
```

Artifacts: `build/Stash.app` and `build/Stash-0.1.1.zip`.

## Signing and notarization

The checked-in packaging process produces a valid **ad-hoc** local signature inside both `Stash.app` and the ZIP. It is not Developer ID signed and is not notarized. Public downloads may trigger Gatekeeper warnings.

For public distribution, a release maintainer must sign with a valid Developer ID Application certificate, submit the ZIP or DMG to Apple notarization with `notarytool`, staple the resulting ticket, then repeat signature and launch checks. Do not advise users to bypass Gatekeeper.

## Release blockers

- Choose and add an open-source `LICENSE`; none currently exists.
- Add real product screenshots.
- Complete the GUI checklist in `docs/manual-qa.md`, including multiple displays and a real locked PDF.
- Obtain Developer ID signing and notarization credentials.

Stash remains unsandboxed to retain direct Finder file access. A future sandboxed distribution needs security-scoped bookmark design and regression testing before enabling App Sandbox.
