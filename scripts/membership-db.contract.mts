import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
const id = (n: number) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const query = async (sql: string, args: any[] = []) => (await db.query<any>(sql, args)).rows;
const snapshot = async (n: number) => (await query('select membership_snapshot($1) as value', [id(n)]))[0].value;
const claim = async (n: number) => query('select claim_founding_membership($1) as value', [id(n)]);
before(async () => {
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create table auth.users(id uuid primary key,email_confirmed_at timestamptz,phone_confirmed_at timestamptz);
    grant usage on schema public,auth to anon,authenticated,service_role;
    `);
  await db.exec(readFileSync(new URL('../supabase/migrations/20261115021855_premium_membership.sql', import.meta.url), 'utf8'));
  for (let n = 1; n <= 55; n++) await query('insert into auth.users(id,email_confirmed_at) values($1,now())', [id(n)]);
});
after(async () => db.close());
test('clients cannot mint, read or edit premium grants, counters or privileged RPCs', async () => {
  for (const role of ['anon', 'authenticated']) {
    await db.exec(`set role ${role}`);
    for (const sql of ['select * from founding_memberships', 'update membership_campaign set claimed=0',
      `select claim_founding_membership('${id(1)}')`, `select membership_snapshot('${id(1)}')`,
      `select reserve_membership_ai('${id(1)}','pulse',100,100)`]) await assert.rejects(db.exec(sql));
    await db.exec('reset role');
  }
});
test('campaign is closed until release activation; nonexistent owners cannot consume places', async () => {
  await assert.rejects(claim(1), /founder_unavailable/);
  await db.exec('update membership_campaign set enabled=true');
  await assert.rejects(claim(99), /foreign key/);
  assert.equal((await query('select claimed from membership_campaign'))[0].claimed, 0);
});
test('claim is repeatable without extra places or extending the three calendar months', async () => {
  await claim(1); const first = await snapshot(1); await claim(1);
  assert.equal((await snapshot(1)).founder_expires_at, first.founder_expires_at);
  assert.equal((await query('select claimed from membership_campaign'))[0].claimed, 1);
  assert.equal((await query("select expires_at=claimed_at+interval '3 months' as exact from founding_memberships"))[0].exact, true);
});
test('last-place attempts never exceed 50 and retries after sellout retain the original grant', async () => {
  // PGlite serializes requests; production multi-connection lock contention is separately
  // exercised by membership-postgres-test.py. This checks SQL invariants and retry semantics.
  const attempts = await Promise.allSettled(Array.from({ length: 53 }, (_, i) => claim(i + 2)));
  assert.equal(attempts.filter(x => x.status === 'fulfilled').length, 49);
  assert.equal((await query('select count(*)::int as n from founding_memberships'))[0].n, 50);
  assert.equal((await query('select claimed from membership_campaign'))[0].claimed, 50);
  await claim(1);
  assert.equal((await snapshot(1)).founder_available, false);
});
test('entitlement expiration, per-user limits and global circuit breaker are enforced atomically', async () => {
  const reserve = async (n: number, bucket = 'pulse', limit = 2, global = 3) => (await query('select reserve_membership_ai($1,$2,$3,$4) as result', [id(n),bucket,limit,global]))[0].result;
  assert.equal(await reserve(54), 'membership_required');
  assert.equal(await reserve(1), 'allowed'); assert.equal(await reserve(1), 'allowed');
  assert.equal(await reserve(1), 'membership_limit_reached');
  assert.equal(await reserve(2, 'food'), 'allowed');
  assert.equal(await reserve(3), 'ai_temporarily_unavailable');
  await query("update founding_memberships set claimed_at=now()-interval '4 months',expires_at=now()-interval '1 month' where user_id=$1", [id(3)]);
  assert.equal(await reserve(3), 'membership_required');
});
test('paid grants reject takeover, stale state, refunds, expired grace and stale verification', async () => {
  const record = async (owner: number, status: number, revoked = false, signedOffset = 0, checkedOffset = 0, expiryOffset = 86400) => query(`select record_apple_subscription($1,'apple-original','Production','com.dustin.nutripulse.premium.monthly','tx',$2,now()+$3*interval '1 second',$4,now()+$5*interval '1 second',now()+$6*interval '1 second')`, [id(owner),status,expiryOffset,revoked,signedOffset,checkedOffset]);
  await record(54, 1);
  assert.ok(new Date((await snapshot(54)).premium_expires_at) > new Date());
  await assert.rejects(record(55, 1), /subscription_owner_mismatch/);
  await record(54, 5, true, 1, 1);
  assert.equal((await snapshot(54)).premium_expires_at, null);
  await record(54, 1, false, -100, -100);
  assert.equal((await snapshot(54)).premium_expires_at, null);
  await record(54, 4, false, 2, 2, -1);
  assert.ok(new Date((await snapshot(54)).premium_expires_at) < new Date());
  await db.exec('delete from apple_subscriptions');
  await record(54, 1, false, -100000, -100000);
  assert.ok(new Date((await snapshot(54)).premium_expires_at) < new Date());
});
test('sandbox purchases never grant production access without a server allowlist decision', async () => {
  await query(`select record_apple_subscription($1,'sandbox-original','Sandbox','com.dustin.nutripulse.premium.monthly','sandbox-tx',1,now()+interval '1 day',false,now(),now())`, [id(55)]);
  assert.equal((await snapshot(55)).premium_expires_at,null);
  const allowed = (await query('select membership_snapshot($1,true) as value',[id(55)]))[0].value;
  assert.ok(new Date(allowed.premium_expires_at)>new Date());
  assert.equal((await query("select reserve_membership_ai($1,'pulse',60,100,false) as result",[id(55)]))[0].result,'membership_required');
  assert.equal((await query("select reserve_membership_ai($1,'pulse',60,100,true) as result",[id(55)]))[0].result,'allowed');
  await query('delete from auth.users where id=$1',[id(55)]);
});
test('deletion removes private billing/usage data without reopening a founding place', async () => {
  await query('delete from auth.users where id=$1', [id(1)]);
  assert.equal((await query('select count(*)::int as n from founding_memberships where user_id=$1',[id(1)]))[0].n,0);
  assert.equal((await query('select count(*)::int as n from membership_ai_usage where user_id=$1',[id(1)]))[0].n,0);
  assert.equal((await query('select claimed from membership_campaign'))[0].claimed,50);
  await query('delete from auth.users where id=$1', [id(54)]);
  assert.equal((await query('select count(*)::int as n from apple_subscriptions'))[0].n,0);
  assert.equal((await query('select count(*)::int as n from founding_memberships'))[0].n,49);
});
