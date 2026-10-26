# Notch workspace tabs

New Stash (including the global shortcut) creates a tab in the notch workspace. Show Current Stash and Open Notch Workspace open the selected tab and keep the workspace open until dismissed.

Each tab owns a separate shelf controller, file collection, selection, and action state. The horizontal tab strip shows names and item counts. Use + to create a tab, its name to switch, and its small close button to remove it from this session. The header close button collapses the entire workspace without removing tabs.

Pin the selected tab using the header pin button to retain it across launches. Pinned tabs restore quietly; opening the workspace reveals them. Closing a pinned tab leaves its saved copy available in the menu; unpin it first to stop restoring it.

Smart Action output to New Shelf creates and selects a new tab containing the generated results. Output to Current Shelf updates the source tab. Original file references remain in their original tab.

The tab harness exercises creation with output items, switching independent contents, closing, quiet restoration, and reopening saved tabs using disposable preferences. Real menu clicks, Finder dragging between interactions, and Smart Action sheet completion still require GUI verification.
