# Your strong week

Today now offers a saved weekly outlook: one grounded observation, one food focus, and broad movement/recovery guidance. The optional check-in accepts travel, a busy week, taking it easier, injury/limited movement, and free text. An injury choice exposes a field for clinician-provided restrictions; Pulse asks for clarification instead of treating an alternative activity as safe when restrictions are unclear.

## Context and lifetime

- Weeks run Monday–Sunday in the user's local time. Date keys remain Gregorian regardless of the device's display calendar.
- Temporary circumstances stop influencing advice in the following week. Something marked ongoing is presented for explicit confirmation; it is never assumed resolved or automatically carried into an unrestricted plan.
- Saving context clears the old outlook atomically. Context remains saved if generation fails. Failed persistence of a generated outlook can retry the pending result without another model request in the same session.
- Outlook saves are conditional on the context revision. A late response cannot overwrite newer circumstances.
- The outlook remains stable until the user chooses **Update my week** or **Refresh with latest data**. The card highlights a new day's data or a changed shot log. Refresh is explicit, not an automatic background model call.
- Current circumstances and the saved outlook also enter normal Pulse conversations. New evidence and restrictions outrank the dated outlook. Chat itself does not silently edit saved weekly circumstances.
- Generic coaching nudges pause while custom circumstances or an unconfirmed ongoing condition are active. The outlook and Pulse provide tailored suggestions instead. Shot reminders and notification preference settings do not change.

## Evidence

Generation compares the last seven completed calendar days of logged food/activity against the preceding 21. It includes logged-day counts, average logged calories/protein, comparisons with the **current** protein target, activity types, session counts, and duration. Historical workout evidence comes from the locally available synced/imported workout history; absence is not evidence of rest. Food logs are not confirmed complete-day intake.

Sleep, resting heart rate, HRV, and steps include observed-day counts and personal baseline averages. Comparisons require at least three recent observations and seven baseline observations. Implausible samples are excluded. Today's sleep may be included; today's incomplete food/activity totals are not. Existing health-data-quality warnings accompany the evidence. Recent reported appetite and energy are supplied as subjective experience; they do not establish a multi-cycle pattern by themselves.

The model receives existing nutrition goals, active personal goals, actual shot/skip context, and the weekly evidence. It stays on Claude Sonnet 4.6. A structured tool response is validated before display; malformed/truncated responses fail visibly. Prompts disallow sets/reps, exercise-by-exercise plans, rehabilitation, medication changes, medical clearance, and readiness verdicts from wearables. The response validator also rejects common numeric sets/reps prescriptions; it is not a substitute for semantic model evaluation.

## Validation and preview

```sh
npm ci --prefix scripts
node --test scripts/strong-week.contract.mts scripts/strong-week-db.contract.mts
```

These tests use a stubbed model transport and isolated embedded PostgreSQL, never live user data. They cover context sanitization, response shape, truncation/failure handling, owner-only access, schema constraints, and context revision races. `StrongWeekTests` in FootingTests covers local week boundaries, daylight saving, context expiration/reconfirmation, draft normalization, missing nutrition data, and sparse recovery evidence.

A Debug-only `--strong-week-preview` launch argument opens the check-in without authentication or network requests. Add `--outlook` for a sample completed outlook. The fixture cannot generate or persist data.

## Outlook feedback

Each generated outlook offers **Was this useful?** with Helpful / Not helpful ratings. Users can optionally select Too vague, Doesn't fit my week, More food ideas, More movement detail, or The tone could be better. The sheet saves explicitly, supports Cancel and edits, retains choices on save failure, and confirms success only after persistence. Feedback does not refresh the outlook or enter the coaching prompt automatically.

`strong_week_feedback` stores an owner-only rating and reason list with the reviewed outlook snapshot, context revision, and generation timestamp. Upserts keep one response per user and generated outlook; refreshed outlooks start with no rating while previous feedback remains available for analysis. Account or weekly-record deletion cascades to feedback. The stored snapshot is client-submitted feedback evidence, not verified model provenance; this feature does not add a review dashboard or model comparison metadata.

Apply `20260917045151_strong_week_feedback.sql` before releasing this iOS update. No Edge Function change is required. Applied to production on September 16, 2026 (Pacific). Verified migration history, enabled RLS, all four owner-only policies, and authenticated-only grants. Security advisors returned no new findings; the existing informational service-only `rate_limits` notice remains. `scripts/strong-week-feedback-db.contract.mts` verifies upserts, ownership, anonymous denial, bounds, snapshot retention across refresh, and deletion. The iOS test verifies that the saved generation timestamp matches the fetch filter and that the payload round-trips.

## Rollout

### Monday notification

The updated iOS app schedules a repeating on-device notification for Monday at 8 AM in the device's local time. Its calendar trigger leaves the time zone unspecified so the schedule follows local time, including daylight-saving changes. The message invites users to check Pulse; it does not imply an outlook has already been generated or trigger a background model request.

