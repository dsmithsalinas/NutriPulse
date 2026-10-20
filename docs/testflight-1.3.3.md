# Footing 1.3.3 — TestFlight

Previous live TestFlight version reviewed in App Store Connect: **1.3.2 (296)**.
The app and widget both advance to **1.3.3**; the build number is generated from
the release commit count. Bundle IDs and the App Group remain unchanged.

## Changes and what to test

- Open Profile repeatedly, including at larger text sizes. The device stack-exhaustion
  fix splits the settings view into bounded sections while preserving its controls.
- Home places **Today went sideways** and **Make today easier** below water logging
  in both normal and lighter tracking.
- **Take it easier** replaces the ambiguous “Need a lighter week?” shortcut. It pauses
  goal reminders for a stretch; Make today easier opens practical tools on demand.
- Pulse uses the approved Ready, Listening, Thinking, Coaching and Check-in rings in
  its header, replies, waiting row, Talk to Log and optional Home prompt. Listening
  follows actual microphone capture; Thinking follows in-flight requests. Rings stay static.
- The approved lime-window Cove app icon and living-dot wordmark replace the older
  product branding. Pulse keeps its separate faceless ring. App assets match the
  approved masters in `marketing/brand/current/`, including the reversed wordmark.
- Recheck Siri water capture, notes and Off-script on a physical phone. These existing
  features are retained; screenshots do not verify microphone or live network behavior.

## Validation

The Profile fix previously passed the complete suite (467 passed, seven opt-in live
checks skipped) and two app-target optimized rendering checks. The ring integration
passed both Profile checks; chat, waiting, listening and parsing screenshots were
visually inspected using Debug-only fixtures. The final 1.3.3 simulator suite executed
474 tests: 467 passed, seven opt-in live checks skipped, zero failures. Archive signing,
versions, Siri metadata and Apple processing are verified during release preparation.

The icon is the unmodified approved 1024×1024 opaque PNG. Current app icon and both
wordmark images were checked byte-for-byte against their approved marketing masters.
