# Logging comfort: undo, offline notes and usual meals

October 19, 2026

## Undo a saved entry

The shared logger's saved screen offers Undo, Done and Add something else. Undo
captures the exact new food-log IDs created inside the explicit save task, including
Talk's child tasks and reviewed multi-food meals. Remote pulls do not produce receipts.
It removes that save, not the source food, favorite, usual-meal definition or older
history. Reviewed recent meals have the same action. Starting another save replaces
the receipt; closing the sheet ends the opportunity. This does not provide edit history.

Food undo writes all selected tombstones in one local save and increments revisions.
It works before or after upload; an in-flight create cannot erase the deletion. A
failed undo retains the receipt and shows Retry. Undo also cancels queued goal
celebrations and rechecks the actual goal state before any delayed celebration.
Other saved-screen actions pause
while undo runs. Note undo uses the durable deletion queue below.

## Offline meal notes

Meal notes now commit to a protected, atomic account-specific file before reporting
success. The file is excluded from backup. Saves, edits and deletion tombstones use
stable IDs and revisions. An upload acknowledgment cannot consume a later edit or
undo. A stale remote read cannot overwrite a newer local mutation. Failed disk writes
do not claim success, and invalid/corrupt cache data is not overwritten.

Today and the saved screen label pending notes **Saved on this phone · Waiting to
sync**. Foreground, reconnect and explicit retry flush notes through the normal sync
coordinator. Offline reads use the local cache without waiting for a failed request.
Notes remain qualitative and never become nutrition totals or diary-completeness signals.

During a signed-in offline cold start, the loading/profile-retry surfaces offer a
note-only route. It supports local viewing, adding, editing and deleting notes without
bypassing the profile or onboarding gate for the rest of the app. Account changes
close this route and clear visible cached entries. A previous online sign-in is required.

Protected files remain isolated by account across ordinary sign-out so unsynced notes
are not silently discarded. They reload only for that account. Successful in-app account
deletion purges note and usual-meal files and the remembered logging-method preference.
The cloud tables cascade from the account. Pending notes are still device-local until
sync succeeds; they are not guaranteed to survive app deletion or device loss.

## Remembered method

The generic Log action opens the last selected Talk/Search/Scan/Favorites method for
that account. Explicit Talk/quick-action handoffs retain their intended method and do
not overwrite the preference merely by opening. Familiar foods and named usual meals
remain accessible through Favorites; Talk places them below the talk and typing sections.

## Named usual meals

Save the current successful food batch, a reviewed recent meal, or an existing Today
meal as a named combination. Names support up to 80 Unicode scalar characters and
meals up to 40 entries. The original serving and nutrition snapshots are preserved.
The `usual_meals` table has owner-only RLS and an account-deletion cascade.

Choose a usual meal from Talk or Favorites, review every serving, then explicitly log
it to the header's selected meal and day. The food entries use new IDs and one local
transaction; undo covers the whole save. Rename and delete are available through the
context menu and accessibility actions. Deleting a definition does not delete history.
Creating, renaming and deleting definitions require a connection; cached definitions
can still be reviewed and logged offline. Failures retain the form for retry. There
is no automatic recurring meal logging.

## When lighter tracking ends

A passed end date now asks for a choice instead of resuming pressure. On the next
Today visit, **Your lighter stretch has ended** offers **Keep taking it easier** and
**Return to usual tracking**. Goal reminders stay paused, logging stays available,
and Pulse stays gentle until the user chooses. Keeping it easier removes the end
date; duration and optional context can be changed in Manage. Expired vacation or
illness context is not carried into Pulse or prefilled as a new reason.

The account row stays enabled until an explicit resume. Client notification gates
and the server's tracking context both apply this rule, including while backgrounded.
Medication reminders keep their independent settings. No goals or past entries change.

## Verification and deployment

- Full suite: **437 passed, zero failures, five opt-in live cases skipped** after
  credentials were removed. No TestFlight archive or upload was made.
- **38 backend/database checks pass**, including usual-meal ownership, anonymous and
  cross-account restrictions, validation, deletion and cascade; note and Pulse checks
  continue to pass.
- Offline tests cover disk reload, repeated save deduplication, connection recovery,
  edit/undo during upload, stale reads, account switching and failed disk writes.
- Food receipt tests cover exact IDs, preserved older/foreign rows, atomic owner
  validation, new repeated-meal IDs and adjusted servings.
- `SignedInLoggingComfortTests.testUndoOfflineNotesUsualMealsPreferenceAndPauseChoice`
  passed on an isolated iPhone 17 Pro / iOS 26.5 simulator: **one pass, no failures
  or skips**. It used the real auth, queue, repositories, local store, sync and Pulse.
  Offline behavior was exercised through the app's connectivity flag and disk reload;
  this is not a physical airplane-mode or manual tap-through test.
- That check verified a queued note undo reached the server, named-meal save/rename/
  delete and idempotent retry, half-portions synced and undone without changing the
  source records, account-isolated methods, paused-expiry context and explicit resume.
- The first live run exposed an assertion that checked the queue before an already
  running background sync drained. The final check waits for the queued operation
  and verifies remote state. It passed with a fresh fixture.
- `coach-chat` **v32** is live in project `dcabdzuhuixlcgwavtsc`, JWT verification
  remains enabled, and all five downloaded files match the tested source. Its live
  response confirmed there was no catch-up obligation and support remained gentle
  until the user chose to resume or extend.
- Migration `20261019225119_usual_meals.sql` is applied. The security advisor reports
  no new-table finding; the existing default-deny `rate_limits` INFO remains unchanged
  ([advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).

The disposable account was signed out with zero remaining sessions and then removed
with its credentials. The dedicated simulator is removed after visual review; existing
personal simulator sessions are left alone. Debug visual fixtures use `--tour` with
`--logging-preview --saved-note-preview` or `--lighter-preview --lighter-ended-preview`.
The prompt hash changed; update `pulse-eval` before another model evaluation.

## Off-script

[Today went sideways](off-script.md) adds two user-initiated Pulse help routes and a
separate day-note path. Day notes share the existing offline outbox and undo behavior;
`kind = day_context` keeps them distinct from meal notes and from approved Pulse memories.
