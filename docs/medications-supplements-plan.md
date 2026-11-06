# Medications and supplements implementation plan

Approved flow with initial iOS implementation · November 6, 2026

Footing will let people configure medications and supplements, see each scheduled dose on Today, and record Taken or Skipped from the daily checklist. Local notifications will offer Mark taken without opening the app. Each occurrence records one scheduled dose, independent of the amount taken.

Example: two vitamins scheduled at 8 AM and 7 PM create four daily occurrences. Magnesium can specify “2 capsules” per occurrence; it still takes one tap per scheduled time.

## Agreed experience

- Each person explicitly enables Medications & supplements in their own Profile; this is an individual setting, not an administrator permission. Default is off. Today must never show the section while this setting is off, even if saved routines exist.
- Setup supports name, optional amount per dose, every day or selected weekdays, and one or more user-selected times. Times determine frequency; there is no second conflicting frequency field.
- Today shows all scheduled doses, grouped by Morning, Afternoon, and Evening and sorted by time within each group. Each item is tracked separately.
- Untaken morning doses remain actionable in the evening. Skipped is an explicit choice, never inferred from silence.
- Taken and Skipped can be undone. Completed days collapse to “All taken today” or “Today complete · 3 taken, 1 skipped.” Expand to review or correct entries.
- History shows scheduled times, recorded times, and Taken, Skipped, or Not logged states.
- Notification actions record one specific occurrence. Tapping the notification body opens the relevant day and item.

## Existing app integration

| Existing source | Planned integration |
| --- | --- |
| `NutriPulse/Features/Today/TodayView.swift` | Add a dedicated checklist after `tileGrid` and before `homeSupportActions`. Include the same section in the lighter experience before support actions. Keep it outside `pulsePriorityCard`. |
| `NutriPulse/Features/Today/TodayViewModel.swift` | Load occurrences for `selectedDate`; refresh on date changes, foreground, account changes, and local dose updates. Isolate most logic in a feature store/view model. |
| `NutriPulse/Features/Profile/ProfileView.swift` | Add a “Medications & supplements” entry in `profileHealth`, opening activation and management. Include an account-scoped, default-off Show on Today switch. Use the existing SettingsTile and sheet/navigation conventions. |
| `NutriPulse/Core/Supabase/MealNoteStore.swift` and `MealNoteRepository.swift` | Reuse the durable account-scoped outbox approach: persist before updating UI, revision guards, offline retry, account generation checks, and tombstones. Do not add unrelated medication data to meal-note storage. |
| `NutriPulse/Core/SwiftData/SyncEngine.swift` | Include the new outbox in pending counts and every upload path; surface retries using the existing sync status pattern. |
| `NutriPulse/Core/Notifications/NotificationManager.swift` | Add a separate medication namespace and scheduler; preserve existing shot, weekly, and smart notifications. Register all categories together, since category registration replaces the set. |
| `NutriPulse/App/AppDelegate.swift` | Dispatch medication notification actions before smart-coaching routing. Load the correct local account store and save directly in the background. |
| `NutriPulse/App/AppState.swift` | Bind/unbind the store with account lifecycle, route notification opens to Today, and reconcile on foreground. |
| `NutriPulse/Core/Supabase/AccountRepository.swift` | Purge cached medication data and pending actions during account deletion; cancel account-owned reminders on sign-out/switch. |
| `NutriPulse/DesignSystem/Theme.swift` | Use current Daylight fonts, colors, spacing, radii, Dynamic Type, and existing button styles. |

The current app already has a specialized GLP-1 tracker. Keep that flow authoritative for injections; this first version adds a separate routine checklist and does not automatically import or duplicate shot schedules.

## Screens and interaction

### Management and editor

Profile → Medications & supplements opens activation and management. The Show on Today switch is off by default. Turning it on reveals the daily checklist once items have been added. This setting is separate from each item's Remind me preference and OS notification permission; activation alone does not request permission.

Proposed deactivation behavior: turning it off immediately hides the section on Today and cancels medication pending and delivered reminders. Preserve routines, item reminder preferences, and history; retain access to management and history from Profile. Show “Turn off to hide this section and pause its reminders. Your items and history stay saved.” Re-enabling reconciles only future reminders that are individually enabled, without replaying past reminders.

Record effective enable/disable intervals, not just a current boolean. Retain already logged occurrences, freeze unlogged occurrences during disabled intervals as tracking paused, and exclude those intervals from completion totals. Do not backfill Not logged doses for days while the feature was disabled. If re-enabled mid-day, resume with remaining future doses; earlier unlogged slots stay paused. In past-day history, explain paused intervals without treating them as skips. This paused-history policy is proposed for review.

