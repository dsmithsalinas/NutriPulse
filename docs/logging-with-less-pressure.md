# Logging with less pressure

## A clear stopping point

Every successful save in the shared food logger shows **Saved for today** (or the
selected historical date), **Done**, and optional **Add something else**. Returning
users also see **No need to fill in previous days**. The recent-meal review has the
same stopping point. These messages confirm a saved record, never adequate intake
or a complete diary. Talk's protein-floor tile stays hidden while goal prompts are
suppressed, including Take it easier and an unavailable tracking preference.

## Familiar foods after a break

The default Talk surface offers up to three familiar foods below the talk and
typing sections, in the same scrolling content. Suggestions rank frequency, then recency, within the latest 200
food records, deduplicate by food item, and retain the latest portion and nutrition
snapshot. Source dates are visible; tapping opens a serving review before saving.
Favorites also keeps up to 20 familiar foods beyond the former 72-hour cutoff and
reviews recent foods before repeating them. Existing favorites remain available.
Older date groups include the calendar date so separate weeks do not collapse into
one weekday. Existing recent-meal review remains available on the return card.

History is fetched from the account with RLS and an explicit owner filter. A failed
history fetch falls back to that account's local records. Account changes invalidate
results. Saving a familiar food uses the local-first food log/sync path, creates a
new entry ID, and preserves the source record and nutrition snapshots.

## Meal notes

**Just leave a meal note** is available from the logger. Choose the meal in the
existing header, add up to 1,000 Unicode scalar characters, and save. Notes appear
on the selected Today date with Edit/Delete controls and **Nutrition unknown · not
included in totals**. Deletion requires confirmation. Historical notes retain their
date. A note on today removes the return invitation and avoids an empty-diary message.

Notes live in a separate owner-protected `meal_notes` table with no nutrition
columns. They never create zero-calorie food items, count toward numeric totals,
confirm a full diary, or change goals. They can remain notes indefinitely; there is
no automatic estimation or completion task. Account deletion cascades to notes.

Note saves/edits/deletes now commit locally and queue for sync. See
[logging comfort](logging-comfort.md) for durable offline notes, undo, named usual
meals and remembered logging methods. Failed note loads are shown with Retry and
do not establish that the person abandoned logging.

Pulse receives today's notes as bounded qualitative context under existing AI
consent and enablement checks. The shared prompt treats note text as untrusted data,
forbids inferred nutrition or adherence, and makes later detail optional. No note
text is sent to telemetry. The changed prompt hash requires updating `pulse-eval`
before another model evaluation.

## Verification — October 19, 2026

- Final full iOS suite: 429 passed, zero failures, four opt-in live cases skipped
  after temporary credentials were removed. The two new live cases passed separately.
- 35 backend/database contracts pass, including note RLS, owner CRUD, cross-account
  restrictions, blank/oversized content, account deletion, and Pulse sanitization.
- Signed-in `testNoteLifecycleAndFamiliarFoodAfterBreak`: one pass, zero failures or
  skips, using real iOS repositories/view models and an isolated confirmed account.
  It checked note create/edit/delete, idempotent retry, a note-only day with no food
  rows, eight-day-old familiar foods, and a reviewed half-portion synced with a new ID.
- Signed-in `testPulseUsesSavedNoteWithoutInventingNutrition`: one pass, zero failures
  or skips. Pulse referenced a picnic note not present in the user's message, explicitly
  declined to infer nutrition, persisted the reply, and left food records unchanged.
- Pulse `coach-chat` v31 is deployed to `dcabdzuhuixlcgwavtsc`, with JWT verification
  retained and all five downloaded files identical to the tested local payload.
- Both additive note migrations are applied with owner RLS. The security advisor
  reports no note-table issue; its existing `rate_limits` no-policy INFO remains
  unchanged (intentional default-deny for clients).

The live checks use a dedicated iPhone 17 Pro / iOS 26.5 simulator and the disposable
fixture documented in [return experience](return-experience.md). Sign-out was checked
for zero sessions before account deletion. Credentials and the test account are
removed afterward, along with the dedicated simulator. Existing personal simulator
sessions are never replaced.

Visual review uses native views with synthetic data: Debug `--tour --logging-preview`
and `--tour --meal-note-preview`. Screenshots do not establish full accessibility
compliance or physical-device interaction. No TestFlight build or upload was made.
