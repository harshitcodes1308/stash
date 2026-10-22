#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle_path="$project_root/build/Stash.app"
archive_path="$project_root/build/Stash-0.1.1.zip"

"$project_root/Packaging/build-app.sh"
codesign --force --deep --sign - "$bundle_path"
rm -f "$archive_path"
# A release archive needs the bundle itself, not Finder resource-fork sidecars.
ditto -c -k --norsrc --keepParent "$bundle_path" "$archive_path"
print "Created $archive_path"
