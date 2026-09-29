import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db=new PGlite();
const owner='00000000-0000-0000-0000-000000000001', other='00000000-0000-0000-0000-000000000002';
const asUser=async(id:string)=>db.exec(`reset role;select set_config('request.jwt.claim.sub','${id}',false);set role authenticated;`);
const denied=async(sql:string,code='42501')=>assert.rejects(db.exec(sql),(e:any)=>e.code===code);
before(async()=>{
 await db.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema public,auth to anon,authenticated;insert into auth.users values('${owner}'),('${other}');`);
 for(const name of ['20260917033029_strong_week.sql','20260917043834_pulse_food_access_and_adjustments.sql']) await db.exec(readFileSync(new URL('../supabase/migrations/'+name,import.meta.url),'utf8'));
});
afterEach(async()=>db.exec('reset role'));after(async()=>db.close());
test('owner can save, update, and clear persistent food preferences',async()=>{
 await asUser(owner);await db.exec(`insert into food_access_preferences(user_id,choices,note) values('${owner}',ARRAY['rarely_cook','budget_friendly'],'Microwave only')`);
 assert.equal((await db.query<any>('select * from food_access_preferences')).rows[0].note,'Microwave only');
 await db.exec("update food_access_preferences set choices='{}',note=''");assert.deepEqual((await db.query<any>('select choices from food_access_preferences')).rows[0].choices,[]);
});
test('other users cannot read, overwrite, delete, impersonate, or transfer ownership',async()=>{
 await asUser(other);assert.equal((await db.query('select * from food_access_preferences')).rows.length,0);
 assert.equal((await db.query("update food_access_preferences set note='bad' returning user_id")).rows.length,0);
 assert.equal((await db.query('delete from food_access_preferences returning user_id')).rows.length,0);
 await denied(`insert into food_access_preferences(user_id) values('${owner}') on conflict(user_id) do update set note='bad'`);
 await asUser(owner);await denied(`update food_access_preferences set user_id='${other}'`);
});
test('database rejects unknown choices, excessive notes, and duplicate owner rows',async()=>{
 await asUser(owner);await denied("update food_access_preferences set choices=ARRAY['unknown']",'23514');
 await denied("update food_access_preferences set note=repeat('a',501)",'23514');
 await denied(`insert into food_access_preferences(user_id) values('${owner}')`,'23505');
});
test('weekly adjustments default empty and reject unsupported values; stale revisions cannot erase constraints',async()=>{
 await asUser(owner);await db.exec(`insert into strong_weeks(user_id,week_start,circumstances,activity_restrictions,context_revision) values('${owner}','2026-09-14',ARRAY['injury'],'No weight bearing','00000000-0000-0000-0000-000000000011')`);
 assert.deepEqual((await db.query<any>('select adjustments from strong_weeks')).rows[0].adjustments,[]);
 await denied("update strong_weeks set adjustments=ARRAY['ignore_limits']",'23514');
 await db.exec("update strong_weeks set adjustments=ARRAY['simpler','less_activity'],context_revision='00000000-0000-0000-0000-000000000012'");
 assert.equal((await db.query("update strong_weeks set activity_restrictions='' where context_revision='00000000-0000-0000-0000-000000000011' returning id")).rows.length,0);
 assert.equal((await db.query<any>('select activity_restrictions from strong_weeks')).rows[0].activity_restrictions,'No weight bearing');
});
test('anonymous roles have no preferences access; owner account deletion cascades',async()=>{
 await db.exec('set role anon');for(const sql of ['select * from food_access_preferences',"update food_access_preferences set note=''",'delete from food_access_preferences'])await denied(sql);
 await db.exec(`reset role;delete from auth.users where id='${owner}'`);assert.equal((await db.query('select * from food_access_preferences')).rows.length,0);
});
