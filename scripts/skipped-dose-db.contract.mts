import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

// Embedded real PostgreSQL; no network, production credentials, or live user data.
const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001';
const other = '00000000-0000-0000-0000-000000000002';
const injection = '00000000-0000-0000-0000-000000000011';
const otherInjection = '00000000-0000-0000-0000-000000000012';
const skipped = '00000000-0000-0000-0000-000000000021';
const insert = (id: string, user = owner, parent = injection, due = '2026-09-08T16:00:00Z', next = '2026-09-15T16:00:00Z') =>
  `insert into public.glp1_skipped_doses(id,user_id,injection_id,scheduled_at,next_reminder_at)
   values ('${id}','${user}','${parent}','${due}','${next}')`;
const asUser = async (id: string) => {
  await db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false); set role authenticated;`);
};
const denied = async (sql: string, code = '42501') => {
  await assert.rejects(db.exec(sql), (error: any) => error.code === code);
};

before(async () => {
  await db.exec(`create role anon; create role authenticated;
    create schema auth;
    create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth, public to authenticated, anon;
    grant execute on function auth.uid() to authenticated, anon;
    insert into auth.users values ('${owner}'),('${other}');`);
  const initial = readFileSync(new URL('../supabase/migrations/20260703000000_initial_schema.sql', import.meta.url), 'utf8');
  const start = initial.indexOf('CREATE TABLE IF NOT EXISTS public.glp1_logs');
  const end = initial.indexOf('WITH CHECK (user_id = auth.uid());', start) + 'WITH CHECK (user_id = auth.uid());'.length;
  await db.exec(initial.slice(start, end));
  await db.exec(`grant select,insert,delete on public.glp1_logs to authenticated;
    insert into public.glp1_logs(id,user_id,injected_at,medication,dose_mg,next_due_at) values
    ('${injection}','${owner}','2026-09-01T16:00:00Z','Zepbound',5,'2026-09-08T16:00:00Z'),
    ('${otherInjection}','${other}','2026-09-01T16:00:00Z','Zepbound',5,'2026-09-08T16:00:00Z');`);
  await db.exec(readFileSync(new URL('../supabase/migrations/20260917030735_glp1_skipped_doses.sql', import.meta.url), 'utf8'));
});
afterEach(async () => { await db.exec('reset role'); });
after(async () => { await db.close(); });

test('owner can record and read a skip without altering the injection', async () => {
  await asUser(owner);
  await db.exec(insert(skipped));
  const result = await db.query('select * from public.glp1_skipped_doses');
  assert.equal(result.rows.length, 1);
  const shots = await db.query<{ next_due_at: Date }>('select next_due_at from public.glp1_logs');
  assert.equal(shots.rows.length, 1);
  assert.equal(new Date(shots.rows[0].next_due_at).toISOString(), '2026-09-08T16:00:00.000Z');
});
test('duplicate skip is rejected for idempotent retry handling', async () => {
  await asUser(owner);
  await denied(insert('00000000-0000-0000-0000-000000000022'), '23505');
});
test('other users cannot read, delete, impersonate, or attach to the owner’s injection', async () => {
  await asUser(other);
  assert.equal((await db.query('select * from public.glp1_skipped_doses')).rows.length, 0);
  assert.equal((await db.query(`delete from public.glp1_skipped_doses where id='${skipped}' returning id`)).rows.length, 0);
  await denied(insert('00000000-0000-0000-0000-000000000023', owner, otherInjection));
  await denied(insert('00000000-0000-0000-0000-000000000024', other, injection));
});
test('anonymous users have no table access', async () => {
  await db.exec('set role anon');
  for (const sql of ['select * from public.glp1_skipped_doses', insert('00000000-0000-0000-0000-000000000025'),
    'delete from public.glp1_skipped_doses', "update public.glp1_skipped_doses set user_id=user_id"]) await denied(sql);
});
test('skips are immutable and cannot precede the scheduled dose or invent a different cadence', async () => {
  await asUser(owner);
  await denied('update public.glp1_skipped_doses set user_id=user_id');
  await denied(insert('00000000-0000-0000-0000-000000000026', owner, injection, '2026-09-01T16:00:00Z', '2026-09-08T16:00:00Z'));
  await denied(insert('00000000-0000-0000-0000-000000000027', owner, injection, '2026-09-15T16:00:00Z', '2026-09-16T16:00:00Z'), '23514');
});
test('owner can undo a skip', async () => {
  await asUser(owner);
  assert.equal((await db.query(`delete from public.glp1_skipped_doses where id='${skipped}' returning id`)).rows.length, 1);
  assert.equal((await db.query('select * from public.glp1_skipped_doses')).rows.length, 0);
});
test('local-calendar daylight-saving weeks are accepted; deleting parent removes its skips', async () => {
  await asUser(owner);
  await db.exec(insert(skipped, owner, injection, '2026-10-27T16:00:00Z', '2026-11-03T17:00:00Z'));
  await db.exec(`delete from public.glp1_logs where id='${injection}'`);
  assert.equal((await db.query('select * from public.glp1_skipped_doses')).rows.length, 0);
});
