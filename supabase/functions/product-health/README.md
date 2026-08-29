# Protected product health

GET https://dcabdzuhuixlcgwavtsc.supabase.co/functions/v1/product-health. Database reachability is a HEAD request to an existing operational table; Auth reachability is a health probe. Neither response body is read. Output contains boolean checks and aggregate latency only. Do not reuse get_daily_status: it includes nutrition/medication activity and keyed rate-limit buckets. No customer records, synthetic accounts or new database are needed.

No authoritative product job ledger exists: jobs is empty, not evidence that scheduled jobs succeeded. Existing external status-report jobs are untouched.

Tests: `node --test scripts/product-health*.contract.mts`. Deno: `npx deno check --no-config --no-lock --node-modules-dir=none supabase/functions/product-health/index.ts`. Deploy only this function to project dcabdzuhuixlcgwavtsc with JWT verification disabled: the handler verifies the dedicated token first.

Authorization: Bearer token from hosted runtime secret `FOOTING_HEALTH_TOKEN`, matching the same named GitHub Actions secret in product-health-agent. Never reuse other credentials or commit token values.

The endpoint performs no writes. It returns schemaVersion 1 with deterministic status, observedAt, checks, jobs and metrics. Missing runtime configuration or collection failure returns generic 503; invalid credentials return 401 before any backend access; non-GET returns 405. Every response is no-store. Valid observations use HTTP 200 even when status is degraded/fail so the agent retains the evidence. Errors and raw rows are never logged or returned.

