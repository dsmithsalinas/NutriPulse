import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

// The coach_messages payload column: additive, object-only, size-bounded.
async function database() {
  const db = new PGlite();
  await db.exec(`CREATE TABLE public.coach_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL, role TEXT NOT NULL,
    content TEXT NOT NULL, message_type TEXT NOT NULL DEFAULT 'chat', created_at TIMESTAMPTZ NOT NULL DEFAULT NOW());`);
  await db.exec(`INSERT INTO public.coach_messages (user_id, role, content) VALUES (gen_random_uuid(), 'assistant', 'Before the column');`);
  const migration = readFileSync(new URL('../supabase/migrations/20260929200000_coach_message_payload.sql', import.meta.url), 'utf8');
  await db.exec(migration);
  await db.exec(migration); // re-runnable
  return db;
}
const insert = (db: PGlite, payload: string | null) => db.query(
  `INSERT INTO public.coach_messages (user_id, role, content, payload) VALUES (gen_random_uuid(), 'assistant', 'Hi', $1::jsonb)`, [payload]);

test('existing rows keep a null payload and new rows can store a card payload', async () => {
  const db = await database();
  const before = await db.query(`SELECT payload FROM public.coach_messages WHERE content = 'Before the column'`);
  assert.equal((before.rows[0] as any).payload, null);
  await insert(db, JSON.stringify({ foods: [{ name: 'Turkey chili', why: '31g' }], followUps: ['Make it lighter'] }));
  await insert(db, null);
  const count = await db.query(`SELECT count(*)::int AS n FROM public.coach_messages`);
  assert.equal((count.rows[0] as any).n, 3);
});

test('non-object and oversized payloads are rejected', async () => {
  const db = await database();
  await assert.rejects(insert(db, JSON.stringify(['not', 'an', 'object'])));
  await assert.rejects(insert(db, JSON.stringify('text')));
  await assert.rejects(insert(db, JSON.stringify({ reply: 'x'.repeat(9000) })));
});
