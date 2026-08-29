import { createHash, timingSafeEqual } from "node:crypto";

export type HealthSnapshot = {
  checks: Record<string, boolean>;
  jobs: { id: string; lastSuccessAt: string | null; maxAgeMinutes: number }[];
  metrics: Record<string, number>;
};

const headers = {
  "Cache-Control": "no-store, private",
  "Vary": "Authorization",
  "X-Content-Type-Options": "nosniff",
};

// Separate token per product. Never accept admin, cron, user-session, or query credentials.
export async function productHealth(
  request: Request,
  token: string | undefined,
  service: string,
  collect: () => Promise<HealthSnapshot>,
): Promise<Response> {
  const json = (body: unknown, status = 200) => Response.json(body, { status, headers });
  if (request.method !== "GET") return json({ error: "method_not_allowed" }, 405);
  if (!token) return json({ error: "health_unavailable" }, 503);
  const authorization = request.headers.get("authorization") ?? "";
  const match = /^Bearer ([^\s]+)$/i.exec(authorization);
  const supplied = match?.[1] ?? "";
  const digest = (value: string) => createHash("sha256").update(value).digest();
  if (!supplied || supplied.length > 4096 || !timingSafeEqual(digest(supplied), digest(token))) {
    return json({ error: "unauthorized" }, 401);
  }
  try {
    const snapshot = await collect();
    // Project only the contract; never serialize raw database responses/errors.
    const checks = Object.fromEntries(Object.entries(snapshot.checks));
    const metrics = Object.fromEntries(Object.entries(snapshot.metrics));
    if (!Object.keys(checks).length || Object.values(checks).some(v => typeof v !== "boolean")
      || Object.values(metrics).some(v => typeof v !== "number" || !Number.isFinite(v))) throw new Error("Invalid health evidence");
    const now = new Date();
    const jobs = snapshot.jobs.map(job => {
      if (!job.id || !Number.isFinite(job.maxAgeMinutes) || job.maxAgeMinutes <= 0
        || (job.lastSuccessAt !== null && (!Number.isFinite(Date.parse(job.lastSuccessAt))
          || Date.parse(job.lastSuccessAt) > now.getTime() + 60_000))) throw new Error("Invalid job evidence");
      return { id: job.id, lastSuccessAt: job.lastSuccessAt === null ? null : new Date(job.lastSuccessAt).toISOString(), maxAgeMinutes: job.maxAgeMinutes };
    });
    const stale = jobs.some(job => job.lastSuccessAt === null
      || now.getTime() - Date.parse(job.lastSuccessAt) > job.maxAgeMinutes * 60_000);
    const status = checks.database === false ? "fail"
      : Object.values(checks).some(v => !v) || stale ? "degraded" : "ok";
    return json({ schemaVersion: 1, service, status, observedAt: now.toISOString(), checks, jobs, metrics });
  } catch {
    // No exception messages, credentials, SQL, or response bodies in logs or output.
    return json({ error: "health_unavailable" }, 503);
  }
}

