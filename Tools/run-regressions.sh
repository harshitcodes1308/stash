#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_root="${TMPDIR:-/tmp}/stash-regressions-$$"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root"
cd "$project_root"

run_harness() {
  local name="$1"
  shift
  swiftc -parse-as-library "$@" -o "$tmp_root/$name"
  "$tmp_root/$name"
}

run_harness action Sources/Stash/Models.swift Sources/Stash/ActionEngine.swift Tools/action-engine-harness.swift
run_harness thumbnail Sources/Stash/Models.swift Sources/Stash/FileThumbnailView.swift Tools/thumbnail-harness.swift
run_harness image Sources/Stash/ImageActionService.swift Tools/image-action-harness.swift
run_harness archive Sources/Stash/ImageActionService.swift Sources/Stash/ArchiveActionService.swift Tools/archive-action-harness.swift
run_harness rename Sources/Stash/Models.swift Sources/Stash/ImageActionService.swift Sources/Stash/RenameActionService.swift Tools/rename-action-harness.swift
run_harness pdf Sources/Stash/Models.swift Sources/Stash/ImageActionService.swift Sources/Stash/ActionEngine.swift Sources/Stash/PDFActionService.swift Tools/pdf-action-harness.swift
swift build -c release
print "PASS: all Stash regression harnesses and release build"
