# Footing 1.3.7 — TestFlight

Previous verified TestFlight release: 1.3.6 (302). This release advances app and widget to 1.3.7, with expected git-derived build 303.

## Included

- Shared optional restaurant selection across Search and Talk for the current entry.
- Restaurant-versus-seasoning clarification for ambiguous Chipotle descriptions, conflict handling, and ingredient checklists for customizable meals.
- Explicit ingredient inclusions/exclusions, custom additions, real provider food and serving validation, honest restaurant/generic/estimate labels, and deliberate estimate acceptance.
- Keyboard-safe restaurant selection, Talk input and custom ingredient editing, including a fixed Add/Review area and compact header while typing.
- Optional per-person Medications setup in Profile, Today Taken/Skipped logging, schedules, history/corrections and notification actions. History is preserved when the feature is turned off.

## Validation and rollout

Restaurant checks: 13 backend contract tests, six native state tests, and two keyboard UI tests on each of iPhone 17 Pro and iPhone SE (iOS 26.5). Live disposable-account checks pass for consent, ambiguity, scoped search, confirmed composition, provider resolution, old client compatibility and a six-ounce Texas Roadhouse sirloin at quantity one. Test accounts and temporary keys were removed. Medication verification is recorded in `medications-supplements-plan.md`.

The hosted medication migration and additive restaurant endpoints are already deployed; JWT verification and AI consent checks remain enabled. No additional backend migration is needed for this upload. Full release unit results, signed archive/export verification, source commit, upload receipt and observed App Store Connect distribution state belong in `build/TestFlight-1.3.7-303/release-verification.json`.

On-phone acceptance: real dictation and microphone/speech permission behavior, actual keyboard variants, restaurant match/portion review, save/undo, and medication notification actions. Existing physical Apple Health acceptance remains a device check as described in the prior release. Upload success is separate from Apple processing and tester availability; neither is claimed by this source document alone.
