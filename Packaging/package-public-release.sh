#!/bin/zsh
set -euo pipefail

# Required only for a public distribution. Keep certificate credentials in the
# macOS keychain; never place them in this repository or a shell script.
: "${STASH_SIGNING_IDENTITY:?Set STASH_SIGNING_IDENTITY to a Developer ID Application certificate name.}"
: "${STASH_NOTARY_PROFILE:?Set STASH_NOTARY_PROFILE to a notarytool keychain profile.}"

project_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle_path="$project_root/build/Stash.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_root/Packaging/Info.plist")"
archive_path="$project_root/build/Stash-$version.zip"
dmg_path="$project_root/build/Stash-$version.dmg"

"$project_root/Packaging/build-app.sh"
codesign --force --deep --options runtime --timestamp --sign "$STASH_SIGNING_IDENTITY" "$bundle_path"
codesign --verify --deep --strict --verbose=2 "$bundle_path"

rm -f "$archive_path"
ditto -c -k --norsrc --keepParent "$bundle_path" "$archive_path"
"$project_root/Packaging/create-dmg.sh"

xcrun notarytool submit "$dmg_path" --keychain-profile "$STASH_NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
hdiutil verify "$dmg_path"

print "Created and notarized $dmg_path"
print "Created signed source-build archive $archive_path"
