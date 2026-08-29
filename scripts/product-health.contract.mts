import test from "node:test";
import assert from "node:assert/strict";
import { productHealth, type HealthSnapshot } from "../supabase/functions/product-health/health-handler.ts";

const secret = "test-only-health-token-not-a-real-credential";
const request = (value: string | null = secret, method = "GET") => new Request("https://product.test/api/internal/product-health", {
  method, headers: value === null ? {} : { authorization: `Bearer ${value}` },
});
const healthy = async (): Promise<HealthSnapshot> => ({ checks: { database: true }, jobs: [], metrics: { latency_ms: 1 } });

test("missing, incorrect, and cron/admin credentials fail before collection", async () => {
  for (const value of [null, "wrong", "cron-or-admin-token", secret + "suffix"]) {
    const response = await productHealth(request(value), secret, "test", async () => { assert.fail("must not read database"); });
    assert.equal(response.status, 401);
    assert.equal(response.headers.get("cache-control"), "no-store, private");
  }
});
test("missing runtime secret fails closed", async () => {
  assert.equal((await productHealth(request(), undefined, "test", healthy)).status, 503);
});
test("query credentials do not authenticate", async () => {
  assert.equal((await productHealth(new Request("https://product.test?token=" + secret), secret, "test", healthy)).status, 401);
});
test("mutating methods are rejected", async () => {
  assert.equal((await productHealth(request(secret, "POST"), secret, "test", healthy)).status, 405);
});
test("valid token returns the minimal uncached schema", async () => {
  const response = await productHealth(request(), secret, "test", healthy);
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.deepEqual(Object.keys(body).sort(), ["checks", "jobs", "metrics", "observedAt", "schemaVersion", "service", "status"]);
  assert.equal(body.schemaVersion, 1);
  assert.equal(body.status, "ok");
  assert.ok(Math.abs(Date.now() - Date.parse(body.observedAt)) < 5000);
  assert.equal(response.headers.get("vary"), "Authorization");
});
test("failed and stale facts cannot become healthy", async () => {
  for (const checks of [{ database: false }, { database: true, queue: false }]) {
    const response = await productHealth(request(), secret, "test", async () => ({ checks, jobs: [], metrics: {} }));
    assert.notEqual((await response.json()).status, "ok");
  }
  for (const lastSuccessAt of [null, "2020-01-01T00:00:00.000Z"]) {
    const response = await productHealth(request(), secret, "test", async () => ({ checks: { database: true }, jobs: [{ id: "worker", lastSuccessAt, maxAgeMinutes: 60 }], metrics: {} }));
    assert.equal((await response.json()).status, "degraded");
  }
});
test("malformed aggregate values fail closed", async () => {
  const response = await productHealth(request(), secret, "test", async () => ({ checks: { database: true }, jobs: [], metrics: { latency: NaN } }));
  assert.equal(response.status, 503);
});
test("future or invalid job evidence fails closed", async () => {
  for (const lastSuccessAt of ["invalid", "2099-01-01T00:00:00Z"]) {
    const response = await productHealth(request(), secret, "test", async () => ({ checks: { database: true }, jobs: [{ id: "worker", lastSuccessAt, maxAgeMinutes: 60 }], metrics: {} }));
    assert.equal(response.status, 503);
  }
});
test("errors never disclose underlying data or secrets", async () => {
  const response = await productHealth(request(), secret, "test", async () => { throw new Error(secret + " private record sql"); });
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: "health_unavailable" });
});
test("extra collector and job fields are stripped", async () => {
  const response = await productHealth(request(), secret, "test", async () => ({
    checks: { database: true }, metrics: {}, customer: "PRIVATE_SENTINEL",
    jobs: [{ id: "worker", lastSuccessAt: new Date().toISOString(), maxAgeMinutes: 60, error: "PRIVATE_SENTINEL" }],
  }));
  assert.ok(!(await response.text()).includes("PRIVATE_SENTINEL"));
});

