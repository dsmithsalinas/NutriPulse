import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001';
const other = '00000000-0000-0000-0000-000000000002';
const write1 = '10000000-0000-0000-0000-000000000001';
const write2 = '10000000-0000-0000-0000-000000000002';
const document = { enabled: true, intervals: [], schedules: [], doses: {}, events: [] };
const asUser = async (id: string) => db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false); set role authenticated;`);
const save = async (revision: number, write: string, value: unknown = document) => db.query<any>(
  'select * from public.save_medication_tracking($1,$2::jsonb,$3::uuid)', [revision, JSON.stringify(value), write]);

before(async () => {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema public,auth to anon,authenticated;
    insert into auth.users values('${owner}'),('${other}');`);
  await db.exec(readFileSync(new URL('../supabase/migrations/20261106170529_medications_tracking.sql', import.meta.url), 'utf8'));
});
afterEach(async () => db.exec('reset role'));
after(async () => db.close());

test('create, retry, update and stale CAS preserve a single atomic document', async () => {
  await asUser(owner);
  assert.equal((await save(0, write1)).rows[0].revision, 1);
  assert.equal((await save(0, write1)).rows[0].revision, 1);
  const disabled = { ...document, enabled: false };
  assert.equal((await save(1, write2, disabled)).rows[0].revision, 2);
  assert.equal((await save(1, write1)).rows.length, 0);
  const row = (await db.query<any>('select * from medication_tracking')).rows[0];
  assert.equal(row.document.enabled, false);
  assert.equal(row.revision, 2);
});
test('other account cannot read, edit, impersonate or take over the owner document', async () => {
  await asUser(other);
  assert.equal((await db.query('select * from medication_tracking')).rows.length, 0);
  assert.equal((await db.query('update medication_tracking set revision=99 returning user_id')).rows.length, 0);
  await assert.rejects(db.exec(`insert into medication_tracking values('${owner}',1,'${write1}','${JSON.stringify(document)}')`));
  await asUser(owner);
  await assert.rejects(db.exec(`update medication_tracking set user_id='${other}'`));
});
test('anonymous access and malformed documents are rejected', async () => {
  await db.exec('set role anon');
  await assert.rejects(db.exec('select * from medication_tracking'));
  await assert.rejects(save(0, write1));
  await asUser(other);
  for (const value of [{}, { ...document, enabled: 'yes' }, { ...document, schedules: null }]) {
    await assert.rejects(save(0, write1, value));
  }
  await assert.rejects(save(-1, write1));
});
test('account deletion cascades medication routines and dose history', async () => {
  await db.exec(`reset role; delete from auth.users where id='${owner}'`);
  assert.equal((await db.query('select * from medication_tracking')).rows.length, 0);
});
