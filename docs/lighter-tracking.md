# Take it easier

Profile → Tracking and Today → Need a lighter week? open the same account setting.
Choose 3 days, 1 week, or Until I’m ready, with optional Vacation, Feeling unwell,
or Busy stretch context. Editing context can preserve the current end time.
Return to usual tracking ends it immediately and clears the reason and dates.

While active, Today replaces goal rings, progress totals and goal coaching with a
quieter logging surface. Food entries and water logging remain available. Pulse
remains available according to the existing enablement and consent preferences.
Goals and history are preserved; partial and empty diaries remain unassessed.
Medication reminders and shot check-ins retain their independent settings.

Smart coaching and the weekly Strong Week reminder pause without changing saved
preferences. Pending and delivered smart notifications are removed. Notification
scheduling rechecks account and setting after awaits, and stale goal-notification
routes do not reopen goal coaching. A timed stretch ending now waits for an explicit choice before ordinary eligibility
resumes. See [logging comfort](logging-comfort.md) for that flow.

The preference is stored in `tracking_preferences` with owner-only RLS. An
account-scoped cache supports startup; sign-out clears the prior account cache.
Failed refreshes suppress unsolicited goal prompts until a successful refresh.
Saves require a successful server response. Other devices refresh on foreground;
an offline background device cannot immediately cancel an already scheduled alert.

Pulse's server lookup overrides client mode claims and drops expired context.
The new prompt asks for optional support without quotas, catching up, or grading.
Feeling unwell is user-supplied context, never a diagnosis or medication instruction.

## Verification and rollout

The migration `20261019220103_lighter_tracking_preferences.sql` was applied to the
linked `nutripulse` project on October 19, 2026. Thirty backend/database contracts
pass, covering owner isolation, invalid writes, expiry, server authority and failures.
The full iOS suite passed: 426 tests, zero failures; the opt-in live test skipped.
The suite includes duration/DST, explicit-null resume encoding, cache/account
isolation, failed saves/refreshes and unchanged reminder preferences.

Deployed `coach-chat` version 30 to project `dcabdzuhuixlcgwavtsc` on October 19,
2026, following explicit owner authorization. JWT verification remains enabled.
All five downloaded deployment files exactly match the tested local files.
Unauthenticated POST returns 401 and CORS preflight returns 200.

`SignedInLighterTrackingTests.testPauseLoggingPulseAndResume` passed on a dedicated
iPhone 17 Pro simulator (iOS 26.5): one test, zero failures, zero skips.
The opt-in signed-in iOS check exercises the real AuthViewModel, tracking store,
PostgREST persistence, TodayViewModel, food sync and CoachViewModel. It verifies
vacation pause persistence after reload, two food entries synced while paused,
Pulse chat persistence, editing to feeling unwell without extending the end,
and resuming with reason/start/end explicitly cleared and saved reminder
preferences unchanged. Live replies were retained in the synthetic test report.
A direct SQL check confirmed cleared settings and zero auth sessions after sign-out.
The disposable account, temporary credentials and dedicated simulator were removed
after verification. The existing simulator and its unrelated session were left alone.

Run `SignedInLighterTrackingTests` alone on a dedicated simulator with the private
fixture described in [return experience](return-experience.md). Never replace an
existing personal session. The test skips without the opt-in fixture. This is a
signed-in data-path check, not a manual tap-through or physical notification test.

Debug visual review: `--tour --lighter-preview` uses the production Today surface
with synthetic entries. This is not a signed-in persistence or notification test.
