# Footing 1.3.4 — TestFlight

Previous live version verified in App Store Connect: **1.3.3 (298)**.
App and widget advance to **1.3.4**. Build number is generated from the release
commit count; bundle IDs and App Group stay unchanged.

## What to test

- Save a usual meal after logging food. The name field starts with an editable real
  suggestion and Save is available for valid entries. Clear the name to see the
  inline explanation; try renaming an existing usual meal.
- Dismiss the skipped-shot Home card with ×. Confirm it stays hidden after reopening
  the app while the skip and next reminder remain in shot history. Undo remains
  available in history. A future skipped shot should show its own card.

Validation: 479 simulator tests executed, 472 passed, seven optional live checks
skipped, zero failures. Five regressions cover suggested names, validation,
account-specific dismissal, future skip IDs and reminder preservation. Live saving
and physical-device behavior remain part of TestFlight verification.
