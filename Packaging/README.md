# Packaging

Run `./Packaging/build-app.sh` from the project root to compile the existing Swift target and create `build/Stash.app`. Run `./Packaging/package-release.sh` to also make `build/Stash-0.1.1.zip`.

There is no original Stash icon asset in this repository, so the bundle intentionally uses the standard macOS application appearance until an original `.icns` asset is supplied. The release script applies an ad-hoc signature for local testing; it is not Developer ID signed or notarized. Do not distribute it publicly until the signing and notarization steps in `docs/release.md` are complete.
