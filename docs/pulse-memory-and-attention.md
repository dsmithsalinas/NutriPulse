# Pulse memory, attention, and breakfast check-ins

Implemented October 19, 2026; backend deployed and verified the same day. This is application-owned memory attached to a
Supabase Auth user UUID, retrieved for each request. It is not model training, a global
chat session, or a shared pool of memories.

## Experience

- Profile → Pulse’s attention: at most one optional proactive Pulse notification per
  local day, or keep things quiet. Existing notification permissions and feature
  toggles still apply; choosing one does not turn notifications on. Smart coaching
  and Monday’s outlook share the ceiling. User-started chat and shot reminders do not.
- Pulse can propose a `helpful` memory for a practical experience explicitly stated
  in the current message. The card requires Save. It cannot write to the memory table.
  Medical inferences, diagnoses, dosing advice, conclusions from missing logs, and
  automatic extraction from meal notes are prohibited by the prompt.
- What Pulse knows → What helps you: add, edit, and forget approved practical memories.
  A meal note’s “Remember what helped” opens an editable draft and requires approval.
  Saving/editing/forgetting requires a connection; failure never reports success.
- A saved usual breakfast can be explicitly selected for simple check-ins from What
  Pulse knows or the usual-meals list. Today offers “Had my usual,” or a route to notes
  and detailed logging. A simple check-in is optional, undoable, and never creates FoodLog
  entries or nutrition. Days remain unassessed unless measured data confirms a win.
- Simple check-ins require a connection in this first implementation. Existing meal notes
  and detailed logging retain their offline behavior. Nothing automatically transitions
  a person to lighter tracking based on sparse records or inferred adherence.

## User isolation

1. `pulse_memories.user_id` references `auth.users(id)` with cascading deletion. RLS
   restricts SELECT/INSERT/UPDATE/DELETE to `auth.uid() = user_id`. UPDATE has both USING
   and WITH CHECK. Anonymous/public grants are revoked. Reassignment and upsert takeover
   are rejected. Attention, reservations, breakfast preferences and check-ins use the same
   ownership rule. A composite FK prevents a breakfast choice pointing to another owner’s
   usual meal.
2. `coach-chat` verifies the bearer token with `auth.getUser()`, queries with that caller’s
   JWT (not service-role), and explicitly filters by verified `user.id`. A second allowlist
   discards foreign-owner/unapproved/malformed rows even if a repository returns them.
   Client-provided approved-memory fields are never accepted. Failed retrieval is unavailable,
   never a client-memory fallback. Only the current user’s approved memory goes in the
   uncached dynamic context. No process-global memory cache or provider conversation ID exists.
3. The native memory store has no disk cache or offline write queue. Auth changes clear its
   in-memory list immediately. Generation fences reject late load/save completions, including
   A → B → A. Approval carries the screen/message’s expected owner so an old screen cannot
   save A’s preference into B’s account. Data repositories write a fixed owner; RLS remains
   authoritative if the token changes during transport.
4. Existing Pulse profile settings and queued preferences now have account-specific keys.
   Unattributable legacy shared keys are discarded. A previous account’s allergies/preferences
   are cleared immediately. MainTabView is recreated on account changes; chat history queries
   explicitly filter by owner and chat requests/replies check that the account is still current.
5. Forget performs an owner-scoped DELETE and the next request retrieves fresh state. It does
   not erase historical messages; the UI explains that history can be cleared separately.
   Already-started model requests cannot be retroactively recalled. Account deletion cascades
   all new cloud records. Approved-memory content is not added to telemetry or server logs.

These controls enforce user-to-user isolation; access by authorized project administrators
and AI-provider processing follow Footing’s existing infrastructure and consent policies.
They do not constitute a promise that software can never have a security defect.

## Attention scheduling

`reserve_pulse_attention` is SECURITY INVOKER, derives its owner from `auth.uid()`, and
serializes reservations per user. A unique owner/day key provides one allowance across
devices and notification categories. A request token makes a retry/replacement idempotent.
No allowance is refunded for dismissed/cancelled notifications; fewer interruptions are
preferable to duplicate notifications. Unknown/offline preferences fail closed.

Monday reminders are now non-repeating, reserved for the next occurrence. Launch/foreground
reconciles the next reminder. This avoids an unlimited repeating trigger bypassing the daily
budget. Quiet cancels pending notifications on the current device immediately; another
already-offline device applies changed preferences on its next refresh. Old app versions
cannot participate in this new ledger; the shared guarantee applies to updated clients.
Shot reminders are unaffected.

## Compatibility and rollout

