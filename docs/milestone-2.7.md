# Milestone 2.7: Liquid Glass shelf redesign

## Window shell

The floating `NSPanel` is now transparent and non-opaque, uses the native window shadow, hides standard traffic-light controls, removes its title-bar separator, and remains background-draggable and resizable. SwiftUI supplies a continuous 28-point rounded material shell with a layered environmental highlight, adaptive border, restrained indigo drag glow, and outer depth. The panel level, Spaces behavior, focus, persistence, and clamped frame restoration remain unchanged.

## Adaptive tiles and interactions

The previous vertical utility rows are replaced by a bounded adaptive `LazyVGrid`. Each compact tile shows a native file icon, two-line filename, type/missing state, persistent remove affordance, tooltip, and VoiceOver description. Hover adds a 1.03 scale, slight lift, brighter surface, and deeper shadow; selection uses a distinct indigo fill/border and elevation. Native `NSItemProvider` drag-out and stable `ShelfItem.id` identity are unchanged.

The empty shelf remains a large usable drop target. Valid drag entry scales the shell slightly, strengthens its border/shadow, and changes the empty prompt. Insertions use opacity/scale transitions. A shared set of restrained springs handles hover, selection, insertion, and target changes. Reduce Motion disables scaling, offsets, and spring animation while preserving state feedback.

## Header and action panels

The shelf header is now an integrated floating toolbar with identity symbol, title, count capsule, Smart Actions, pin, and dismiss controls. The footer retains clear/status/selection/hotkey information. All image, ZIP, rename, and PDF panels use a consistent rounded material-card treatment. Filename and rename fields now have explicit visible labels; destructive rename confirmation and PDF ordering controls remain intact.

## Performance and safety

There are no continuous animations or custom blur loops. The grid is lazy and native file icons are requested only for constructed tile views; full-resolution previews are not decoded. No file service, drag payload, action logic, generated-file ownership behavior, or persistence schema changed.

No numeric performance claims are made because Instruments profiling was not performed. Idle CPU, 20+ items, multiple shelves, wallpaper contrast, transparent-corner hit testing, and hover feel require manual GUI inspection.

## Verification and packaging

The unified action, image, ZIP, rename, PDF, generated-output, and persistence regressions must pass after the redesign. Release packaging is version `0.1.1` build `2`, producing `build/Stash.app` and `build/Stash-0.1.1.zip`. The build is ad-hoc signed, not Developer ID signed or notarized.
