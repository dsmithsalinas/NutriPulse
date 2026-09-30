import test, { before } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

// profiles.glp1_tracking: "I've paused" / "I've stopped" for GLP-1 tracking. Additive, defaulted,
// and limited to the three states the app knows.
const db = new PGlite();
const id = '00000000-0000-0000-0000-000000000001';
const migration = readFileSync(new URL('../supabase/migrations/20260930160000_glp1_tracking_status.sql', import.meta.url), 'utf8');

before(async () => {
  // The columns the initial schema gives profiles, with a row that predates this migration.
  await db.exec(`create table public.profiles(id uuid primary key, email text not null, created_at timestamptz not null default now());
  insert into public.profiles(id, email) values('${id}', 'a@b.c');`);
  await db.exec(migration);
  await db.exec(migration); // re-runnable
});

test('existing rows read as active, with no change date', async () => {
  const { rows } = await db.query<any>(`select glp1_tracking, glp1_tracking_changed_at from public.profiles where id='${id}'`);
  assert.deepEqual(rows[0], { glp1_tracking: 'active', glp1_tracking_changed_at: null });
});

test('paused and stopped are accepted, with a change date', async () => {
  for (const status of ['paused', 'stopped', 'active']) {
    await db.exec(`update public.profiles set glp1_tracking='${status}', glp1_tracking_changed_at=now() where id='${id}'`);
    const { rows } = await db.query<any>(`select glp1_tracking from public.profiles where id='${id}'`);
    assert.equal(rows[0].glp1_tracking, status);
  }
});

test('anything else is rejected, and it can not be null', async () => {
  await assert.rejects(db.exec(`update public.profiles set glp1_tracking='on_break' where id='${id}'`), (e: any) => e.code === '23514');
  await assert.rejects(db.exec(`update public.profiles set glp1_tracking=null where id='${id}'`), (e: any) => e.code === '23502');
});
