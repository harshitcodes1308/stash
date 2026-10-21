# MASTER BUILD PROMPT: STASH
## Build a Production-Quality, Open-Source macOS Floating File Shelf

You are acting as a senior macOS engineer, reverse-engineering specialist, product designer, and open-source maintainer.

Your task is to research, architect, implement, test, and package a genuinely useful native macOS application called **Stash**.

Stash is inspired by the workflow of applications such as Dropover, but it must be an independently implemented, original, open-source product.

**The objective is not to create a visual clone. The objective is to understand the underlying user problem, learn from established interaction patterns, and build a faster, cleaner, more capable solution that users would actually install and use every day.**

I have the Reverse Engineering Anything (REA) skill available in my Codex environment. I can also provide the DMG installer for the reference application.

You must use the available skill where appropriate, following its actual instructions and capabilities. Do not invent REA commands, assume it can do something it cannot, or claim to have analyzed files you haven't inspected.

---

# 1. Product Vision

Build the ultimate lightweight, local-first floating file shelf for macOS.

Users should be able to temporarily collect and manipulate:

- Files and folders
- Screenshots and images
- Text snippets
- URLs
- Code snippets
- Multiple mixed items

The app must feel like a natural extension of macOS rather than a browser application disguised as a desktop utility.

The experience should be fast, polished, intuitive and visually distinctive.

Core product principles:

1. Zero friction between capturing and using content.
2. Native macOS interactions.
3. Minimal memory and CPU overhead.
4. No account required.
5. No subscription.
6. No unnecessary cloud services.
7. Privacy by default.
8. Reliable drag-and-drop functionality.
9. Reversible operations wherever possible.
10. Open-source from the beginning.

The app must provide real functionality, not mock buttons, fake interactions, or simulated features presented as complete.

---

# 2. Reference Application Analysis Using REA

Before implementing the product, inspect the reference application.

I will provide the original application's DMG path.

Ask for the path only if it cannot be located in the workspace.

## Step 1: Inspect the environment

Determine:

- Whether the REA skill is installed and accessible.
- What instructions and analysis capabilities it provides.
- Whether the DMG is available.
- Which macOS development tools are installed.
- The host's macOS version and architecture.
- Whether Xcode and Swift tooling are available.

Read the actual REA skill instructions before using it.

Do not execute an unfamiliar binary simply because it appears in the DMG.

## Step 2: Analyze the reference

Start with non-invasive, read-only inspection of the DMG and application bundle.

Where permitted, inspect:

- Bundle metadata and Info.plist
- Declared entitlements
- Application resources
- Supported file types
- Publicly exposed application behavior
- Documented keyboard shortcuts
- Accessibility-visible UI structure
- Window behavior
- Drag-and-drop interactions
- Shelf creation and dismissal
- File collection and retrieval
- Menu-bar behavior
- Preferences and customization

If the reference application can be safely run in an authorized environment, observe its normal user-facing behavior.

Document the interaction flows and relevant technical constraints.

Do not bypass licensing, DRM, code signing, authentication, or other security controls.

Do not extract or reuse proprietary source code, icons, illustrations, branding, or other protected assets.

Do not redistribute the reference DMG or bundle.

Do not reproduce its internal implementation. Use the analysis to understand product behavior and build original functionality using public macOS APIs.

## Step 3: Create a research report

Produce:

`docs/reference-analysis.md`

Include:

1. Features observed directly.
2. Features inferred but not verified.
3. Key user journeys.
4. Interaction patterns worth learning from.
5. Limitations and usability problems.
6. Opportunities for differentiation.
7. macOS API requirements.
8. Legal and technical boundaries.
9. Features selected for Stash.
10. Features intentionally excluded.

Clearly distinguish observed facts from assumptions.

Do not proceed as though reverse engineering has succeeded if the DMG cannot be inspected.

If inspection is blocked, document the limitation and continue with an original implementation based on publicly documented behavior.

---

# 3. The Core Experience

Stash must support three primary ways of creating a shelf.

## A. Shake-to-Stash

The user drags a file and shakes the cursor horizontally.

A small floating shelf appears near the cursor.

The user drops the file onto the shelf.

Requirements:

- Detect the gesture reliably.
- Avoid accidental activation.
- Support configurable sensitivity.
- Provide visual feedback.
- Respect existing macOS drag behavior.
- Do not interfere with ordinary Finder operations.

Investigate whether this can be implemented reliably using supported macOS APIs.

Do not promise universal drag interception if macOS does not permit it.

If reliable shake detection is not feasible, implement a documented fallback.

## B. Hotkey-to-Stash

