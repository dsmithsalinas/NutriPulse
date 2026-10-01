# Android / iOS parity audit

Audit date: September 21, 2026. Scope: local source comparison and implementation plan; no app changes, device tests, production reads, or store-release verification were performed.

## Delivery decision after this audit

The user subsequently authorized implementation of every parity area and explicitly prohibited any Google Play upload until all areas and release validation are complete. That decision supersedes the incremental-release suggestion below. Implementation and the current verification gates are tracked in the sibling `footing-android/PARITY_STATUS.md`.

## Baselines

- Android: sibling `footing-android` checkout, clean at `0dc14b4` (August 24), configured as 1.1.3 / versionCode 5. This does not establish which build the reporting user installed.
- iOS: `6fe669a` plus the current modified and untracked source. August 30 added goals/experiments and health quality; September 3 added Progress. Local September additions include skipped shots, Your Strong Week, preferences, feedback, and weekly notifications.
- `your-strong-week.md` records an iOS 1.3.0 (183) upload and backend deployments. These are historical records, not a fresh verification of production or App Store availability.
- Preserve the current iOS working tree. Comparing only committed changes would miss much of the requested parity target.

## Existing foundation to retain

Android already implements authentication/recovery/onboarding, nutrition targets and retargeting, food search/manual/barcode/voice logging, favorites, water, workouts, body measurements/goals, basic analytics, Pulse chat, a shot ritual, dose history/reminders, a widget, Health Connect integration, and account-scoped offline storage/outbox support. These need regression checks and integration with the newer behavior, not wholesale replacement.

## Prioritized gap inventory

| Priority | Capability | Current Android evidence | Work required |
| --- | --- | --- | --- |
| P0 | Always-accessible shot logging | `MainActivity.kt` only opens the ritual from the due card; `showDoseEntry` is never set true. `MedicationScreen.kt` is history/reminders only. | Persistent Today action and Medication-screen action, independent of due date, dismissal, history availability, or existing logs. Reuse the ritual and reliable save path. |
| P0 | Visible schedule failures | `TodayViewModel.kt` converts medication-fetch errors to null; home card requires `latest.nextDueAt`. | Explicit loading/loaded-empty/failed/cached states, retry, and continued manual logging access. Missing schedule must not manufacture a due date. |
| P0 | Cross-platform meal visibility | Android Today and meal pickers enumerate breakfast/lunch/dinner/snack; iOS `Meal.swift` also has `pre_workout` and `post_workout`. | Shared Android meal model used by display, manual/search/voice logging, editing, snapshots, and outbox. Render both new categories and preserve unfamiliar server values. Existing new-category rows can contribute to totals while being absent from the four displayed sections. |
| P0 | Read skipped-shot state correctly | Android medication model/repository only reads injections. iOS has separate saved skip decisions. | Read skips and compute the effective schedule before showing reminders or cycle advice, including skips created on iOS. Unavailable history is unknown, not an empty skip list. |
| P1 | Skip / Undo / history | No Android skipped-dose UI or repository found. | Explicit Skip and Undo in Today and Medication, separate history, refresh after mutations, new-injection and deletion handling. Preserve actual injection dates. |
| P1 | Shot-cycle check-ins and preparation | Android shows basic days-since-shot text; no check-in model or planner found. | Appetite/nausea/energy capture, days 1/3/6 prompts, cycle context, learned patterns with sufficient evidence, and low-appetite preparation. Suppress normal cycle predictions after interruption or unknown skip history. |
| P1 | Personal goals and experiments | Android nutrition/body targets exist, but no personal-goal or experiment implementation found. | Goal creation/versioning, active/completed views, boolean/rating check-ins, progress and coverage, daily detail, experiments, and Pulse handoffs. Nutrition targets are a different feature. |
| P1 | Progress hub and summaries | Android navigation still opens `AnalyticsScreen`. | Progress destination with week/month/quarter views, coverage and unknown days, Goals/Analytics/Summaries/Experiments destinations, historical summaries, and the iOS calculation semantics. |
| P1 | Health evidence quality | Android reads daily metrics; no equivalent to iOS `HealthDataQuality.swift` found. | Historical observations, provenance, freshness/coverage/plausibility, baseline windows, and explicit missing-data states. Adapt to Health Connect; do not assume Apple-only metrics are available. |
| P1 | Workout overlap deduplication | Android excludes its own writes and uses provider IDs, but does not collapse near-identical sessions from different sources. | Port the narrowly defined iOS overlap/duration behavior, with tests preserving separate adjacent sessions. Assess already-imported duplicates before any historical cleanup. |
| P1 | Your Strong Week | No Android weekly-outlook implementation found. | Saved weekly context, circumstances/restrictions, evidence, structured generation, explicit refresh, stable saved outlook, stale-evidence notice, revision conflicts, failure recovery, adjustments, and feedback. |
| P1 | Food preferences and Pulse context | Android context contains older food/body/GLP-1/Health Connect fields; no preferences editor or richer client context found. | Persistent food-access preferences UI and current goals, skips, check-ins, quality, and weekly evidence in the appropriate request paths. Verify server-owned enrichment separately; shared backend updates do not supply missing Android UI or client observations. |
| P2 | Contextual food/recovery actions | Android has basic text nudges; no protein-rescue or repeated-meal confirmation implementation found. | Recovery opportunities, favorite-based protein rescue, repeated-meal confirmation, partial-save-safe retries, and suppression during relevant custom weekly circumstances. |
| P2 | Smart coaching notifications | Android has dose reminders and permission UI; no smart-coaching engine/preferences/history found. | Opportunity selection, one daily coaching slot, quiet hours, category controls, notification history/feedback, and destination routing. Keep shot reminders separate. |
| P2 | Weekly reminder | No Android Strong Week reminder found. | Separate per-account preference, Monday 8 AM local scheduling, sign-out cancellation, account-checked tap routing, and reconciliation across time changes/restarts. A notification invites a check-in; it does not generate an outlook. |
| P2 | Platform experience | Existing Android audit leaves populated-device accessibility and dialog polish outstanding. | TalkBack, large text, dark theme, small screens, back navigation, loading/error states, widget/shortcut routes, and physical notification checks. Match capabilities using Android conventions. |

