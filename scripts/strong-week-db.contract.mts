import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001', other = '00000000-0000-0000-0000-000000000002';
const revision = '00000000-0000-0000-0000-000000000011', newRevision = '00000000-0000-0000-0000-000000000012';
const outlook = JSON.stringify({observation:'A busy week ahead.',foodFocus:'Keep familiar meals convenient.',movementFocus:'Keep activity flexible.'});
const asUser = async (id: string) => db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false); set role authenticated;`);
const denied = async (sql: string, code='42501') => assert.rejects(db.exec(sql), (error:any) => error.code === code);
before(async () => {
  await db.exec(`create role anon; create role authenticated; create schema auth; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema public,auth to anon,authenticated;
    insert into auth.users values('${owner}'),('${other}');`);
  await db.exec(readFileSync(new URL('../supabase/migrations/20260917033029_strong_week.sql',import.meta.url),'utf8'));
});
afterEach(async()=>{await db.exec('reset role')}); after(async()=>{await db.close()});
test('owner saves context before generation and can reload it without an outlook',async()=>{
  await asUser(owner);
  await db.exec(`insert into strong_weeks(user_id,week_start,circumstances,note,ongoing,context_revision) values('${owner}','2026-09-14',ARRAY['injury'],'Knee injury',true,'${revision}')`);
  const row=(await db.query('select * from strong_weeks')).rows[0] as any;
  assert.equal(row.note,'Knee injury'); assert.equal(row.outlook,null); assert.equal(row.ongoing,true);
});
test('other users cannot read, edit, delete, or impersonate the owner',async()=>{
  await asUser(other);
  assert.equal((await db.query('select * from strong_weeks')).rows.length,0);
  assert.equal((await db.query("update strong_weeks set note='changed' returning id")).rows.length,0);
  assert.equal((await db.query('delete from strong_weeks returning id')).rows.length,0);
  await denied(`insert into strong_weeks(user_id,week_start,context_revision) values('${owner}','2026-09-21','${revision}')`);
});
test('owner can save an outlook but cannot transfer ownership',async()=>{
  await asUser(owner);
  await db.exec(`update strong_weeks set outlook='${outlook}',generated_at=now() where context_revision='${revision}'`);
  assert.equal((await db.query('select outlook from strong_weeks')).rows.length,1);
  await denied(`update strong_weeks set user_id='${other}'`);
});
test('new context invalidates old outlook and late responses cannot overwrite it',async()=>{
  await asUser(owner);
  await db.exec(`update strong_weeks set context_revision='${newRevision}',note='Travel instead',outlook=null,generated_at=null`);
  assert.equal((await db.query(`update strong_weeks set outlook='${outlook}',generated_at=now() where context_revision='${revision}' returning id`)).rows.length,0);
  const row=(await db.query('select * from strong_weeks')).rows[0] as any;
  assert.equal(row.note,'Travel instead'); assert.equal(row.outlook,null);
});
test('database rejects invalid weeks, conflicting tags, unbounded notes, and malformed outlooks',async()=>{
  await asUser(owner);
  for(const sql of ["update strong_weeks set week_start='2026-09-15'", "update strong_weeks set circumstances=ARRAY['usual','injury']", "update strong_weeks set circumstances=ARRAY['arbitrary']", "update strong_weeks set note=repeat('x',1001)", "update strong_weeks set outlook='{}',generated_at=now()", `update strong_weeks set outlook='${outlook}',generated_at=null`]) await denied(sql,'23514');
});
test('anonymous callers have no access and an owner can delete their context',async()=>{
  await db.exec('set role anon');
  for(const sql of ['select * from strong_weeks',"update strong_weeks set note=''",'delete from strong_weeks',`insert into strong_weeks(user_id,week_start,context_revision) values('${owner}','2026-09-21','${revision}')`]) await denied(sql);
  await asUser(owner); assert.equal((await db.query('delete from strong_weeks returning id')).rows.length,1);
});
