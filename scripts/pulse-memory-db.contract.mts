import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
const a='00000000-0000-0000-0000-000000000001', b='00000000-0000-0000-0000-000000000002';
const memory='10000000-0000-0000-0000-000000000001', meal='20000000-0000-0000-0000-000000000001';
const asUser=async(id:string)=>db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false);set role authenticated;`);
const migration=(suffix:string)=>{const dir=new URL('../supabase/migrations/',import.meta.url);return readFileSync(new URL(readdirSync(dir).find(x=>x.endsWith(suffix))!,dir),'utf8');};
before(async()=>{
 await db.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema public,auth to anon,authenticated;insert into auth.users values('${a}'),('${b}');`);
 await db.exec(migration('_usual_meals.sql'));await db.exec(migration('_pulse_memory_and_attention.sql'));
});
afterEach(async()=>db.exec('reset role'));after(async()=>db.close());
test('approved memories stay private across read, edit, delete, forged insert, ownership transfer and upsert',async()=>{
 await asUser(a);await db.exec(`insert into pulse_memories(id,user_id,content) values('${memory}','${a}','Familiar breakfasts make travel easier.')`);
 assert.equal((await db.query('select * from pulse_memories')).rows.length,1);
 await asUser(b);
 assert.equal((await db.query(`select * from pulse_memories where user_id='${a}'`)).rows.length,0);
 assert.equal((await db.query(`update pulse_memories set content='forged' returning id`)).rows.length,0);
 assert.equal((await db.query('delete from pulse_memories returning id')).rows.length,0);
 await assert.rejects(db.exec(`insert into pulse_memories(user_id,content) values('${a}','forged')`));
 await assert.rejects(db.exec(`insert into pulse_memories(id,user_id,content) values('${memory}','${b}','takeover') on conflict(id) do update set content='takeover'`));
 await asUser(a);await assert.rejects(db.exec(`update pulse_memories set user_id='${b}'`));
 await db.exec(`update pulse_memories set content='Keep a familiar option for travel.'`);
 assert.equal((await db.query<any>('select content from pulse_memories')).rows[0].content,'Keep a familiar option for travel.');
});
test('unsigned callers cannot read or write any memory, attention or breakfast table or reserve budget',async()=>{
 await db.exec("reset role;select set_config('request.jwt.claim.sub','',false);set role anon");
 for(const table of ['pulse_memories','pulse_attention_preferences','pulse_attention_reservations','breakfast_checkin_preferences','breakfast_checkins']) {
  await assert.rejects(db.exec(`select * from ${table}`));await assert.rejects(db.exec(`delete from ${table}`));
 }
 await assert.rejects(db.exec("select reserve_pulse_attention(current_date,gen_random_uuid())"));
});
test('invalid/oversized memories are rejected, and forgetting deletes the durable record',async()=>{
 await asUser(a);
 for(const text of ['', '   ', '\t\n', 'x'.repeat(301)]) await assert.rejects(db.query('insert into pulse_memories(user_id,content) values($1,$2)',[a,text]));
 await db.exec(`delete from pulse_memories where id='${memory}'`);
 assert.equal((await db.query('select * from pulse_memories')).rows.length,0);
});
test('attention quiet and daily allowance are account-owned; one reservation across all devices and channels',async()=>{
 await asUser(a);await db.exec(`insert into pulse_attention_preferences(user_id,attention_limit) values('${a}','quiet')`);
 assert.equal((await db.query<any>('select reserve_pulse_attention(current_date,gen_random_uuid()) as ok')).rows[0].ok,false);
 await asUser(b);assert.equal((await db.query('select * from pulse_attention_preferences')).rows.length,0);
 await assert.rejects(db.exec(`insert into pulse_attention_preferences(user_id) values('${a}')`));
 await assert.rejects(db.exec(`insert into pulse_attention_reservations(user_id,local_day,token) values('${a}',current_date,gen_random_uuid())`));
 await asUser(a);await db.exec("update pulse_attention_preferences set attention_limit='one'");
 const token='30000000-0000-0000-0000-000000000001';
 const claim=async(t:string)=>(await db.query<any>('select reserve_pulse_attention(current_date,$1) as ok',[t])).rows[0].ok;
 assert.equal(await claim(token),true);assert.equal(await claim(token),true);
 const outcomes=await Promise.all([claim('30000000-0000-0000-0000-000000000002'),claim('30000000-0000-0000-0000-000000000003')]);
 assert.deepEqual(outcomes,[false,false]);
 await assert.rejects(db.exec('delete from pulse_attention_reservations'));
 await db.exec("update pulse_attention_preferences set attention_limit='quiet'");assert.equal(await claim(token),false);
 await asUser(b);assert.equal(await claim('30000000-0000-0000-0000-000000000002'),true);
 assert.equal((await db.query('select * from pulse_attention_reservations')).rows.length,1);
});
test('breakfast preference and check-in cannot reference another account’s usual meal',async()=>{
 await asUser(a);await db.exec(`insert into usual_meals(id,user_id,name,meal,items) values('${meal}','${a}','My breakfast','breakfast','[{}]')`);
 await db.exec(`insert into breakfast_checkin_preferences(user_id,usual_meal_id) values('${a}','${meal}')`);
 await db.exec(`insert into breakfast_checkins(user_id,local_day,usual_meal_id,name) values('${a}',current_date,'${meal}','My breakfast')`);
 const row=(await db.query<any>('select * from breakfast_checkins')).rows[0];
 assert.equal(row.name,'My breakfast');for(const key of ['calories','protein_g','quantity'])assert.equal(key in row,false);
 await asUser(b);
 assert.equal((await db.query('select * from breakfast_checkins')).rows.length,0);
 await assert.rejects(db.exec(`insert into breakfast_checkin_preferences(user_id,usual_meal_id) values('${b}','${meal}')`));
 await assert.rejects(db.exec(`insert into breakfast_checkins(user_id,local_day,usual_meal_id,name) values('${b}',current_date,'${meal}','forged')`));
 await asUser(a);await assert.rejects(db.exec(`update breakfast_checkins set user_id='${b}'`));
 await db.exec(`delete from usual_meals where id='${meal}'`);
 assert.equal((await db.query('select * from breakfast_checkin_preferences')).rows.length,0);
 assert.equal((await db.query<any>('select * from breakfast_checkins')).rows[0].usual_meal_id,null);
});
test('deleting an account cascades memories, preferences, check-ins and allowance without touching another user',async()=>{
 await asUser(a);await db.exec(`insert into pulse_memories(user_id,content) values('${a}','Easy breakfasts help.')`);
 await db.exec(`reset role;delete from auth.users where id='${a}'`);
 for(const table of ['pulse_memories','pulse_attention_preferences','pulse_attention_reservations','breakfast_checkin_preferences','breakfast_checkins'])assert.equal((await db.query(`select * from ${table} where user_id='${a}'`)).rows.length,0);
 assert.equal((await db.query(`select * from pulse_attention_reservations where user_id='${b}'`)).rows.length,1);
});