P0 means address first because a current action is inaccessible or shared account data can be misrepresented. P1 supplies the newer feature set and its data foundations. P2 completes contextual experiences and release polish; it remains required for full parity.

## First implementation slice: dose access

1. Add a persistent **Log dose** action to Today, outside the dismissible dose card. Add the same action to Medication history, including its empty and error states.
2. Extract a shared dose-entry route and save handler so both entry points use the existing ritual, stable record ID, and offline queue. Remove the unreachable legacy dialog once it has no purpose.
3. Make the intended logging date explicit. Today should preserve its selected date; Medication should default to today. Confirm timestamp and next-date handling when recording a historical shot.
4. Prefill from known history when available. On history failure or first use, require the user to review medication/dose/site; fetching a schedule must not block entry.
5. Keep the action available after dismissal and after a shot has already been logged. Show the existing record and require deliberate review before another same-day entry; do not silently duplicate a dose.
6. Introduce explicit schedule-load state and account-scoped dismissal storage. The current Today dismissal preference is global to the installation.
7. After save, refresh Today, Medication, the effective reminder schedule, Pulse context, and eventually weekly-outlook staleness. Keep disabled reminders disabled.

Acceptance cases: first-ever shot; missing next date; future/due/overdue schedule; dismissed card; failed history read; cold offline launch; queued save and retry; storage failure; already-logged day; historical day; account switch; midnight/time-zone change. A confirmed local queued save must not be uploaded twice, and a failed save must not show success.

## Delivery order and dependencies

1. **Access and interoperability release:** persistent logging, explicit schedule state, meal-category support, and skip-aware schedule reads. Add focused regression tests. Do not wait for the whole parity project to unblock dose logging.
2. **Medication and evidence foundation:** Skip/Undo, cycle check-ins, schedule/reminder reconciliation, historical Health Connect evidence and quality, and overlap deduplication. Reuse deterministic iOS behavioral fixtures where possible.
3. **Goals and Progress:** goal/experiment repositories and calculations, goal UI, then Progress hub and summaries. This supplies active goals for weekly coaching.
4. **Weekly coaching:** food preferences, Strong Week context/outlook/adjustments/feedback, and complete Pulse context. Reuse established backend contracts and validate authenticated cross-platform reads/writes.
5. **Contextual experiences and release:** rescue/repeated meals, recovery/preparation, smart coaching and weekly notifications, accessibility, populated-device QA, and staged release.

Each slice should leave the app usable and have its own acceptance checklist. Split deterministic schedule, progress, and evidence logic from Compose screens; `MainActivity.kt` and `PulseScreen.kt` currently mix large amounts of UI and domain work.

## Source map for implementation

All Android paths below are relative to the sibling `footing-android` repository; iOS paths are relative to this repository.

