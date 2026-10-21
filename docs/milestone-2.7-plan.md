# Milestone 2.7 plan: glass shelf redesign

## Baseline

The AppKit/SwiftUI boundary remains appropriate: `ShelfWindowController` owns the floating `NSPanel`, while `ShelfView` owns selection and all presentation. File identity, drag payloads, persistence, and action services remain untouched. Baseline action, image, ZIP, rename, PDF, generated-file, and shelf-persistence harnesses pass on macOS 13.

## Planned changes

1. **Glass shell:** make the panel non-opaque with a clear background, native window shadow, invisible title-bar separator, and background dragging. Replace the fixed rectangular SwiftUI surface with a layered material capsule-like container, rounded highlight border, and drag-target glow.
2. **Adaptive geometry:** remove the fixed 330-point content width, establish compact minimum/ideal sizes, keep user resizing authoritative, and constrain item content with scrolling.
3. **File tiles:** replace rows with an adaptive `LazyVGrid`. Preserve stable `ShelfItem.id`, selection toggles, removal, and `NSItemProvider` drag-out. Tiles use native file icons, two-line truncation, tooltips, missing state, local hover elevation, and distinct selected styling.
4. **Motion:** centralize restrained spring values for insertion, hover, selection, and drag targeting. Disable scale/spring changes when Reduce Motion is enabled.
5. **Header and panels:** integrate Actions into a floating toolbar, retain persistent icon controls, and apply one readable material-card treatment and explicit field labels across all action sheets.
6. **Accessibility/performance:** retain native keyboard controls and VoiceOver labels. File icons are generated only for visible lazy-grid tiles; no full-resolution thumbnails or continuous animations are introduced.
7. **Release:** run the unified regressions, build/sign/package as version `0.1.1` build `2`, verify the app inside the ZIP, and document GUI-only checks.

## Regression boundary

No action service, filesystem semantics, persistence schema, drag payload, global hotkey, menu-bar behavior, window level, or generated-file ownership behavior will be redesigned. Manual GUI verification remains required for transparent-corner hit testing, Finder drag/drop, multiple displays, appearances, VoiceOver, and animation feel.
