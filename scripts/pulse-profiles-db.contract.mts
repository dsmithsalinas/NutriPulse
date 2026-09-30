import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

// pulse_profiles: what Pulse knows about the user plus the Pulse settings. Owner-only.
const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001', other = '00000000-0000-0000-0000-000000000002';
const asUser = async (id: string) => db.exec(`reset role;select set_config('request.jwt.claim.sub','${id}',false);set role authenticated;`);
const asAnon = async () => db.exec(`reset role;select set_config('request.jwt.claim.sub','',false);set role anon;`);
const denied = async (sql: string, code = '42501') => assert.rejects(db.exec(sql), (e: any) => e.code === code);
const migration = readFileSync(new URL('../supabase/migrations/20260929210000_pulse_profiles.sql', import.meta.url), 'utf8');

before(async () => {
  await db.exec(`create role anon;create role authenticated;create role service_role;create schema auth;create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  grant usage on schema public,auth to anon,authenticated;insert into auth.users values('${owner}'),('${other}');`);
  await db.exec(migration);
  await db.exec(migration); // re-runnable
});
afterEach(async () => db.exec('reset role'));
after(async () => db.close());

test('a new profile defaults to Pulse on, on Today, no consent yet, and nothing known', async () => {
  await asUser(owner);
  await db.exec(`insert into pulse_profiles(user_id) values('${owner}')`);
  const row = (await db.query<any>('select * from pulse_profiles')).rows[0];
  assert.equal(row.pulse_enabled, true);
  assert.equal(row.pulse_on_today, true);
  assert.equal(row.ai_consent_at, null);
  assert.deepEqual(row.allergies, []);
});

test('owner saves allergies, patterns, loves and avoids, and turns Pulse off', async () => {
  await asUser(owner);
  await db.exec(`update pulse_profiles set allergies=ARRAY['Peanuts','Shellfish'], allergy_note='Mild, but avoid',
    eating_patterns=ARRAY['pescatarian'], loves=ARRAY['Greek yogurt'], avoids=ARRAY['Salmon'], pulse_enabled=false, ai_consent_at=now()`);
  const row = (await db.query<any>('select * from pulse_profiles')).rows[0];
  assert.deepEqual(row.allergies, ['Peanuts', 'Shellfish']);
  assert.equal(row.pulse_enabled, false);
});

test('other users and anonymous callers cannot read or change it', async () => {
  await asUser(other);
  assert.equal((await db.query('select * from pulse_profiles')).rows.length, 0);
  assert.equal((await db.query("update pulse_profiles set pulse_enabled=true returning user_id")).rows.length, 0);
  assert.equal((await db.query('delete from pulse_profiles returning user_id')).rows.length, 0);
  await denied(`insert into pulse_profiles(user_id) values('${owner}') on conflict(user_id) do update set pulse_enabled=true`);
  await asUser(owner);
  await denied(`update pulse_profiles set user_id='${other}'`);
  await asAnon();
  await denied('select * from pulse_profiles');
});

test('unknown patterns, blank or long items, too many items, and long notes are rejected', async () => {
  await asUser(owner);
  for (const sql of [
    "update pulse_profiles set eating_patterns=ARRAY['carnivore']",
    "update pulse_profiles set allergies=ARRAY['  ']",
    `update pulse_profiles set avoids=ARRAY['${'x'.repeat(61)}']`,
    `update pulse_profiles set loves=array_fill('Eggs'::text, ARRAY[31])`,
    "update pulse_profiles set allergy_note=repeat('a',301)",
  ]) await denied(sql, '23514');
});
