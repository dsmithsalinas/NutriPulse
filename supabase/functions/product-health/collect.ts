type Environment = Record<string, string | undefined>;

export async function collectHealth(env: Environment, fetcher: typeof fetch = fetch) {
  const key = env.SUPABASE_SECRET_KEYS
    ? (JSON.parse(env.SUPABASE_SECRET_KEYS) as Record<string, string>).default
    : env.SUPABASE_SERVICE_ROLE_KEY;
  const url = env.SUPABASE_URL;
  if (!url || !key) throw new Error("Backend unavailable");
  const headers = { apikey: key, ...(key.startsWith("eyJ") ? { Authorization: `Bearer ${key}` } : {}) };
  const started = Date.now();
  const probe = async (path: string, method: string) => {
    const response = await fetcher(`${url}${path}`, { method, headers, redirect: "error", cache: "no-store", signal: AbortSignal.timeout(8_000) });
    await response.body?.cancel();
    return response.ok;
  };
  // HEAD proves database/API reachability without reading a single row. Never call
  // get_daily_status here: it includes nutrition/medication activity and keyed buckets.
  const [database, auth] = await Promise.all([
    probe("/rest/v1/rate_limits?select=bucket&limit=0", "HEAD"),
    probe("/auth/v1/health", "GET"),
  ]);
  return {
    checks: { database, auth },
    // No authoritative product-job ledger exists. Do not fabricate last-success times.
    jobs: [],
    metrics: { backend_latency_ms: Date.now() - started },
  };
}