| Area | iOS reference | Android starting point |
| --- | --- | --- |
| Dose UI/scheduling | `Models/GLP1Log.swift`, `Features/Today/TodayViewModel.swift`, `Features/GLP1`, `docs/skipped-shot-support.md` (Swift paths under `NutriPulse/`) | `MainActivity.kt`, `TodayViewModel.kt`, `MedicationScreen.kt`, `InjectionRitualDialog.kt`, `DoseReminder.kt` |
| Cycle/coaching | `NutriPulse/Core/Coaching`, `NutriPulse/Features/FoodLogging/ProteinRescueSheet.swift`, `RepeatedMealConfirmationSheet.swift` in that directory | `MainActivity.kt`, `FoodSearchScreen.kt`, `PulseScreen.kt` |
| Goals/Progress | `NutriPulse/Core/Goals`, `NutriPulse/Features/Goals`, `NutriPulse/Features/Progress` | New domain/repository/UI modules; retain `AnalyticsScreen.kt` |
| Weekly outlook | `NutriPulse/Features/StrongWeek`, `NutriPulse/Core/AI/StrongWeekEvidence.swift`, `docs/your-strong-week.md` | New weekly domain/repository/UI modules |
| Health quality | `NutriPulse/Core/HealthKit/HealthDataQuality.swift`, workout deduplication in `HealthKitManager.swift` | `data/HealthConnectRepository.kt`, `data/ActivityRepository.kt` |
| Pulse | `NutriPulse/Core/AI/CoachContextBuilder.swift` | `PulseScreen.kt`, `data/CoachRepository.kt` |
| Notifications | `NutriPulse/Core/Notifications` | `DoseReminder.kt`, `NotificationPermission.kt`, `ProfileScreen.kt` |

Android files in this table live under `app/src/main/java/com/tryfooting/app/`.

## Release validation

- First establish Android build/test/lint results using the documented Gradle commands. This audit did not execute them. Existing `ExampleUnitTest.kt` contains substantive offline, dose-save, goal-math, and sync tests despite its generic name.
- Add deterministic tests for schedule/skip semantics, local calendar boundaries, coverage, goal calculations, stale weekly responses, and deduplication. Use Compose tests for entry-point reachability and save/error states.
- Use a dedicated test account on both platforms: create each new record type on one device, read/change it on the other, then verify reload and offline recovery. Include pre/post-workout meals and skipped shots.
- Verify intended-environment schema/function compatibility before release; do not blindly replay migrations. Existing rollout documentation records migration-history drift.
- Test Android permission denial, process death, offline queue drain, notification taps, disabled reminders, account switching, local midnight, DST, and time-zone changes. Confirm actual delivery on a physical device.
- Run `testDebugUnitTest`, `lintDebug`, and `assembleDebug`, then create and verify a versioned release bundle and release notes. Store upload/release is a separate action.

## What remains uncertain

The reporting user's exact build, medication history, and dismissal state are unknown. Local source establishes these gaps but not their specific trigger. Current production schema/function versions, installed-store versions, live model behavior, Android device performance, and complete end-to-end parity still require verification during implementation. No implementation-duration estimate is given before the Android build baseline and first slice are validated.

## iOS follow-ups from the Android Daylight port (October 1, 2026)

The Android Daylight port (`footing-android/docs/daylight-android.md`) turned up iOS gaps. Owner decisions: faint text #55637A / #8391A7 on both platforms, the widget turns fully lime when the floor is cleared, one hour → meal rule (`Meal.forHour`), and experiment observations get built rather than the results being hidden.

**Data correctness (`ios/data-correctness`, NutriPulse#13; Android search fix footing-android#1):** body goals keep untouched stored values; the consent sheet waits for Pulse settings; Pulse hand-offs survive a reply in progress; coach-chat's 403 `pulse_off` turns Pulse off on the device; onboarding dose labels are exact; widget, Home Screen and notification water actions add the usual amount to today; search "+" logs the portion the row describes (both platforms).

**Daylight alignment (`ios/daylight-alignment`):** lime widget when cleared; floor-cleared moment once per day per account, persisted; meal rows read "1 cup · 320 cal" / "1.5 × 1 cup"; the floor card's Profile link; no shot wording on Progress while GLP-1 is paused; the Analytics weight chart's dose marks stay inside the selected range; the Progress weight sparkline scales to the data (with a ~1 kg / ~2 lb minimum span); `--tour --glp1-paused`; one meal-time rule for the logger and Pulse's suggestions; English weekday labels in Recents; faint text colour (Android's dark value lifted to match on `daylight/faint-text-dark`).

**Still open:**
- Android: the weight sparkline still anchors at 60% of the peak (iOS now scales to the data); the floor card link only opens Profile on iOS, where Android also scrolls to Daily targets.
- Both: nothing writes `experiment_observations`, and HealthKit / Health Connect sleep and steps outcomes aren't evaluated into experiment results (approved to build).
- Both: the dark-mode indigo hero has low contrast on the dark ground (needs a design pass); Pulse history is one stream with no `conversation_id`.
- Not changed on purpose: `WeeklyRecapDigest.weightChange` uses an ASCII hyphen, but it's only context sent to Pulse, never shown on screen.
