import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001', other = '00000000-0000-0000-0000-000000000002';
const asUser = async (id: string) => db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false); set role authenticated;`);
const migration = readFileSync(new URL('../supabase/migrations/20261019220103_lighter_tracking_preferences.sql', import.meta.url), 'utf8');
before(async () => {
  await db.exec(`create role anon; create role authenticated; create schema auth; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema public,auth to anon,authenticated;
    insert into auth.users values('${owner}'),('${other}');`);
  await db.exec(migration);
});
afterEach(async () => db.exec('reset role'));
after(async () => db.close());
test('new settings default to usual tracking without optional context', async () => {
  await asUser(owner);
  await db.exec(`insert into tracking_preferences(user_id) values('${owner}')`);
  const row = (await db.query<any>('select * from tracking_preferences')).rows[0];
  assert.equal(row.enabled, false); assert.equal(row.reason, null); assert.equal(row.ends_at, null);
});
test('owner can pause, edit context, and resume without storing illness history', async () => {
  await asUser(owner);
  await db.exec(`update tracking_preferences set enabled=true,reason='vacation',started_at=now(),ends_at=now()+interval '3 days'`);
  await db.exec(`update tracking_preferences set reason='feeling_unwell'`);
  assert.equal((await db.query<any>('select reason from tracking_preferences')).rows[0].reason, 'feeling_unwell');
  await db.exec(`update tracking_preferences set enabled=false,reason=null,started_at=null,ends_at=null`);
});
test('another account cannot see, change, delete or reassign the setting', async () => {
  await asUser(other);
  assert.equal((await db.query('select * from tracking_preferences')).rows.length, 0);
  assert.equal((await db.query('update tracking_preferences set enabled=false returning user_id')).rows.length, 0);
  assert.equal((await db.query('delete from tracking_preferences returning user_id')).rows.length, 0);
  await assert.rejects(db.exec(`insert into tracking_preferences(user_id) values('${owner}') on conflict(user_id) do update set enabled=false`));
  await asUser(owner);
  await assert.rejects(db.exec(`update tracking_preferences set user_id='${other}'`));
});
test('anonymous callers have no table access', async () => {
  await db.exec('set role anon');
  await assert.rejects(db.exec('select * from tracking_preferences'), (e: any) => e.code === '42501');
});
test('invalid context, incomplete windows and forgotten context on resume are rejected', async () => {
  await asUser(owner);
  for (const query of [
    "update tracking_preferences set reason='diagnosed_condition'",
    'update tracking_preferences set enabled=true',
    "update tracking_preferences set enabled=true,started_at=now(),ends_at=now()-interval '1 day'",
    "update tracking_preferences set reason='feeling_unwell'",
  ]) await assert.rejects(db.exec(query), (e: any) => e.code === '23514');
});
test('account deletion also removes the current preference', async () => {
  await db.exec(`delete from auth.users where id='${owner}'`);
  assert.equal((await db.query('select * from tracking_preferences')).rows.length, 0);
});
