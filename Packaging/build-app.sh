#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle_path="$project_root/build/Stash.app"
contents_path="$bundle_path/Contents"

cd "$project_root"
swift build -c release

rm -rf "$bundle_path"
mkdir -p "$contents_path/MacOS" "$contents_path/Resources"
cp "$project_root/Packaging/Info.plist" "$contents_path/Info.plist"
cp "$project_root/.build/release/Stash" "$contents_path/MacOS/Stash"
cp "$project_root/Packaging/Assets/Stash.icns" "$contents_path/Resources/Stash.icns"
chmod 755 "$contents_path/MacOS/Stash"
plutil -lint "$contents_path/Info.plist"