The active list has Add, History, and item editing. Each summary reads, for example, “Magnesium · 2 capsules · Daily · 8 AM, 7 PM.” Archive stops future scheduling while retaining history.

The editor contains Name, optional Amount per dose, Days, Dose times, and a Remind me toggle. A time row can be added or removed. Reject empty names, empty weekday selection, no times, and duplicate times. Show the derived summary “Twice daily” below the times. Request notification permission only when the user enables reminders; denied permission does not prevent saving the routine or logging.

### Today

Use one white grouped surface titled “Medications & supplements,” with Manage and a summary such as “2 of 4 taken.” Within it, use lightweight dividers and time-of-day headings. Each row shows name, amount, scheduled time, and Taken/Skip actions. Taken rows show the actual recorded time and Undo; skipped rows show Skipped and Undo. Use 44-point targets, text labels in addition to color, and no swipe-only essentials.

Proposed grouping: Morning before noon; Afternoon noon to before 5 PM; Evening 5 PM onward. These are display groups only; user-entered times control reminders. Omit empty groups. Large routines may make the section tall; retain every dose with normal page scrolling rather than hiding future doses.

Gate the checklist on the account's feature activation setting in both usual and lighter Today. Hide it if off, or if no routines have ever been configured; provide discovery and first-item setup through Profile. On an enabled day with routines but no scheduled doses, show a compact “Nothing scheduled today” row. Date navigation uses the existing Today header and loads that date's occurrences. Future occurrences are visible but cannot be marked taken early in the first version; past entries can be corrected through History.

### History

Open from Today or management. Show a date-grouped list with a date picker, not adherence scores or streaks. Preserve each occurrence's name and amount at the time it was scheduled. Allow Taken, Skipped, reset to Not logged, and editing the actual taken time. Distinguish actual taken time from the time the entry was recorded. Do not allow future actual times.

At midnight, yesterday's untaken doses become Not logged in history. Do not carry them forward, automatically mark them skipped, or suggest a replacement dose. Today starts with the new day's schedule.

## Data model

Use separate logical routine definitions, effective-dated schedule versions, dated occurrences, and status events. A single boolean cannot represent skipped, unlogged, undo, or corrected history. The first implementation stores these together in one account-owned `medication_tracking` JSON document, with a server revision and idempotent write ID. An invoker RPC atomically compares revisions before committing. This replaces the originally proposed separate physical tables and keeps schedule/activation/history changes transactional.

| Entity | Principal fields |
| --- | --- |
| MedicationTrackingPreference | user_id, enabled (default false), revision, effective activation intervals; separate from device notification permission |
| MedicationRoutine | id, user_id, name, optional amount_text, active_from, archived_at, created_at, updated_at |
| MedicationScheduleVersion | id, routine_id, user_id, effective_from, effective_until, selected_weekdays, stable time-slot IDs and local times, timezone policy, revision |
| MedicationOccurrence | stable id, user_id, routine_id, schedule_version_id, slot_id, local_date, timezone_id, scheduled_at, name_snapshot, amount_snapshot, status, actual_taken_at, recorded_at, revision |
| MedicationDoseEvent | id, occurrence_id, user_id, action, actual_taken_at, recorded_at, source (Today/notification/history), expected_revision |
| Device reminder preference | user/device/routine scope, reminders enabled, reconciled revision; system permission remains device-local |

Use a deterministic occurrence identity from account, schedule version, local date, and slot ID. Generate dates with calendar arithmetic, not 24-hour offsets. Snapshot history before applying changes. Default schedule edits to tomorrow; offer an explicit “Apply to remaining doses today” path that previews additions/removals and preserves already logged occurrences. Archive cancels future reminders while retaining completed and past unlogged records.

Occurrence generation must be deterministic and idempotent locally and remotely. Materialize missing historical dates from effective schedule versions, so an unopened app does not lose unlogged history. Persist the initial configuration/start date to avoid inventing doses before setup.

The document row uses ownership RLS and cascades on account deletion. Each dose has a deterministic occurrence key. Route writes through an atomic revision-checked transition so replayed notification taps cannot duplicate a dose and stale actions cannot overwrite a later skip, correction, or undo. If a cross-device conflict occurs, retain this phone's document and the synced document for explicit review. The review shows both routine lists and recorded doses; choosing one version replaces the other only after confirmation. Undo produces a new event/revision, rather than deleting audit context. This first version resolves conflicts at the document level; it does not automatically merge conflicting dose histories.

## Notifications and offline actions