Local migration: `20261020014052_pulse_memory_and_attention.sql` (created using the Supabase CLI).
Deploy migration before the updated `coach-chat` and app. New tables unavailable: memory UI
shows retry; proactive Pulse notifications stay quiet; existing manual chat remains usable.

`pulseMemoryVersion: 1` gates helpful proposals for capable clients. New helpful proposal
cards are transient and are filtered out of persisted chat payloads so older app versions
can still decode history. Existing allergy/love/avoid cards retain their behavior. Approved
memories themselves persist across devices and sessions.

The reviewed migration and `coach-chat` v33 are deployed to `dcabdzuhuixlcgwavtsc`.
All five downloaded source files exactly match the approved local bundle; JWT verification
remains enabled. The migration file is aligned to the applied remote version
`20261020014052` to prevent a later push from attempting to apply it twice.
The signed-in two-account check is complete (details below). No TestFlight archive or upload
was created. The app changes still require the next app release to reach installed clients.

## Verification

- Native tests cover explicit approval, edit/forget, owner filtering, immediate reset,
  A → B → A stale loads, late approvals, former-screen ownership, failed refresh/save,
  shared legacy key disposal, and qualitative breakfast encoding.
- PGlite runs the actual migration and exercises two authenticated roles plus anonymous
  access: forbidden reads/writes/reassignment/upserts, attention ownership/quiet/one-slot
  claims, cross-owner breakfast FK rejection, and account-delete cascades.
- Endpoint contracts execute the actual coach-chat and prompt/provider modules with a stub
  model: verified owner filtering, approved-only retrieval, client injection rejection,
  fresh retrieval after forget, cache isolation, lookup failure, and older-client compatibility.
- Full iOS and relevant backend contract results are recorded after final validation.

### Local results

- Final ordinary iOS suite: **448 passed, 6 opt-in live tests skipped, 0 failures** (454 total).
- Relevant backend contracts: **60 passed, 0 failures**.
- `git diff --check`: clean.
- Native read-only UI review on a disposable iPhone simulator: attention/memory settings
  and breakfast check-in layouts inspected. Fixtures: `--pulse-week-preview`, optionally
  `--breakfast-checkin-preview --breakfast-saved-preview`. These do not read a real account.
- Separate signed-in native run: **1 passed, 0 failures, 0 skips**, with eight live checkpoints.
- Live HTTP checks: **10 passed**, using two disposable accounts and real Pulse replies.


## Production verification — October 19, 2026

Deployment: migration `20261020014052_pulse_memory_and_attention.sql`, followed by
`coach-chat` **v33**, ACTIVE, JWT verification on. All five source files downloaded and
compared byte-for-byte to the reviewed deployment bundle.

Live HTTP coverage:

- Anonymous table access and unsigned Pulse requests are rejected.
- In both directions, A and B cannot read, edit, delete, insert for, reassign, or upsert
  over the other account’s memories.
- Each account’s actual Pulse response recalls only its own saved breakfast preference.
- An edit reaches the next reply; forget removes retrieval. Forged client memory and owner
  fields do not restore deleted memory or fetch B’s memory for A.
- A helpful-memory proposal is returned without a new memory row being saved.
- Two independent A sign-ins concurrently claim one daily allowance: exactly one succeeds.
  B has its own allowance. Quiet blocks both A sessions.
- Breakfast records cannot reference another owner’s usual meal, contain no nutrition,
  create no food logs, and support deletion. Pulse describes their amounts as unknown.

Native `SignedInPulseMemoryTests.testTwoAccountsKeepMemoryAttentionAndBreakfastPrivate`
uses Supabase sign-in, the production stores/repositories, and the deployed Pulse function
on a dedicated simulator. It verifies independent-store persistence, edit, quiet/one allowance,
account resets, rejected stale approvals and upserts, separate B memory and allowance,
A → B → A persistence, breakfast undo, disable, and forget. The simulator run is code-signed
so the normal authentication keychain is available.

The security advisor shows no new findings. Its existing informational
[RLS-with-no-policy finding](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
for `rate_limits` is unchanged: this table deliberately denies direct client access.
All five new tables have RLS and owner policies; the reservation RPC remains SECURITY INVOKER.

Cleanup: globally revoked both test accounts’ sessions, confirmed **zero auth sessions**
for each before deleting them, then verified **zero fixture users, sessions, memories,
attention preferences/reservations, breakfast preferences/check-ins, and usual meals**.
Private keys and temporary account credentials were removed. The dedicated simulator was
removed; personal simulator sessions were untouched.

Synthetic-only execution reports are in `/private/tmp/footing-memory-e2e/`:
`http-results.json`, `native-results.json`, `native-signed-test.log`, `final-suite.log`,
`cleanup.json`, and `deployment-manifest.json`. No credentials remain in that directory.
