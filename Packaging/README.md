# Packaging

Run `./Packaging/build-app.sh` from the project root to compile the existing Swift target and create `build/Stash.app`.

There is no original Stash icon asset in this repository, so the bundle intentionally uses the standard macOS application appearance until an original `.icns` asset is supplied. The bundle is not code-signed or notarized; Gatekeeper may therefore require an explicit user approval when it is moved to another machine.
