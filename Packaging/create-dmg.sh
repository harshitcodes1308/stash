#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle_path="$project_root/build/Stash.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_root/Packaging/Info.plist")"
dmg_path="$project_root/build/Stash-$version.dmg"
staging_path="$(mktemp -d "${TMPDIR:-/tmp}/stash-dmg.XXXXXX")"

cleanup() {
  rm -rf "$staging_path"
}
trap cleanup EXIT

if [[ ! -d "$bundle_path" ]]; then
  print -u2 "Missing $bundle_path. Run Packaging/package-release.sh first."
  exit 1
fi

ditto --norsrc "$bundle_path" "$staging_path/Stash.app"
ln -s /Applications "$staging_path/Applications"
rm -f "$dmg_path"
hdiutil create \
  -volname "Stash" \
  -srcfolder "$staging_path" \
  -format UDZO \
  -ov \
  "$dmg_path" >/dev/null
hdiutil verify "$dmg_path" >/dev/null
print "Created $dmg_path"
