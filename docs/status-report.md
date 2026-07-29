# Daily status report

Every morning a scheduled Codex task runs `scripts/status-report.mjs` and posts
the results directly in the task. The script:

1. **Health-checks production end to end** — Auth service, database via PostgREST,
   a real sign-in with a dedicated healthcheck account, then one round-trip through
   each critical Edge Function: `search-food` + `get-food` (exercises the FatSecret
   credentials) and `coach-chat` (exercises the Anthropic key — costs a few tokens
   a day, deliberately).
2. **Pulls aggregate usage stats** from the `get_daily_status()` Postgres function
   (migration `20260722000000_daily_status_report.sql`): user counts, yesterday's
   activity per log type, Pulse chat volume, hot rate-limit buckets, aggregate
   feedback counts, and a 7-day food-log trend.
3. **Prints the report as markdown** and uses distinct exit codes so the runner
   can tell a real Footing failure from a runner setup problem.

Exit codes are `0` for Healthy, `1` for a production check that needs attention,
and `2` when the report itself could not run (for example, missing private
settings, or a network policy that blocked the Supabase host — production status
unknown, not an outage).

## Privacy model

The report never contains end-user names, emails, or individual logs. That's
structural, not conventional: the stats can only contain what
`get_daily_status()` returns, and that function returns counts and per-day totals
only. Feedback is grouped into category counts; message text is not returned.
The function is `SECURITY DEFINER`, executable **only by `service_role`**
(revoked from `anon` and `authenticated`), so app clients can never call it.

Accounts whose email ends in `@example.com` — the seeded demo profiles and the
healthcheck account — are excluded from every user-derived number, so the daily
synthetic traffic never inflates the stats.

## One-time setup

1. **Apply the migrations** — the production function is already live. For a
   fresh Supabase project, `supabase db push` applies both the original report
   function and its aggregate-feedback privacy update.

2. **Create the healthcheck account** — sign up a dedicated user whose email ends
   in `@example.com` (e.g. `healthcheck@example.com`) with a strong password.
   Email confirmations are off on this project, so a plain sign-up works:

   ```js
   // e.g. in a node REPL with @supabase/supabase-js and the anon key
   await supa.auth.signUp({ email: 'healthcheck@example.com', password: '...' })
   ```

   The `@example.com` suffix is what keeps it out of the stats (see above).

3. **Create the local private environment file** — copy
   `.env.status-report.example` to `.env.status-report`, fill in the values below,
   and keep it local. The real file is gitignored:

   | Variable | Value |
   |---|---|
   | `SUPABASE_URL` | Project URL (`https://<ref>.supabase.co`) |
   | `SUPABASE_ANON_KEY` | Public anon key |
   | `SUPABASE_SERVICE_ROLE_KEY` | Service role key (server-side only — this is why it lives in environment config, never in the app or repo) |
   | `HEALTHCHECK_EMAIL` | The healthcheck account email |
   | `HEALTHCHECK_PASSWORD` | Its password |

   Optional: `REPORT_TZ` (defaults to `America/Los_Angeles`).

4. **Allow the Supabase host in the runner's network policy** — add your project
   host (e.g. `<ref>.supabase.co`, or `*.supabase.co`) to the allowed domains.
   Sandboxed runners block unlisted hosts, and the script reports that as "checks
   could not run — production status unknown" (exit code 2) rather than as failing
   health checks. Like env vars, this takes effect on the next fresh container.

The morning task lives in Codex, not in this repository. It should point at this
Footing project, load `.env.status-report`, run at the chosen local morning time,
and post the script output without changing code or production data.

## Running manually

```sh
set -a
source .env.status-report
set +a
node scripts/status-report.mjs
```

The report uses only built-in Node features, so it does not need `npm install`.

## Later

- **TelemetryDeck section** — once Phase 1C instrumentation ships (see
  `ENHANCEMENTS.md`), pull time-to-log / edit-rate / retention aggregates from
  the TelemetryDeck Query API into the same report. That's the "is the product
  working" layer on top of this "is the service working" layer.
- **Independent alerting** — the Codex task is one delivery channel; if
  the report ever needs to page harder (push notification, email), a GitHub
  Actions cron running the same script with repo secrets is the
  fallback design (a failed run triggers GitHub's workflow-failure email).
