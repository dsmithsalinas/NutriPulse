-- ============================================================
-- food_items: make the FatSecret dedupe key per-user, not global.
--
-- THE BUG
-- `UNIQUE (source, external_id)` was table-wide, but the client upserts
-- food_items rows stamped with its own user_id and RLS restricts UPDATE to
-- `user_id = auth.uid()`. So the second user to log a given FatSecret food took
-- the ON CONFLICT DO UPDATE path against the *first* user's row, which RLS
-- rejected outright:
--
--   42501: new row violates row-level security policy for table "food_items"
--
-- The food never logged — permanently, for every food any other user had
-- already logged. Invisible in single-user testing; guaranteed on TestFlight.
--
-- THE FIX
-- Scope uniqueness to the owner. Each user keeps their own catalog row for a
-- given FatSecret item, so the upsert always resolves against a row they own.
--
-- Notes on NULL semantics (both intentional, both rely on default NULLS DISTINCT):
--   * user_id IS NULL marks a shared catalog row. Those never collide with a
--     user's own row, so a user always inserts their own copy — which is what
--     the "food_items: insert own" / "update own" policies expect.
--   * external_id IS NULL for manual entries. Those never collide with each
--     other, so two manual foods with the same name stay separate rows, matching
--     the plain INSERT the manual-entry path already uses.
-- ============================================================

-- Find the old constraint by its *columns*, not by a guessed name. Postgres would
-- have auto-named it food_items_source_external_id_key, but if it was ever created
-- by hand under another name, a `DROP CONSTRAINT IF EXISTS <guess>` would silently
-- no-op — leaving the global key (and the bug) in place while reporting success.
DO $$
DECLARE
  old_constraint TEXT;
BEGIN
  SELECT con.conname INTO old_constraint
  FROM pg_constraint con
  WHERE con.conrelid = 'public.food_items'::regclass
    AND con.contype  = 'u'
    -- attname is `name`, not `text`. Postgres has no name[] = text[] operator,
    -- so both sides must be cast explicitly.
    AND (
      SELECT array_agg(att.attname::TEXT ORDER BY att.attname::TEXT)
      FROM unnest(con.conkey) AS k(attnum)
      JOIN pg_attribute att
        ON att.attrelid = con.conrelid AND att.attnum = k.attnum
    ) = ARRAY['external_id', 'source']::TEXT[];

  IF old_constraint IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.food_items DROP CONSTRAINT %I', old_constraint);
  END IF;
END $$;

ALTER TABLE public.food_items
  DROP CONSTRAINT IF EXISTS food_items_user_id_source_external_id_key;

ALTER TABLE public.food_items
  ADD CONSTRAINT food_items_user_id_source_external_id_key
  UNIQUE (user_id, source, external_id);
