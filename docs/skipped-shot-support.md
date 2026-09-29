# Skipped shots

A skip is a separate `glp1_skipped_doses` row tied to the injection that established the schedule. It never writes an injection, changes its dose/site, or resets days since the last actual shot. Only explicitly skipped dates advance the existing weekly reminder cadence; elapsed time is not treated as a skip.

Today, Profile, and the GLP-1 tracker expose Skip and Undo. History lists skipped scheduled doses separately from shots taken. Existing reminder requests are replaced using the effective schedule; disabled reminders stay disabled. Undo restores the first unskipped planned date. A new actual injection establishes a fresh schedule; older skips remain in history. Deleting an injection also deletes the skips anchored to it.

Pulse receives saved skipped dates, whether skip history was available, the actual cycle day, cycle interruption, and a separately labeled next reminder. After interruption, cycle predictions and scheduled post-shot prompts are suppressed. A failed history fetch is unknown, not evidence that no dose was skipped. Neither the UI nor Pulse presents the next reminder date as medical restart advice. Chat cannot persist a skip; it directs users to the explicit action.

## Validation

With Node 24 installed:

```sh
npm ci --prefix scripts
node --test scripts/skipped-dose-db.contract.mts scripts/coach-skipped-dose.contract.mts
```

The database tests run the checked-in migration in embedded PostgreSQL with two users and authenticated/anonymous roles. They check ownership, foreign injection references, immutable rows, duplicate decisions, Undo, cadence constraints, and parent deletion. They never access a remote database.

`GLP1SkippedDoseTests` in the app test target covers repeated skips, partial Undo, new injections, unknown schedules, passed dates, and daylight-saving transitions. Run the FootingTests target with an installed iOS simulator after Xcode setup is complete.

Manual app checks before release:

- Skip a due shot with reminders enabled. Confirm Today/Profile agree, history says skipped, and the pending reminder dates move one calendar week.
- Undo and confirm the original planned date returns; repeat with reminders disabled and verify they remain off.
- Log a real shot after skipping, then verify its actual date/site and normal cycle check-ins. Delete that shot to restore the previous schedule.
- Skip two consecutive doses, then Undo the earlier skip in history. Confirm the earlier unrecorded planned date is restored.
- Fail the skip request and history refresh. Confirm no success is shown without a committed skip, and unavailable history produces no inferred cycle guidance.

## Rollout order

1. Apply `20260917030735_glp1_skipped_doses.sql` to the intended Supabase environment.
2. Deploy the updated `coach-chat` function. It accepts legacy clients without the new fields.
3. Release the tested iOS app. Older app versions do not read skipped-dose records and cannot suppress reminders based on them.

No model provider change is included.
