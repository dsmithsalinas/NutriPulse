import test from "node:test";
import assert from "node:assert/strict";
import { collectHealth } from "../supabase/functions/product-health/collect.ts";

test("probes backend without reading health or customer data", async () => {
  const calls: string[] = [];
  const result = await collectHealth({ SUPABASE_URL: "https://backend.test", SUPABASE_SERVICE_ROLE_KEY: "test-key" }, async (url, init) => {
    calls.push(String(url));
    if (String(url).includes("/rest/v1/")) assert.equal(init?.method, "HEAD");
    assert.equal(init?.redirect, "error");
    return new Response("PRIVATE_SENTINEL");
  });
  assert.equal(calls.length, 2);
  assert.ok(calls.every(url => !/daily_status|food|weight|glp1|profiles/.test(url)));
  assert.deepEqual(result.checks, { database: true, auth: true });
  assert.ok(!JSON.stringify(result).includes("PRIVATE_SENTINEL"));
});
test("backend denial remains a failed check", async () => {
  const result = await collectHealth({ SUPABASE_URL: "https://backend.test", SUPABASE_SERVICE_ROLE_KEY: "test-key" }, async () => new Response(null, { status: 403 }));
  assert.equal(result.checks.database, false);
});
