# Footing 1.3.2 — TestFlight

Previous live TestFlight version reviewed in App Store Connect: **1.3.1 (286)**.

This release increments both the app and widget to **1.3.2**. The build number is generated from the release commit count after saving and integrating the source. Bundle IDs and the App Group remain unchanged so existing installations retain their account and local data.

## What to test

- Return after a logging break without catch-up work; partially logged days remain unknown.
- Take it easier, optional vacation/unwell context, paused goal reminders and available logging/Pulse.
- Familiar-food shortcuts, portion review, undo and offline meal/day notes.
- Pulse attention limits, explicit practical memories and lighter breakfast check-ins.
- Today went sideways: find something, make it easier, or save just a day note.
- Today → Make today easier: small experiments, approved works-for-me library, leftovers and one-decision requests. Experiments, leftovers cards and decision drafts are device-only in this version; notes and approved memories sync with the account.
- Profile → Siri and shortcuts: “Record water in Footing,” “Save a note in Footing,” and “Today went sideways in Footing.” Test spoken parameter collection, confirmation, locked/unlocked operation, account changes, offline saves and removal from water history. A dose shortcut opens the app for review rather than silently logging a dose.

## Release checks

The implementation passed 465 iOS tests (7 opt-in live checks skipped), then all 10 focused checks after final refinements. Earlier signed-in checks for notes, memory ownership and two-account isolation are recorded in the corresponding feature documents. Physical-device Siri behavior is intentionally part of this TestFlight test, not claimed as simulator-verified.

Archive, signing, app/widget version matching, App Intents metadata and Apple upload/processing status are verified separately when preparing this build. This document is not a claim that Apple processing or beta review has completed.
