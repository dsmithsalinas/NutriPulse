# Off-script: Today went sideways

Implemented October 19, 2026. Today has a compact “Today went sideways” action below
water logging, available in normal and lighter tracking. It opens three choices:

- **Help me find something:** send the person’s description to Pulse to find a practical
  option using what is available.
- **Help me make this easier:** ask Pulse for one manageable next step.
- **Just remember what happened:** save an editable day note, with offline support and undo.

A short description is enough (up to 1,000 Unicode scalars); no diary completion or
backfilling is required. The text survives changing between the three choices while the
sheet remains open. Nothing is submitted just by opening or selecting an option.

## Pulse handoff

The two help routes are explicit user-initiated chats, so they do not consume the proactive
attention allowance. The sheet closes before Today calls `AppState.askPulse`, allowing the
existing AI-consent sheet to present normally. Pulse-off displays an explanation and leaves
the note route available. Account ownership is captured when opening the sheet and checked
before either saving or handing off a prompt; pending handoffs are discarded after an
account change. No new model prompt, Edge Function, or notification source was deployed.
Pulse v33 already accepts this user message and the bounded qualitative context.

## Day notes, not meals or lasting memory

Day notes reuse `meal_notes` and its protected, account-specific offline outbox. The migration
`20261020015829_off_script_day_notes.sql` adds `kind`, defaulting to `meal` for existing rows
and older writes, with a `day_context` alternative. RLS policies and grants are unchanged.
The local filename matches the applied remote migration version.

The legacy required `meal` column remains populated for storage compatibility; `kind` controls
meaning. Updated Today, edit, and offline views label these records **Day note**. Pulse’s
context identifies them as `day_context`, rather than calling a travel or workout experience
a snack. Older app versions ignore the additional column and can still decode the row.

No food log, calorie, macro, target credit, tracking-mode change, or approved Pulse memory is
created. Lasting memory requires the existing separate “Remember what helped” approval flow.
There is no automatic AI request when saving. The note-only path also works while Pulse is off.
Saved-on-phone and waiting-to-sync states remain explicit. Edits retain the note kind; undo
uses the existing deletion outbox, including when a sync is in flight.

## Validation and rollout

The backward-compatible migration is applied to Supabase project `dcabdzuhuixlcgwavtsc`.
`coach-chat` remains **v33**; no server source update was required. New app UI ships with the
next app release. No TestFlight archive or upload was created.

- Native unit tests cover the three routes, context validation, explicit user request content,
  legacy decoding, qualitative note encoding, offline restart/edit/sync/account isolation,
  and existing consent/off handoff controls.
- Database contracts run the real migration, verify default/allowed kinds, and preserve
  owner-only access. Endpoint contracts verify day context is retained without approved memory.
- The signed-in `SignedInOffScriptTests.testDayNoteOfflineSyncEditUndoAndNoAutomaticMemory`
  passed on a disposable simulator, using a disposable account with Pulse turned off. It
  verified offline persistence and restart, cloud save/edit with kind retained, undo removing
  the cloud row, zero food logs, and zero automatic approved memories.
- Native screen review covered both the three-choice sheet and the selected day-note form.
  Debug read-only fixtures: `--off-script-preview`, optionally `--off-script-note-preview`.
  Screenshots: `/private/tmp/footing-off-script.png` and `/private/tmp/footing-off-script-note.png`.
- The security advisor has no new findings. The existing informational
  [rate-limit table finding](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
  is unchanged and intentionally denies direct client access.

Cleanup: globally revoked the disposable account’s sessions, verified zero sessions before
account deletion, then verified zero remaining fixture users, sessions, notes, and memories.
Private credentials were removed. Personal accounts and simulators were untouched.
Synthetic-only live execution evidence is in `/private/tmp/footing-off-script-e2e/`.

Final verification: **455 iOS tests passed**, seven opt-in live tests skipped (462 total),
**63 backend contracts passed**, and the separate signed-in native check passed with zero
failures and zero skips. `git diff --check` is clean. The dedicated QA simulator was removed.
