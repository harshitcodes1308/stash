# Milestone 2.6 plan: polish and beta readiness

## Current architecture

Stash is a Swift Package with an AppKit application lifecycle, menu-bar item, Carbon hotkey, and independent floating `NSPanel` shelf controllers. Shelf content and action sheets are SwiftUI. `ShelfStore` persists pinned shelf data in `UserDefaults`; action services create durable generated files in Application Support and expose them through existing shelf/output-destination paths. Disposable command-line harnesses cover all implemented smart actions.

## Risks and priorities

1. **Pinned-window placement (high):** pinned shelf content restores, but its frame does not. Persist a pinned frame and clamp it to a currently available visible display at restore time.
2. **Action feedback and duplicate work (high):** retain the existing action gate and make progress/status language uniform. Do not change action engines.
3. **Keyboard/accessibility and compact UI (medium):** label icon controls, improve selected/hover feedback, make empty and unavailable states clearer, and retain native controls.
4. **Release repeatability (medium):** add one test runner, app ZIP packaging, release documentation, and explicit signing/notarization status.
5. **Retention/cleanup (medium):** retain durable generated files by design, while action services already remove failed staging output. Do not introduce automatic durable-file deletion without user intent.

## Checkpoints

- Baseline and final harness runs, release build, Info.plist lint, code-signature check, and bundle inventory.
- Frame persistence unit coverage using `ShelfStore` encoding and manual multi-monitor tests.
- Focused shelf/UI accessibility refinements with no redesign or action semantics changes.
- Unified `Tools/run-regressions.sh`, deterministic app ZIP, README/release/manual QA/changelog updates.

## Known constraints

No GUI automation is available for this native floating window, so visual, Finder drag/drop, multi-monitor, VoiceOver, and true Developer ID/notarization checks remain manual. No performance numbers will be claimed without Instruments measurement.
