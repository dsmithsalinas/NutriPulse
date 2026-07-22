# Daily status report

Every morning a GitHub Actions cron (`.github/workflows/status-report.yml`) runs
`scripts/status-report.mjs`, which:

1. **Health-checks production end to end** — Auth service, database via PostgREST,
   a real sign-in with a dedicated healthcheck account, then one round-trip through
   each critical Edge Function: `search-food` + `get-food` (exercises the FatSecret
   credentials) and `coach-chat` (exercises the Anthropic key — costs a few tokens
   a day, deliberately).
2. **Pulls aggregate usage stats** from the `get_daily_status()` Postgres function
   (migration `20260722000000_daily_status_report.sql`): user counts, yesterday's
   activity per log type, Pulse chat volume, hot rate-limit buckets, new feedback
   (with message text), and a 7-day food-log trend.
3. **Emails the report** via Resend, then exits non-zero if anything failed — so a
   broken morning also triggers GitHub's workflow-failure email as a second alert
   channel, even when the report email itself can't go out.

## Privacy model

The report never contains end-user names, emails, or individual logs. That's
structural, not conventional: the stats email can only contain what
`get_daily_status()` returns, and that function returns counts and per-day totals
only — plus the text of `feedback` rows, which users deliberately submitted to the
team. The function is `SECURITY DEFINER`, executable **only by `service_role`**
(revoked from `anon` and `authenticated`), so app clients can never call it.

Accounts whose email ends in `@example.com` — the seeded demo profiles and the
healthcheck account — are excluded from every user-derived number, so the daily
synthetic traffic never inflates the stats.

## One-time setup

1. **Apply the migration** — run
   `supabase/migrations/20260722000000_daily_status_report.sql` in the Supabase
   SQL Editor (or `supabase db push`).

2. **Create the healthcheck account** — sign up a dedicated user whose email ends
   in `@example.com` (e.g. `healthcheck@example.com`) with a strong password.
   Email confirmations are off on this project, so a plain sign-up works:

   ```js
   // e.g. in a node REPL with @supabase/supabase-js and the anon key
   await supa.auth.signUp({ email: 'healthcheck@example.com', password: '...' })
   ```

   The `@example.com` suffix is what keeps it out of the stats (see above).

3. **Create a Resend account** (free tier is plenty: one email/day) and grab an
   API key. Without a verified domain, Resend only delivers from
   `onboarding@resend.dev` **to the email address that owns the Resend account** —
   so create the account with the report recipient address, or verify a domain
   and set `REPORT_FROM` in the workflow.

4. **Add GitHub Actions secrets** (repo → Settings → Secrets and variables →
   Actions):

   | Secret | Value |
   |---|---|
   | `SUPABASE_URL` | Project URL (`https://<ref>.supabase.co`) |
   | `SUPABASE_ANON_KEY` | Public anon key |
   | `SUPABASE_SERVICE_ROLE_KEY` | Service role key (server-side only — this is why it lives in Actions secrets, never in the app) |
   | `HEALTHCHECK_EMAIL` | The healthcheck account email |
   | `HEALTHCHECK_PASSWORD` | Its password |
   | `RESEND_API_KEY` | From the Resend dashboard |

   Recipient and timezone are plain env vars in the workflow file
   (`REPORT_TO`, `REPORT_TZ`) — edit there to change them.

5. **Test it** — Actions tab → "Daily status report" → *Run workflow*. The full
   report also prints to the job log, so you can verify content without waiting
   on email delivery.

## Schedule

`0 13 * * *` UTC ≈ 6:00 AM Pacific during PDT (5:00 AM during PST). GitHub cron
has no timezone support, so the local time shifts an hour across DST — adjust the
expression if that matters.

## Running locally

```sh
cd scripts && npm install
SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_SERVICE_ROLE_KEY=... \
HEALTHCHECK_EMAIL=... HEALTHCHECK_PASSWORD=... \
node status-report.mjs
```

Leave `RESEND_API_KEY` unset to print the report to stdout without emailing.

## Later

- **TelemetryDeck section** — once Phase 1C instrumentation ships (see
  `ENHANCEMENTS.md`), pull time-to-log / edit-rate / retention aggregates from
  the TelemetryDeck Query API into the same email. That's the "is the product
  working" layer on top of this "is the service working" layer.
- Tighten to twice daily (or add an hourly checks-only run) if TestFlight beta
  traffic warrants it.
