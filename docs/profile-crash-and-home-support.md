# Profile crash and Home support placement

Fix following TestFlight 1.3.2 (296), prepared and reviewed locally before the owner authorized inclusion in TestFlight 1.3.3.

## Evidence

The submitted October 19 crash feedback for build 296, iPhone 18 Pro, iOS 27.0.1 reports `EXC_BAD_ACCESS / KERN_PROTECTION_FAILURE` in the main-thread Stack Guard region. The stack region is about 1 MB. The app frames lead through `__swift_instantiateConcreteTypeFromMangledNameV2`, `ProfileView.pulseTile`, and `ProfileView.body` while building the settings screen. This supports view-type metadata/stack exhaustion rather than a failed account fetch. Unrelated framework symbol names in the supplied symbolicated trace should not be interpreted as additional user actions.

The unchanged Debug screen opens in the iOS 27 simulator: visual success there alone was insufficient. The added footprint regression initially failed against the unchanged source: Profile’s root view value occupied 30,648 bytes. The fixed root occupies 88 bytes. These are root-value sizes, not total stack usage or app-memory measurements.

## Fix

Profile now builds highlights, coaching, health and support as separate fixed sections. Deliberate `AnyView` boundaries isolate those sections and the lifecycle/editor/notice/confirmation modifier layers. This prevents the entire generic settings tree from propagating through every root modifier. The sections are fixed in identity/order; this is not type erasure in a dynamic list. Pulse toggles, permissions, dialogs, editors, account actions and Siri remain present.

The regression resolves Profile’s root metadata on a 1 MB worker stack, without doing UIKit work off the main thread, and caps its root-value footprint. A separate main-actor hosting test renders Profile three times with accessibility-sized text. An optimized simulator run supplements those checks; physical-device confirmation remains for a later authorized build.

## Home

Both normal and lighter tracking place **Today went sideways** and **Make today easier** immediately below water logging. Neither appears below the date header anymore. The former “Need a lighter week?” shortcut is labeled **Take it easier**, matching Profile and the destination sheet, with the explanation “Pause goal reminders for a few days or longer.” The setting shortcut is hidden while lighter tracking is active, where the existing management control already serves that purpose.

- Today went sideways: help with right now, or leave a note.
- Make today easier: experiments, leftovers, a practical-memory library and one-decision help; does not switch tracking mode.
- Take it easier: persistent tracking preference with optional context/duration; pauses goal reminders while logging and Pulse remain available.

Read-only `--store-today --lighter-preview` uses the production Home layout with a lighter-tracking fixture. Fixture state is in memory only; no real account setting is written.

## Verification

- Full simulator suite: 474 executed, 467 passed, seven opt-in live checks skipped, zero failures.
- App-target optimized Profile checks: two passed, including repeated large-text rendering and the root-footprint regression.
- Regular Home, lighter Home and Profile screenshots inspected.
- `git diff --check` passed; the generated project was restored to its normal settings after the optimized check.

A global optimization override hit a Swift compiler crash in the third-party IssueReporting package. The successful optimized check instead applied `-O` only to the Footing app target. No dependency source was changed. No version increment, archive or upload was performed.