Profile → Notifications has a separate **Your strong week** toggle. The reminder defaults on for accounts with existing iOS notification permission; launch never prompts for permission. Explicitly enabling the toggle can request permission. The preference is stored per account on the device. Sign-out cancels the reminder, and notification taps are accepted only for the matching signed-in account. A tap opens the weekly outlook from Today. Scheduling is reconciled on sign-in, app activation, and significant time changes.

No backend deployment is needed; this requires an updated iOS release. The simulator build and all 202 iOS tests passed, including reminder payload, local Monday scheduling across time zones and daylight-saving dates, account-specific preferences, and one-time tap routing. Actual notification delivery and tap navigation on a physical device remain to be verified.

### Food preferences and outlook adjustments (local follow-up)

**Adjust this for me** lets users select Make it simpler, More food ideas, and Less activity, then explicitly refresh. Selection changes are saved before generation and keep existing circumstances and clinician restrictions. **Something about my week changed** opens the existing check-in. Current adjustments are also included in Pulse chat, expire at the next local week, and do not carry over when ongoing circumstances are reconfirmed. Less activity pauses generic coaching nudges for the week. Context updates use the previous revision to reject stale edits from another device.

**Food preferences** is available from Profile → Pulse Coach and the weekly outlook. Choices cover rarely cooking, eating out, budget-friendly options, limited kitchen access, and quick meals, plus a bounded optional note. Save persists these in the owner-only `food_access_preferences` table; Cancel leaves them unchanged; Clear takes effect only after Save. They apply across weeks until edited. Pulse fetches these for chat and generation. A preference change flags an existing outlook for an explicit refresh and invalidates an in-memory retry generated with older preferences.

Apply `20260917043834_pulse_food_access_and_adjustments.sql` after the two original migrations, then deploy `coach-chat` with the shared context/provider modules before releasing the updated iOS app. Deployed September 16, 2026 (Pacific): migration `20260917043834` and `coach-chat` version 23. Production `PULSE_PROVIDER` is explicitly set to `claude`. Deployed source matches the tested local function and shared modules. Live RLS, ownership policies, migration history, and HTTP smoke checks passed; security advisors returned no new findings. All 29 relevant backend checks passed before rollout. An authenticated end-to-end run of the new preferences flow and the updated iOS release remain outstanding. If the private model evaluator is used again, redeploy its shared prompt too; prompt-hash checks otherwise intentionally reject comparisons between different versions.

Validation: `scripts/pulse-preferences.contract.mts` and `scripts/pulse-preferences-db.contract.mts` cover allowlists, prompt boundaries, RLS, field bounds, clearing, account deletion, and revision conflicts. `PulsePreferenceTests` covers retained injury restrictions, adjustment expiry, legacy record decoding, and unavailable versus unset food preferences.

1. Apply `20260917033029_strong_week.sql` after the skipped-dose migration.
2. Deploy the updated `coach-chat` function.
3. Release the tested iOS app.

Before release, exercise a real authenticated generation in the intended environment, including travel, an injury with/without restrictions, sparse health data, and generation failure. Live model quality and production deployment are separate from the isolated contract tests.

### Backend rollout completed — September 16, 2026 (Pacific)

Applied `20260917030735_glp1_skipped_doses.sql` and `20260917033029_strong_week.sql` to the linked `nutripulse` project (`dcabdzuhuixlcgwavtsc`). Deployed `coach-chat` version 20 with JWT verification retained. Downloaded deployment source matches the local function and its shared dependencies.

Verified live owner-only RLS policies and authenticated grants on both tables, with no anonymous access. Security advisors returned no new findings (the existing informational notice for the service-only `rate_limits` table remains). HTTP smoke checks returned 200 for OPTIONS and 401 for an unauthenticated POST. All 24 skipped-shot and Strong Week backend contract checks passed before deployment. These checks did not invoke Claude or modify user records; authenticated model validation and the iOS release remain outstanding.

The repository has pre-existing migration-history drift: six remote migration timestamps differ from local files, and the local daily-status-report migration is absent from remote history. To avoid replaying unrelated changes or rewriting deployed history, this rollout used a temporary deployment folder populated with `supabase migration fetch`, then added only the two new migrations. Future database deployments must reconcile that older history or use the same isolated approach; do not blindly repair remote migrations as reverted.

### Release package — September 16, 2026 (Pacific)

Prepared Footing 1.3.0 (183) from the current working tree, including the Monday reminder and outlook feedback. `xcodebuild archive` and the App Store Connect export succeeded with automatic signing. Verified archive and exported IPA signatures, IPA integrity, provisioning files, and matching 1.3.0/183 versions in the app and widget. Artifacts: `build/Footing-1.3.0-183.xcarchive` and `build/AppStore-183/Footing.ipa`. The build number was supplied explicitly as `CURRENT_PROJECT_VERSION=183` because the git-derived configuration still reads 182; preserve this override if rebuilding these uncommitted changes. Uploaded this archive to App Store Connect on September 16, 2026 at 22:01 Pacific. Xcode confirmed “Upload succeeded” and “Uploaded package is processing.” Apple processing completion is not yet verified; the build has not been submitted for App Review. Latest validation: 203 iOS tests and 5 feedback database checks passed.
