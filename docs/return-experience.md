# Returning after a logging gap

The iOS Today screen offers **Start with today** after at least three complete local calendar
days without food entries. Eligibility requires prior food history, no entries today, and a
successful remote refresh. New accounts, historical dates, and failed history requests do not
establish a return. No reason for the gap is inferred or requested.

The card uses Today's existing ranked slot after medication actions and scheduled shot
check-ins. **Log food** opens the existing logger on today. **Use a recent meal** offers meal
groups from the most recent logged day, even beyond the seven-day sync window. It shows the
source date and opens the existing serving review before an explicit save. Copies retain food
snapshots, use new IDs, and save atomically. Failed saves leave the review open. A first saved
entry removes the return card; there is no backlog to clear.

## Partial diaries

Food entries are lower bounds on intake, not evidence that a full day was logged. Until an
explicit completeness signal exists, below-floor nutrition remains unknown. Confirmed protein
floor hits remain wins; partial and empty days cannot become confirmed misses. No historical
entries or nutrition targets are changed.

Progress and the built-in protein goal show confirmed floor days and unassessed days. Automatic
protein goals omit unconfirmed outcomes from evaluation. Weekly recap evidence uses `nil` for
unconfirmed floor hits. Logged averages remain available, labeled as logged amounts rather than
full intake. Empty Today tiles show unknown intake; food-pacing nudges stay quiet for empty
diaries, and partial-entry prompts acknowledge uncertainty.

The shared Pulse prompt applies the same rule in chat, check-ins and recaps. Its allowlist also
maps legacy clients' `proteinFloorHit: false` to unknown. `coach-chat` version 29 was deployed
with this shared context on October 19, 2026, before the iOS release. No database migration is
required. The changed prompt
also changes the evaluator prompt hash; update `pulse-eval` before another model evaluation.

## Verification

`ReturnExperienceTests` covers new accounts, failed history, the three-day boundary, first-entry
exit, long gaps, daylight-saving changes, and consistent partial-day states across Progress,
Goals and weekly recap evidence. `LocalStoreSyncStateTests` covers meal-copy rollback, serving
adjustments, preserved snapshots and account separation. The backend chat contract checks that
legacy false outcomes become unknown while confirmed wins are retained.

For an account-free visual review, launch a Debug build with `--tour --return-preview`. This
uses production views with an eight-day-old meal fixture. Saving still requires a real account;
the fixture never writes food records.

Lighter tracking and optional vacation/unwell context are implemented in [Take it easier](lighter-tracking.md).
See also [logging with less pressure](logging-with-less-pressure.md) for familiar-food shortcuts,
explicit stopping points and qualitative meal notes. Retrospective day marking and a full-day
confirmation workflow remain deferred.

## Production verification — October 19, 2026

Deployed `coach-chat` **version 29** to the linked `nutripulse` project
(`dcabdzuhuixlcgwavtsc`) with JWT verification retained. All five downloaded deployment files
match the tested local entrypoint and dependencies. Only the shared Pulse context changed;
provider, model selection, rate limiting and auth behavior were preserved. The 25 relevant
pre-deployment contract checks passed.

Live HTTP checks passed: unauthenticated POST → 401, CORS preflight → 200, signed-in empty-diary
check-in → 200, and signed-in legacy partial-diary weekly recap → 200. The latter retained a
confirmed 140g floor day, described the 32g partial day as insufficient evidence, and explicitly
said no backfilling was needed.

`SignedInReturnExperienceTests.testReturnMealSyncPartialProgressAndPulse` passed on a fresh
iPhone 17 Pro simulator running iOS 26.5, with **one passed test, zero failures and zero skips**.
It used a disposable, email-confirmed test account and synthetic records through the production
iOS view models, repositories, sync engine and deployed function:

1. Sign in through `AuthViewModel` and load Today with an eight-day logging gap.
2. Retrieve the two-item meal beyond the seven-day local sync window for serving review.
3. Save the meal to today, upload it, and confirm new IDs and unchanged source records.
4. Verify the 32g partial day remains unknown in Progress and the protein goal, while a separate
   confirmed 140g floor day remains a win.
5. Reload Today and confirm the return card stays gone.
6. Generate a live Pulse reply, verify its payload in saved history, and reload it using the
   server-assigned message ID.
7. Generate and save a structured weekly recap. Manually inspect both replies for no invented
   missed goals, no inferred under-eating and no catch-up requirement.

This checks the authenticated iOS data path; it is not a manual tap-through or physical-device
accessibility check. The existing simulator's unrelated session was left alone. The isolated
account was signed out with zero remaining auth sessions, then deleted along with its synthetic
records. Temporary credentials and the dedicated simulator were removed after verification.

The live test skips in ordinary CI. To opt in deliberately, provision an isolated
`footing-return-e2e-…` account with the fixture above, then supply a private
`/private/tmp/footing-return-e2e/ios-credentials.json` containing `email`, `password`, `userId`
and `projectRef`. It refuses to replace an unrelated signed-in session. Run only this test on a
dedicated simulator, inspect its retained synthetic-results attachment, sign out, remove the
test account and delete the credential file afterward. Never use a personal account as the
fixture. Production account administration credentials are never supplied to the iOS test.