A configurable global shortcut opens the shelf.

Default proposed shortcut:

`Control + Option + Space`

Users can drag files into the opened shelf.

The shortcut must be configurable and must not override existing shortcuts without user consent.

## C. Edge-to-Stash

When dragging an item toward a configurable screen edge, a small shelf target becomes available.

Requirements:

- Support multiple monitors.
- Avoid accidental triggers.
- Respect full-screen applications.
- Avoid obstructing the Dock and menu bar.
- Allow users to disable this behavior.

If reliable drag-state detection is unavailable, use an explicit edge activation zone rather than unsupported global event interception.

---

# 4. Core Shelf Features

## 4.1 Floating Shelf

Build a native floating window with:

- Rounded corners.
- Subtle material background.
- Smooth animations.
- File thumbnails.
- Item count.
- Drag-and-drop support.
- Clear dismissal behavior.
- Expand and collapse controls.
- Optional always-on-top behavior.

Users must be able to create multiple shelves.

Each shelf should be independently movable and dismissible.

## 4.2 File Collection

Support dragging:

- Individual files.
- Multiple files.
- Folders.
- Images.
- URLs.
- Plain text.
- Rich text where practical.

Preserve the original data and file references.

Do not silently duplicate large files when adding them to a shelf.

For external files, use references and appropriate security-scoped access where necessary.

## 4.3 Dragging Items Out

Users must be able to drag an item or selection from Stash into compatible destinations, including Finder and supported third-party apps.

Preserve expected file drag semantics.

Do not substitute a clipboard-only workflow for actual file dragging.

## 4.4 Shelf Lifecycle

Support:

- Temporary shelves.
- Pinned shelves.
- Multiple shelves.
- Shelf renaming.
- Shelf clearing.
- Shelf dismissal.
- Session restoration for pinned shelves.

Temporary shelves should disappear when explicitly dismissed or when an optional expiration rule applies.

Pinned shelves must persist across app restarts.

---

# 5. Original Features That Make Stash Different

These features are central to the product.

## Feature 1: Smart Actions

Stash should understand the types of items inside a shelf and suggest relevant actions.

Examples:

When a user drops five images:

- Convert to PNG, JPEG, or WebP.
- Resize images.
- Rename sequentially.
- Compress images.
- Create a ZIP archive.

When a user drops several PDFs:

- Merge PDFs.
- Extract selected pages.
- Combine them into a ZIP.
- Rename them.

When a user drops a URL:

- Copy the clean URL.
- Open it in the browser.
- Save it as a `.webloc` file.

When a user drops text:

- Convert to a text file.
- Copy as plain text.
- Save as Markdown.
- Remove unnecessary whitespace.

These actions must be real and implemented using local APIs.

Do not require AI for deterministic operations.

**Unique interaction:** The shelf dynamically presents only the actions relevant to its contents.

## Feature 2: Quick Collections

Users can save reusable shelves for recurring workflows.

Examples:

- Design Assets
- University Assignments
- Screenshots
- Development Files
- Documents to Send

Users can pin collections and reopen them from the menu bar or command palette.

## Feature 3: Smart Batch Rename

Allow users to rename multiple files using:

- Prefixes and suffixes.
- Sequential numbering.
- Date patterns.
- Search and replace.
- File extensions.
- Regular expressions, if practical.

Show a before-and-after preview.

Detect collisions before applying changes.

Never overwrite files silently.

## Feature 4: Shelf Recipes

Allow users to combine supported actions into reusable workflows.

Example recipe:

`Images → Resize to 1600px → Convert to WebP → Compress → Export`

Another example:

`PDFs → Merge → Rename → Save to Downloads`

Recipes must:

- Be user-created.
- Be editable.
- Support previews.
- Have clear error handling.
- Be reusable across shelves.
- Avoid destructive operations without confirmation.

Build the recipe engine using typed, deterministic actions.

Do not create an unnecessarily complex visual automation canvas in the MVP.

## Feature 5: Smart Cleanup

Users should be able to identify temporary items that are no longer needed.

Support:

- Shelf expiration.
- Clearing temporary references.
- Removing expired pinned items from Stash.
- Identifying missing file references.
- Finding duplicate references inside a shelf.

**Critical:** Clearing a shelf must never delete the user's original files.

Deletion of original files must not be part of the default cleanup workflow.

## Feature 6: Keyboard-First Control

Users should be able to:

- Open Stash with a shortcut.
- Navigate items using the keyboard.
- Search shelf contents.
- Trigger quick actions.
- Switch between shelves.
- Pin and unpin shelves.
- Dismiss shelves.

