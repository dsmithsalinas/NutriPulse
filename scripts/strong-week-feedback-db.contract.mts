import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001', other = '00000000-0000-0000-0000-000000000002';
const week = '00000000-0000-0000-0000-000000000011', otherWeek = '00000000-0000-0000-0000-000000000012';
const outlook = JSON.stringify({observation:'A busy week.',foodFocus:'Familiar meals.',movementFocus:'Flexible activity.'});
const asUser = async (id: string) => db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false); set role authenticated;`);
const denied = async (sql: string, code='42501') => assert.rejects(db.exec(sql), (error:any) => error.code === code);
const insert = (user=owner, id=week, date='2026-09-17T04:00:00.123Z') => `insert into strong_week_feedback(user_id,strong_week_id,context_revision,generated_at,outlook,rating) values('${user}','${id}','${week}','${date}','${outlook}','helpful')`;
before(async () => {
  await db.exec(`create role anon; create role authenticated; create schema auth; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema public,auth to anon,authenticated;
    insert into auth.users values('${owner}'),('${other}');`);
  for (const file of ['20260917033029_strong_week.sql','20260917045151_strong_week_feedback.sql'])
    await db.exec(readFileSync(new URL('../supabase/migrations/'+file,import.meta.url),'utf8'));
  await db.exec(`insert into strong_weeks(id,user_id,week_start,context_revision) values('${week}','${owner}','2026-09-14','${week}'),('${otherWeek}','${other}','2026-09-14','${otherWeek}')`);
});
afterEach(async()=>{await db.exec('reset role')}); after(async()=>{await db.close()});
test('owner saves and edits one rating per generated outlook',async()=>{
  await asUser(owner); await db.exec(insert());
  await db.exec(insert()+` on conflict(user_id,strong_week_id,generated_at) do update set rating='not_helpful',reasons=ARRAY['too_vague','more_food_ideas']`);
  const rows=(await db.query('select * from strong_week_feedback')).rows as any[];
  assert.equal(rows.length,1); assert.equal(rows[0].rating,'not_helpful'); assert.deepEqual(rows[0].reasons,['too_vague','more_food_ideas']);
});
test('other users cannot read, edit, delete, or attach ratings to someone else’s week',async()=>{
  await asUser(other);
  for(const sql of ['select * from strong_week_feedback',"update strong_week_feedback set rating='helpful' returning id",'delete from strong_week_feedback returning id'])
    assert.equal((await db.query(sql)).rows.length,0);
  await denied(insert()); await denied(insert(other,week));
  await asUser(owner); await denied("update strong_week_feedback set user_id='"+other+"'");
  await denied("update strong_week_feedback set strong_week_id='"+otherWeek+"'");
});
test('refresh preserves the reviewed snapshot and starts separate feedback',async()=>{
  await asUser(owner);
  await db.exec(`update strong_weeks set outlook='${outlook}',generated_at=now(),context_revision=gen_random_uuid() where id='${week}'`);
  await db.exec(insert(owner,week,'2026-09-17T05:00:00.123Z'));
  assert.equal((await db.query('select * from strong_week_feedback')).rows.length,2);
  assert.deepEqual((await db.query("select outlook from strong_week_feedback order by generated_at limit 1")).rows[0].outlook,JSON.parse(outlook));
});
test('invalid ratings, unknown reasons, oversized snapshots, and anonymous access fail',async()=>{
  await asUser(owner);
  for(const sql of ["update strong_week_feedback set rating='bad'", "update strong_week_feedback set reasons=ARRAY['bad']", "update strong_week_feedback set outlook='[]'", "update strong_week_feedback set outlook=jsonb_build_object('text',repeat('x',20001))"])
    await denied(sql,'23514');
  await db.exec('reset role; set role anon');
  for(const sql of ['select * from strong_week_feedback',insert(),"update strong_week_feedback set rating='helpful'",'delete from strong_week_feedback']) await denied(sql);
});
test('account deletion removes feedback and leaves other accounts intact',async()=>{
  await asUser(other); await db.exec(insert(other,otherWeek));
  await db.exec(`reset role; delete from auth.users where id='${owner}'`);
  const rows=(await db.query('select user_id from strong_week_feedback')).rows as any[];
  assert.deepEqual(rows.map(r=>r.user_id),[other]);
});