Register a medication category with Mark taken as the primary background action. A Skip action may also be included, matching Today. Apple supports these actions without bringing the app to the foreground: [Declaring actionable notification types](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types).

Each notification payload carries account ID, exact occurrence ID, schedule version, and expected revision. The action handler must:

1. Verify the current account, enabled feature state, and payload against locally stored configuration. Reject disabled-feature, stale, archived, superseded, already resolved, or wrong-account requests.
2. Atomically persist the status event and updated occurrence on-device before considering the action successful. Use the existing protected-file pattern, tested while locked and after cold launch. If protected data or account state is unavailable, preserve an actionable route for review; do not report a successful save.
3. Remove that occurrence's pending and delivered reminder after persistence. Notify the visible checklist if open.
4. Queue sync independently of network/auth refresh availability. A later network failure cannot erase the local action.

Late taps must refer to the dated occurrence, never “today's vitamin.” If a notification from a previous day is actioned, open that historical entry for review rather than silently assigning the current time to yesterday. Undo may restore a future reminder; never immediately replay a reminder whose scheduled time has passed.

Create a dedicated scheduler rather than treating medication reminders as smart coaching. Pulse being disabled, coaching quiet hours, daily coaching budgets, and lighter tracking must not cancel explicitly configured medication reminders. Make reminder preferences clear on each routine. Preserve the app's current foreground-banner policy initially; reconcile and update the checklist while the app is open.

Schedule bounded one-shot requests carrying occurrence identities. Use a shared notification budget across medication, shot, weekly, and smart requests; reserve capacity for existing notifications and fill remaining capacity with the earliest medication occurrences. Refresh on configuration changes, foreground, successful background actions, significant clock/timezone changes, and sync updates. Test cancellation by identifier prefix; never cancel every app notification.

Release gate: calculate the guaranteed scheduled horizon for realistic and high-frequency routines. A finite local queue cannot guarantee unlimited reminders if the app is never reopened. Show the actual “Reminders scheduled through …” horizon in management if capacity is constrained. Best-effort background refresh can extend it but is not a delivery guarantee. If indefinite unattended delivery is required, design a server/APNs scheduler before claiming that capability. Prototype scheduling and budget behavior before completing UI work.

Proposed timezone behavior: dose times follow the device's local wall clock; historical occurrences retain their recorded timezone. Reconcile unlogged future occurrences on travel without duplicating already resolved slots. For daylight saving gaps, use the next valid time; for repeated times, create one occurrence. Validate these policies in tests and disclose timezone changes in the schedule editor.

## Delivery order and review gates

1. **Scheduling spike and model contract.** Prove background Mark taken with the app closed, offline, and locked; establish queue horizon, occurrence identity, DST/travel handling, and conflict rules. Review the mockup and proposed defaults before UI implementation.
2. **Persistence and schedule engine.** Add models, calendar expansion, migration, repository, account-scoped store/outbox, ownership policies, and lifecycle cleanup. Wire SyncEngine. Verify ownership and duplicate/conflict handling locally before deployment.
3. **Setup.** Build Profile activation, list/editor/archive and permission handling using Profile's existing patterns. Persist activation intervals and reconcile pause/resume. Add fixtures for default-off, enabled-empty, enabled-populated, and disabled-with-history states.
4. **Today and History.** Integrate the shared checklist into usual/lighter Today, completion state, undo, date navigation, history corrections, empty/error/loading states, and sync feedback.
5. **Notification integration.** Consolidate category registration, add scheduler and direct background actions, default-tap routing, cancellation, timezone reconciliation, and device preference UI.
6. **End-to-end verification and release review.** Run focused unit/integration/UI tests plus a physical-device notification pass. Review both light/dark modes, larger text, VoiceOver, and account switching. Deploy schema additively before enabling the client feature.

## Acceptance checks

- New accounts start off. Saved routines alone never make Today show medications. Profile activation gates both usual/lighter Today and notification scheduling. Deactivation retains history/items, cancels medication reminders only, and blocks stale notification actions. Re-enable does not replay past notifications or invent unlogged doses for disabled intervals. Account changes never inherit another person's activation setting.
- Two vitamins × two times create exactly four separately actionable occurrences, including when amounts are “2 capsules.”
- Daily and selected-weekday schedules work across month/year boundaries, DST, and travel; duplicate local times are rejected.
- Morning doses stay visible in the evening. Taken, Skipped, undo, and history correction calculate completion correctly. No all-taken label appears if anything was skipped.
- Today and notification actions race safely; duplicate delivery/retry does not create a second taken event. Stale taps cannot overwrite corrections.
- Logging survives process termination and offline relaunch; pending sync retries without losing the action. Disk-save failures never display a false completed state.
- Editing/archiving preserves historical snapshots and removes only affected future reminders. Undo does not immediately re-notify a past dose.
- Signed-out/wrong-account notification actions cannot write; sign-out removes that account's reminders; deletion purges local and remote records.
- Denied permission leaves the checklist fully usable and provides a Settings link. Pulse-off and lighter tracking leave explicit medication reminders intact.
- Verify notification actions on a physical device while locked, app terminated, offline, and after reboot. Review the queue's horizon under high frequency alongside existing shot reminders.