Build a compact command palette specifically for Stash.

It should search Stash commands and existing shelves, not attempt to become a general Raycast replacement.

## Feature 7: Local-First Privacy

All shelf metadata should remain local.

No telemetry by default.

No cloud account.

No automatic uploads.

No remote AI processing.

Use local storage for metadata and preferences.

Make file access permissions transparent.

---

# 6. Technical Architecture

Preferred stack:

- Swift
- SwiftUI
- AppKit
- Foundation
- UniformTypeIdentifiers
- Core Graphics where needed
- Quick Look / Quick Look Thumbnailing
- PDFKit
- ImageIO
- SQLite or another justified native persistence solution

Prefer AppKit for advanced window management, dragging, event handling and native macOS integrations.

Use SwiftUI for modern interface components and settings.

Do not use Electron, React or a webview for the core application.

The goal is a truly native Mac app.

Use a modular architecture.

Suggested modules:

`App`
Application lifecycle, menu bar and initialization.

`ShelfCore`
Shelf models, item references, shelf state and persistence.

`ShelfWindow`
Floating windows, positioning, animations and multi-monitor support.

`DragDrop`
File providers, pasteboard integration, drag sessions and supported content types.

`Actions`
Typed file transformations and smart action discovery.

`Recipes`
Reusable action sequences and execution.

`Storage`
Local database, preferences and session restoration.

`Shortcuts`
Global and in-app keyboard shortcuts.

`Utilities`
Logging, validation, error handling and file coordination.

These are suggested boundaries, not mandatory file names. Adapt them when a simpler structure is more appropriate.

---

# 7. UI and Design Direction

The UI should feel like a first-party macOS utility.

Design principles:

- Minimal.
- Refined.
- Fast.
- Lightweight.
- Distinctive.
- Native.
- Accessible.

Avoid generic AI-generated dashboard aesthetics.

Avoid excessive gradients, oversized cards and decorative visual clutter.

Use macOS materials, native typography and consistent spacing.

## Floating Shelf

The collapsed shelf should be compact and unobtrusive.

When expanded, it should reveal:

- Item thumbnails.
- File names.
- File types.
- Item count.
- Quick actions.
- Pin control.
- More actions menu.

Support both light and dark appearance.

Use subtle animations that respect Reduce Motion settings.

## Visual Identity

Create an original app icon and brand identity.

Do not reuse the reference application's icons or artwork.

The working name is Stash, but keep branding configurable.

## Menu Bar

The menu-bar interface should provide:

- Open new shelf.
- Show pinned shelves.
- Recent shelves.
- Preferences.
- Quit.

## Settings

Include:

- Startup at login.
- Global shortcut.
- Shelf appearance.
- Shake sensitivity, if supported.
- Edge activation, if supported.
- Shelf expiration.
- Default export directory.
- Accessibility and permission status.
- Privacy information.

---

# 8. Safety and File Integrity

File safety is a non-negotiable requirement.

Implement:

1. No silent deletion of original files.
2. No silent overwriting.
3. Explicit confirmation for destructive actions.
4. Clear export destinations.
5. Collision handling.
6. Atomic writes where practical.
7. Temporary-file cleanup.
8. Appropriate security-scoped file access.
9. Symlink-aware path handling.
10. Graceful behavior when files are moved or deleted externally.

For file conversions, write to a new destination unless the user explicitly chooses otherwise.

Handle malformed files, unsupported formats, permission failures and partial operation failures.

For long-running operations, show progress and support cancellation where practical.

Do not execute arbitrary shell commands based on file names or imported metadata.

---

# 9. Performance Requirements

The app should be responsive even when a shelf contains many files.

Targets:

- Minimal idle CPU usage.
- Low idle memory usage.
- Fast shelf activation.
- Smooth scrolling.
- Asynchronous thumbnail generation.
- Lazy loading for large collections.
- No blocking file operations on the main thread.

Treat numerical performance goals as targets to measure, not guarantees.

Use Instruments or appropriate profiling tools when available.

Test with:

- Small text files.
- Large video files.
- Hundreds of images.
- Nested folders.
- Mixed file types.
- Missing file references.
- Multiple monitors.
- Retina and non-Retina displays.

---

# 10. Build Phases

Do not attempt to implement everything simultaneously.

## Phase 0: Research and Feasibility

- Read the REA skill.
- Inspect the reference DMG.
- Document observable workflows.
- Validate macOS API feasibility.
- Create the architecture.
- Identify permissions and limitations.
- Define the MVP.

Deliver the reference analysis and architecture documentation.

