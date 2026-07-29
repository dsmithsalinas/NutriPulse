# Daily status report

Every morning a scheduled Claude Code routine wakes the owner's Claude session,
runs `scripts/status-report.mjs`, and posts the results directly in the
conversation. The script:

1. **Health-checks production end to end** — Auth service, database via PostgREST,
   a real sign-in with a dedicated healthcheck account, then one round-trip through
   each critical Edge Function: `search-food` + `get-food` (exercises the FatSecret
   credentials) and `coach-chat` (exercises the Anthropic key — costs a few tokens
   a day, deliberately).
2. **Pulls aggregate usage stats** from the `get_daily_status()` Postgres function
   (migration `20260722000000_daily_status_report.sql`): user counts, yesterday's
   activity per log type, Pulse chat volume, hot rate-limit buckets, new feedback
   (with message text), and a 7-day food-log trend.
3. **Prints the report as markdown** and exits with a meaningful code: `0` all
   green, `1` one or more checks/stats failed, `2` the checks couldn't run at all
   (runner's network policy blocked the Supabase host — production status
   unknown, not an outage).

## Privacy model

The report never contains end-user names, emails, or individual logs. That's
structural, not conventional: the stats can only contain what
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

3. **Add environment variables to the Claude Code environment** (claude.ai →
   Code → the Footing environment → settings → environment variables), so
   every session — including the scheduled morning firing — can run the script:

   | Variable | Value |
   |---|---|
   | `SUPABASE_URL` | Project URL (`https://<ref>.supabase.co`) |
   | `SUPABASE_ANON_KEY` | Public anon key |
   | `SUPABASE_SERVICE_ROLE_KEY` | Service role key (server-side only — this is why it lives in environment config, never in the app or repo) |
   | `HEALTHCHECK_EMAIL` | The healthcheck account email |
   | `HEALTHCHECK_PASSWORD` | Its password |

   Optional: `REPORT_TZ` (defaults to `America/Los_Angeles`).

4. **Allow the Supabase host in the environment's network policy** — in the same
   environment settings dialog, add your project host (e.g.
   `<ref>.supabase.co`, or `*.supabase.co`) to the allowed domains. Sandboxed
   runners block unlisted hosts, and the script reports that as "checks could
   not run — production status unknown" (exit code 2) rather than as failing
   health checks. Like env vars, this takes effect on the next fresh container.

The morning routine itself is created from a Claude session (it lives in the
Claude account, not in this repo). If it's ever lost, ask Claude to recreate it:
a daily trigger at ~6am Pacific whose prompt is to run this script and post the
report in the conversation.

## Running manually

```sh
cd scripts && npm install
SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_SERVICE_ROLE_KEY=... \
HEALTHCHECK_EMAIL=... HEALTHCHECK_PASSWORD=... \
node status-report.mjs
```

Or, in a Claude session with the env vars configured: "run the status report".

## Later

- **TelemetryDeck section** — once Phase 1C instrumentation ships (see
  `ENHANCEMENTS.md`), pull time-to-log / edit-rate / retention aggregates from
  the TelemetryDeck Query API into the same report. That's the "is the product
  working" layer on top of this "is the service working" layer.
- **Independent alerting** — the in-session routine is one delivery channel; if
  the report ever needs to page harder (push notification, email), a GitHub
  Actions cron running the same script with repo secrets is the
  fallback design (a failed run triggers GitHub's workflow-failure email).
