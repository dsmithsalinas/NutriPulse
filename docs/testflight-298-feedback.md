# Build 298 screenshot feedback

Reviewed both new App Store Connect screenshot reports from 1.3.3 (298), iPhone
18 Pro, iOS 27.0.1. The screenshot images and tester details remain outside source.

## Save a usual meal

The screenshot shows the empty name field's “My usual breakfast” placeholder.
The view initializes the name to an empty string and disables Save for empty names,
without explaining the disabled state. This explains the pictured inactive button;
it does not establish a backend save failure.

New meals now begin with an editable, actual suggested name: the food name for a
single entry, or “My usual [meal]” for a combination/oversize food name. A visible
Meal name label and inline validation explain empty and overlong names. Rename
preserves the saved name, and reappearance no longer resets typed edits. Valid names
are trimmed consistently with the stored model. Existing ownership and save rules remain.

## Skipped-shot card

The screenshot requests a way to clear the persistent “Shot marked as skipped” card.
Home now offers an accessible × action that dismisses only that presentation. A local
record keeps one dismissed skip ID per account; future skip IDs remain visible and
account switching preserves each account's choice. The skip record, reminder date,
actual injection history and Undo in shot history are unchanged. Due-shot prompts
retain their separate behavior.

Reviewed locally, then authorized for inclusion in TestFlight 1.3.4.

Validation: complete simulator suite passed: 479 executed, 472 passed, seven opt-in
live checks skipped, zero failures. Five new regressions cover suggested names,
empty/overlong validation, per-account dismissal, future skips and unchanged reminder
schedule. This is not a signed-in server-save or physical-device check.