## Scope and proposed defaults to review

This plan covers the existing SwiftUI iOS app. Android parity should reuse the data contract in a separate implementation. No medication database, dose advice, refill inventory, as-needed schedules, automatic missed-dose guidance, or HealthKit medication integration is included.

Visual concepts in `marketing/medications-supplements-review-2026-11-06/` cover Today, Profile activation/management, add-item setup, and History. The owner approved these screens and the off behavior. They illustrate hierarchy and styling; they are not native screen captures or complete specifications for every state.

## Initial implementation and validation

Implemented Profile activation (default off), daily/weekday scheduling, amount per dose, dose times, item archive, usual/lighter Today checklists, Taken/Skipped/undo, compact completion, historical corrections, durable account-scoped offline storage, revision-checked sync, notification category/actions, default-tap history routing, permission handling, reminder queue budgeting, clock-change reconciliation, and account cleanup.

Primary sources:

- `NutriPulse/Models/Medication.swift`: effective schedules, tracking intervals, occurrences, status events, calendar expansion and validation.
- `NutriPulse/Core/Supabase/MedicationStore.swift` and `MedicationRepository.swift`: local atomic document, outbox, remote CAS, and conflict retention.
- `NutriPulse/Core/Notifications/MedicationNotificationScheduler.swift`: bounded local reminders and direct background actions.
- `NutriPulse/Features/Medications/MedicationViews.swift`: activation/management, editor, Today, History, correction and conflict-review screens.
- `supabase/migrations/20261106170529_medications_tracking.sql`: account-owned storage and idempotent CAS RPC. Applied to the linked hosted `nutripulse` project on November 6, 2026; the local version matches hosted migration history.

Validation on November 6:

- iOS simulator app build and app/unit/UI test target compilation succeeded.
- Thirteen core XCTest cases passed on the Mac host using the original model, store and test files, substituting only OS/network adapters. Coverage includes four-dose expansion, selected weekdays, DST, pause/resume, offline restart, undo, duplicate/stale notification actions, schedule edits/archive history, early-taken doses during same-day edits, cross-device conflicts, mutations/account changes during upload, lost commit responses, and disk-write failure.
- Four PGlite database contract cases passed: create/retry/CAS, ownership isolation, anonymous/malformed-write rejection, and account deletion cascade. Run with `node --experimental-strip-types --test scripts/medications-db.contract.mts`.

Native execution is now verified. CoreSimulator’s updated 1174.21 framework is available and the runtime mismatch is cleared. A dedicated iPhone 17 Pro Simulator on iOS 26.5 kept testing separate from saved personal sessions. Use ad-hoc simulator signing for authenticated tests, since unsigned builds cannot reliably retain the Keychain session.

Eighteen distinct native tests passed across targeted runs: the thirteen core cases, two hosted sync/category checks, the hosted notification/queue check, and two existing Profile rendering checks including large text and the device stack budget. The full signed-in UI flow also passed. It covered activation, daily/selected weekday setup, Taken/Skipped, historical correction, off/on persistence across relaunch, and Mark taken in the expanded OS notification. The action was verified in the hosted document; the actual native reminder queue changed 56 → 0 → 56 across off/on while retaining history. RLS and invoker execution were verified on the deployed table/RPC; the post-migration security advisor reported no medication-related findings.

Native QA fixes include keyboard Done/swipe dismissal in the editor, stable Today-owned sheet presentation so turning the feature off cannot dismiss Settings, and an in-content Daylight title for History on iOS 26. Notification routing accepts the registered category as well as the local identifier prefix, allowing the actual OS action callback to be exercised with a simulated delivery.

Actual captures and sanitized results are in `marketing/medications-supplements-review-2026-11-06/native/README.md`. Disposable hosted users and their records were removed and temporary credentials deleted after validation. The notification UI test used `simctl push` delivery; a physical-device pass must still cover local reminder delivery while locked, offline, terminated, and after reboot before release.
