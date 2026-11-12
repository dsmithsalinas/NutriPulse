# Apple Health nutrition import

Implemented locally on 2026-11-11. No push, release build, or backend deployment is part of this change.

## User flow

Profile → Apple Health → Nutrition sources. Nutrition access is a separate, optional read-only HealthKit request for dietary calories, protein, carbohydrates, total fat, and fiber. Existing Health permissions do not automatically opt the user into nutrition imports. The source list discovers readable samples from the past 90 local calendar days. Users choose Footing or one Health source independently for each nutrient. Selected sources remain selectable even if they stop returning samples.

A selected Health source replaces the entire daily Footing total for that nutrient, including history. It does not augment meal entries. A person can choose their diabetes app for carbs and Footing for protein; they must use the selected app for all of the day's carbs. Extra meals logged in Footing do not increase externally sourced carbs. Choose Footing to restore meal-based totals. This conservative rule avoids guessing whether two separate apps recorded the same meal.

## Reconciliation and privacy

- Match sources by bundle identifier, not display name. Exclude Footing's own HealthKit samples.
- Count a sample UUID once per nutrient/day. Equal values with different UUIDs remain distinct legitimate records. We cannot reliably identify duplicate meals written with unrelated identifiers by one source; users should select a single authoritative source.
- Attribute samples to their start date in the current local calendar, using an exclusive next-midnight boundary. No fixed 24-hour day assumptions.
- Reread whole displayed ranges on refresh, foreground, and observed Health changes. Replace the queried snapshot so corrections/deletions are reflected rather than appended. No claim of immediate background delivery while the app is closed.
- Missing/denied reads are unknown, never a silent fallback to Footing or an inferred zero. Explicit zero samples remain known zero. Invalid and nonfinite values are excluded. Calories are never derived from carbs. Imported food names and meal associations are not invented.
- Only source preferences persist, scoped to the signed-in account on this device. Health samples remain in memory and are cleared on account change/sign-out. Selecting Footing for all nutrients stops observers. No imported meal records are inserted, and nothing is written back to Health.
- Today and Analytics/Progress use the same resolver; Pulse's on-device suggestions and outgoing context use the selected totals. Macro charts omit unavailable samples. Protein-floor evidence does not require readable calorie data. Medication protein context, recovery notifications, and widget unknown states respect the selected sources.
- Existing AI consent still governs Pulse requests. If the user uses AI sharing, selected nutrition totals are part of the context sent to Pulse. The local server sanitizer change preserves bounded, allowlisted source names and adds server-owned instructions against double-counting. That backend change still needs deployment when shipping; it was not deployed here.

## Verification

Focused XCTest cases cover source replacement, independent nutrient sources, UUID deduplication, known zero versus unknown, no fallback, corrections/deletions by replacement, restoring Footing, invalid values/date boundaries, account isolation, and protein-only/carbs-only evidence. UI captures use read-only fixtures and cover source switching, rotation, no-data states, and Today totals. Node tests cover the Pulse sanitizer and source instructions, including legacy clients.

Real authorization, read denial/revocation, live imports from the user's diabetes app, source-app corrections/deletions, and device foreground/observer delivery require a signed Health-enabled device pass. Unsigned simulator tests exercise reconciliation and UI fixtures rather than proving a live Health permission grant.

Apple references: [Nutrition identifiers](https://developer.apple.com/documentation/healthkit/nutrition-type-identifiers), [source attribution](https://developer.apple.com/documentation/healthkit/hkobject/sourcerevision), [authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).

Final verification: 58 distinct Xcode checks passed (10 UI and 48 unit/rendering checks), plus two Node server-context tests. The last two focused result bundles completed with TEST SUCCEEDED. Debug compilation and `git diff --check` passed. Portrait/expanded Today, Progress, Pulse and Profile regressions passed. Captures were visually reviewed, including the selected-source restoration and large-text scroll state.

[Open the six-screen capture gallery](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/nutrition-import-2026-11-11/index.html). Screenshots use read-only sample Health data; permission requests are disabled in that fixture.
