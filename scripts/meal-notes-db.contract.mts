import test, { before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001', other = '00000000-0000-0000-0000-000000000002';
const asUser = async (id: string) => db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false); set role authenticated;`);
const dir = new URL('../supabase/migrations/', import.meta.url);
const migration = readFileSync(new URL(readdirSync(dir).find(n => n.endsWith('_meal_notes.sql'))!, dir), 'utf8');
before(async () => {
  await db.exec(`create role anon; create role authenticated; create schema auth; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema public,auth to anon,authenticated;
    insert into auth.users values('${owner}'),('${other}');`);
  await db.exec(migration);
  for (const file of readdirSync(dir).filter(n => n.endsWith('_meal_note_whitespace_validation.sql') || n.endsWith('_off_script_day_notes.sql'))) {
    await db.exec(readFileSync(new URL(file, dir), 'utf8'));
  }
});
afterEach(async () => db.exec('reset role'));
after(async () => db.close());
test('owner creates and edits a qualitative note without nutrition columns', async () => {
  await asUser(owner);
  await db.exec(`insert into meal_notes(user_id,log_date,meal,body) values('${owner}','2026-10-19','lunch','Lunch out')`);
  await db.exec(`update meal_notes set body='Lunch with friends'`);
  const row = (await db.query<any>('select * from meal_notes')).rows[0];
  assert.equal(row.body,'Lunch with friends'); assert.equal('calories' in row,false); assert.equal('protein_g' in row,false);
});
test('another account cannot read, edit, delete, insert for or take over a note', async () => {
  await asUser(other);
  for (const sql of ['select * from meal_notes','update meal_notes set body=\'changed\' returning id','delete from meal_notes returning id'])
    assert.equal((await db.query(sql)).rows.length,0);
  await assert.rejects(db.exec(`insert into meal_notes(user_id,log_date,meal,body) values('${owner}','2026-10-19','lunch','Forged')`));
  await asUser(owner); await assert.rejects(db.exec(`update meal_notes set user_id='${other}'`));
});
test('anonymous access and invalid notes are rejected', async () => {
  await db.exec('set role anon'); await assert.rejects(db.exec('select * from meal_notes'));
  await asUser(owner);
  for (const body of ['', '   ', '\n\t', 'x'.repeat(1001)]) {
    await assert.rejects(db.exec(`insert into meal_notes(user_id,log_date,meal,body) values('${owner}','2026-10-19','lunch','${body}')`));
  }
  await assert.rejects(db.exec(`update meal_notes set meal='unknown'`));
});
test('owner can delete a note and account deletion cascades', async () => {
  await asUser(owner); await db.exec('delete from meal_notes');
  assert.equal((await db.query('select * from meal_notes')).rows.length,0);
  await db.exec(`insert into meal_notes(user_id,log_date,meal,body) values('${owner}','2026-10-19','snack','Tea')`);
  await db.exec(`reset role; delete from auth.users where id='${owner}'`);
  assert.equal((await db.query('select * from meal_notes')).rows.length,0);
});


test('off-script day notes keep context separate from meals and retain owner-only access', async () => {
  await asUser(other);
  await db.exec(`insert into meal_notes(user_id,log_date,meal,body,kind) values('${other}','2026-10-19','snack','Travel changed the day','day_context')`);
  let row=(await db.query<any>('select * from meal_notes')).rows[0];
  assert.equal(row.kind,'day_context');assert.equal('calories' in row,false);
  await db.exec("update meal_notes set body='Travel took longer than expected'");
  await asUser(owner);
  assert.equal((await db.query('select * from meal_notes')).rows.length,0);
  assert.equal((await db.query("update meal_notes set kind='meal' returning id")).rows.length,0);
  await asUser(other);await db.exec('delete from meal_notes');
});
test('older clients default to meal notes and unknown note kinds are rejected', async () => {
  await asUser(other);
  await db.exec(`insert into meal_notes(user_id,log_date,meal,body) values('${other}','2026-10-19','lunch','Lunch out')`);
  assert.equal((await db.query<any>('select * from meal_notes')).rows[0].kind,'meal');
  await assert.rejects(db.exec("update meal_notes set kind='automatic_memory'"));
});
