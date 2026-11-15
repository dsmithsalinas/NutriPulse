// Requests only an Apple TEST notification. Never prints JWTs or signed payloads.
import { createPrivateKey, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

const environment = process.argv[2];
if (!['Sandbox', 'Production'].includes(environment) || process.argv.length > 3) {
  console.error('Usage: node scripts/apple-notification-check.mjs Sandbox|Production');
  process.exit(1);
}

async function main() {
  const key = createPrivateKey(readFileSync(join(homedir(), '.config/footing/apple/SubscriptionKey_887N4J9K9Y.p8')));
  const encoded = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = encoded({ alg: 'ES256', kid: '887N4J9K9Y', typ: 'JWT' }) + '.' + encoded({
    iss: 'f2f9bd13-1260-4024-81d2-e0d92a55db01', iat: now, exp: now + 300,
    aud: 'appstoreconnect-v1', bid: 'com.dustin.nutripulse.app',
  });
  const jwt = unsigned + '.' + sign('sha256', Buffer.from(unsigned), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  const origin = environment === 'Production' ? 'https://api.storekit.apple.com' : 'https://api.storekit-sandbox.apple.com';
  async function request(path, method = 'GET') {
    const response = await fetch(origin + path, { method, headers: { Authorization: 'Bearer ' + jwt }, signal: AbortSignal.timeout(15000) });
    let data = {};
    try { data = await response.json(); } catch { /* Empty error responses are valid. */ }
    return { http: response.status, data };
  }
  const sent = await request('/inApps/v1/notifications/test', 'POST');
  console.log(JSON.stringify({ environment, phase: 'request', http: sent.http,
    ...(typeof sent.data.errorCode === 'number' ? { appleErrorCode: sent.data.errorCode } : {}) }));
  if (sent.http !== 200 || typeof sent.data.testNotificationToken !== 'string') {
    process.exitCode = 2;
    return;
  }
  for (let attempt = 0; attempt < 6; attempt++) {
    await delay(5000);
    const status = await request('/inApps/v1/notifications/test/' + encodeURIComponent(sent.data.testNotificationToken));
    const attempts = (Array.isArray(status.data.sendAttempts) ? status.data.sendAttempts : []).map(item => ({
      result: typeof item.sendAttemptResult === 'string' ? item.sendAttemptResult.slice(0, 80) : null,
      date: typeof item.attemptDate === 'number' ? item.attemptDate : null,
    }));
    console.log(JSON.stringify({ environment, phase: 'delivery', http: status.http, attempts }));
    if (status.http === 200 && attempts.some(item => item.result === 'SUCCESS')) return;
    if (status.http !== 200 && status.http !== 404) break;
  }
  process.exitCode = 2;
}

main().catch(() => {
  console.error('Notification check failed. Check local key access or connectivity; no credentials or payloads logged.');
  process.exitCode = 1;
});
