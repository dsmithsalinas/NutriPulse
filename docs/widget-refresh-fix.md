# Widget account restoration fix — November 14, 2026

Build 308 could show a centered “Protein — / No Health data” card after relaunch. NutritionImportStore.setAccount unconditionally wrote an unknown snapshot, even with no Health protein source selected. That snapshot remained until Today published another value. The unknown-state view also bypassed every family layout and removed the medium widget's quick actions.

The shared snapshot now has a persisted account binding. Restoring the same account leaves its snapshot intact; an account change, sign-out or migration from an unowned legacy snapshot clears its numbers. Snapshot writes require the current binding, so an in-flight refresh from another account cannot repopulate it. Changing the protein source invalidates protein while retaining goal and dose-button context. Selecting the already-selected source does nothing.

A separate optional needsRefresh flag distinguishes a pending refresh from a completed Health query with no readable protein. Neither state claims zero grams or falls back to local totals for an imported nutrient. All widget families retain their layouts, and medium widgets retain logging controls. Existing snapshots decode without the new optional field.

Verification: 4 WidgetSnapshotTests, 10 NutritionImportTests and 1 WidgetUnavailableUITest passed. Tests use isolated defaults, sample widget fixtures and no real Health queries or data mutations. Screenshot preview uses the same shared view compiled into the widget; device WidgetKit scheduling still needs signed-device acceptance. The focused rerun on November 15 again passed all 15 tests (4 snapshot, 10 Health import, 1 UI). The exported UI screenshot was inspected: the normal widget layouts and quick actions remain visible for both pending refresh and unavailable Health data. The fix is being committed separately for the next combined build; no TestFlight archive or upload has been made.

Verification artifacts: `build/WidgetFixVerified-20261115.xcresult` and `build/WidgetFixVerifiedScreenshots/`.

For build 308, opening Footing's Today screen lets a fresh snapshot replace the erroneous fallback. The code fix requires a future app update.
