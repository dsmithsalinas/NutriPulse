import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001', other = '00000000-0000-0000-0000-000000000002';
const asUser = async (id: string) => db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false); set role authenticated;`);
const dir = new URL('../supabase/migrations/', import.meta.url);
const migration = readFileSync(new URL(readdirSync(dir).find(n => n.endsWith('_usual_meals.sql'))!, dir), 'utf8');
before(async () => {
  await db.exec(`create role anon; create role authenticated; create schema auth; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema public,auth to anon,authenticated;
    insert into auth.users values('${owner}'),('${other}');`);
  await db.exec(migration);

});
afterEach(async () => db.exec('reset role'));
after(async () => db.close());
test('owner saves, renames and deletes a named meal; other accounts cannot read or take it', async () => {
  await asUser(owner);
  await db.exec(`insert into usual_meals(id,user_id,name,meal,items) values('00000000-0000-0000-0000-000000000010','${owner}','My breakfast','breakfast','[{"name":"Yogurt"}]')`);
  await db.exec("update usual_meals set name='Hotel breakfast'");
  await asUser(other);
  assert.equal((await db.query('select * from usual_meals')).rows.length,0);
  assert.equal((await db.query("update usual_meals set name='forged' returning id")).rows.length,0);
  assert.equal((await db.query('delete from usual_meals returning id')).rows.length,0);
  await assert.rejects(db.exec(`insert into usual_meals(id,user_id,name,meal,items) values(gen_random_uuid(),'${owner}','forged','breakfast','[{}]')`));
  await asUser(owner);await assert.rejects(db.exec(`update usual_meals set user_id='${other}'`));
  await db.exec('delete from usual_meals');
  assert.equal((await db.query('select * from usual_meals')).rows.length,0);
});
test('anonymous access, empty names and empty meal combinations are rejected', async () => {
  await db.exec('set role anon');await assert.rejects(db.exec('select * from usual_meals'));
  await asUser(owner);
  for (const [name,items] of [['','[{}]'],['  ','[{}]'],['Breakfast','[]']]) {
    await assert.rejects(db.exec(`insert into usual_meals(id,user_id,name,meal,items) values(gen_random_uuid(),'${owner}','${name}','breakfast','${items}')`));
  }
});
test('account deletion removes saved usual meals', async () => {
  await asUser(owner);
  await db.exec(`insert into usual_meals(id,user_id,name,meal,items) values(gen_random_uuid(),'${owner}','Breakfast','breakfast','[{}]')`);
  await db.exec(`reset role;delete from auth.users where id='${owner}'`);
  assert.equal((await db.query('select * from usual_meals')).rows.length,0);
});