## Phase 1: Working Native MVP

Implement:

- Menu-bar application.
- Global hotkey.
- Floating shelf window.
- File and text drag-and-drop.
- Multiple item support.
- Dragging items back out.
- Pinning and dismissing shelves.
- Local persistence for pinned shelves.
- Basic settings.

**Do not proceed until the core file shelf works end to end.**

## Phase 2: Smart Actions

Implement:

- Contextual action discovery.
- Image conversion.
- Image resizing.
- ZIP creation.
- PDF merging.
- Batch rename with preview.
- Safe export handling.

## Phase 3: Original Differentiators

Implement:

- Quick Collections.
- Shelf Recipes.
- Command palette.
- Shelf expiration.
- Improved keyboard navigation.

## Phase 4: Advanced macOS Integration

Investigate and implement where technically feasible:

- Shake-to-Stash.
- Edge-to-Stash.
- Multi-monitor improvements.
- Full-screen compatibility.
- Startup at login.
- Performance optimization.

Do not make advanced activation gestures a dependency for the MVP.

## Phase 5: Open-Source Release

Prepare:

- GitHub repository.
- README.
- Screenshots.
- Demo GIF or video.
- Build instructions.
- Contribution guidelines.
- Code of Conduct.
- Security policy.
- Changelog.
- License.
- Release workflow.
- DMG packaging.

Use an appropriate permissive open-source license, such as MIT, for original code and assets where legally appropriate.

Check dependency licenses before release.

---

# 11. Testing and Acceptance Criteria

Implement automated tests wherever practical.

Test:

- Shelf creation and dismissal.
- Dragging files into shelves.
- Dragging files out.
- Multiple-item selection.
- Text and URL handling.
- Pinning and restoration.
- File reference persistence.
- Image transformations.
- PDF operations.
- Rename collisions.
- Recipe execution.
- Permission failures.
- Missing files.
- Multiple displays.

The MVP is complete only when:

1. The app launches successfully on the target macOS version.
2. A user can create a shelf.
3. A user can drop a real file into it.
4. The file appears with appropriate metadata.
5. The user can drag the file back into Finder.
6. The original file remains unchanged.
7. The user can pin a shelf.
8. Pinned shelves survive an app restart.
9. The global shortcut works.
10. The app can be quit cleanly.
11. The project builds reproducibly.
12. There are no known critical file-loss issues.

Do not mark acceptance criteria as passed without verification.

If GUI testing cannot be performed in the environment, explicitly identify the unverified behaviors and provide a manual test plan.

---

# 12. Open-Source Quality

This must be a legitimate open-source project, not a generated code dump.

Requirements:

- Clear architecture.
- Readable source code.
- Minimal dependencies.
- Useful documentation.
- No committed secrets.
- No proprietary reference-app assets.
- No unnecessary external services.
- No hardcoded local machine paths.
- No undocumented installation steps.
- Clear supported macOS versions.
- Accessibility support.
- Transparent permissions.
- Reproducible builds.

Do not include the reference DMG or any extracted proprietary content in the repository.

For distribution, document code signing and notarization requirements.

Do not claim that a release is notarized unless notarization has actually succeeded.

---

# 13. Execution Instructions

You are not merely preparing a concept document. You are responsible for implementing the application.

Start by inspecting the existing workspace.

Then:

1. Read the available REA skill instructions.
2. Locate and inspect the provided DMG.
3. Identify the macOS development environment.
4. Produce the reference analysis.
5. Propose the technical architecture.
6. Create a prioritized implementation plan.
7. Scaffold the native application.
8. Implement Phase 1.
9. Build the application.
10. Run available tests.
11. Fix compilation and functional issues.
12. Document the actual results.
13. Continue into subsequent phases when the MVP is stable and the environment permits.

Use the tools available in the environment.

Do not stop after generating a README or architecture proposal.

Do not replace implementation with pseudocode.

Do not fabricate screenshots, benchmarks, test results, or working functionality.

When a tool or permission is unavailable, state the blocker and continue with the parts that can be completed safely.

Avoid unnecessary questions. Make reasonable engineering decisions and document them.

Preserve working code during iteration.

Do not rewrite functional modules without a clear reason.

At the end of each phase, report:

- What was implemented.
- What was tested.
- What works.
- What remains unverified.
- Known limitations.
- The next engineering milestone.

# Final Objective

Ship an original, polished, genuinely useful macOS utility that people can install and immediately understand.

**Stash should make moving, collecting, transforming and reusing files on macOS feel effortless.**

Prioritize excellent core functionality over an inflated feature list.

Build the product, not just the demo.