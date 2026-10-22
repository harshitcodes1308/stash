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

## Visual correction pass

The first 2.7 shell combined the native `NSPanel` shadow with a large SwiftUI shadow, used an `ultraThinMaterial`, and imposed a 420×360 initial frame with a 250-point minimum height. That produced a duplicate-looking outer silhouette, excessive wallpaper color bleed, and an oversized empty shelf.

The corrected shell disables the native panel shadow and retains one restrained rounded SwiftUI shadow. It uses `regularMaterial` plus an adaptive `NSColor.windowBackgroundColor` tint, preserving translucency while suppressing strong wallpaper saturation. New empty shelves open at 360×220 points with a 340×200 minimum; inner padding, toolbar controls, footer spacing, icon size, and drop surface were reduced. Previously persisted pinned frames are not resized.

The header also includes an explicit Expand Shelf control. It grows the current shelf to at least 560×420 points while keeping it within the active screen, then restores the exact pre-expansion frame when toggled again. Manual resizing remains available, Reduce Motion controls the frame animation, and pinned shelves persist the resulting frame.

An actual window capture reported a 360×222 rendered window. Direct and compositor captures showed one rounded shelf silhouette and a neutral surface over the active background. Finder drag/drop, manual resizing, pinned frame behavior, appearance variants, and populated overflow still require user GUI verification.

## Populated shelf correction

The shelf's existing free-resize behavior, frame limits, expand/restore control, and pinned-frame persistence remain unchanged. Populated content now uses adaptive 82–108-point columns with 48-point previews and lightweight tile surfaces. Filenames have a fixed one-line caption with middle truncation, plus the complete name in the tooltip and accessibility label.

File previews use `QLThumbnailGenerator` asynchronously. Only visible lazy-grid tiles request thumbnails; disappearing tiles cancel requests. An in-memory cache is bounded by count and approximate memory cost, and keys include standardized path, modification time, file size, and requested dimensions so changed files do not reuse stale previews. Native file icons remain the fallback for unsupported or failed previews.

Removal buttons now appear only on hover or selection. Removal remains available without hover through a contextual menu and a named accessibility action. The scroll view has explicit minimum/maximum sizing and higher layout priority between the fixed header and footer, preventing tiles from extending beneath footer controls without resizing the window automatically.

The thumbnail regression creates and modifies a disposable PNG, verifies asynchronous Quick Look output, and confirms that the modified file receives a fresh cached representation. Layout checks for 1, 4, 10, 25, and 50 items in manually resized shelves still require a real GUI pass.

## Tile drag correction

Whole-background panel dragging competed with SwiftUI's native item drag gesture, causing attempts to drag an image to move the entire shelf. The panel no longer uses `isMovableByWindowBackground`. A compact AppKit drag handle in the header calls `performDrag(with:)` and is now the deliberate shelf-movement surface. Thumbnail imagery ignores hit testing so pointer drags resolve to the tile's existing `NSItemProvider` file payload; selection, removal, and other header controls retain their own hit targets.
