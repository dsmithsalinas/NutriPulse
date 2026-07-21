-- Body goals: optional targets for weight and body fat, and a FLOOR for lean mass
-- ("stay above"), one row per user. Deliberately no date columns anywhere — a target
-- date implies a required rate of change, which is both a pressure mechanic and a
-- claim the app refuses to make.
--
-- Create-if-absent throughout, per repo convention.

CREATE TABLE IF NOT EXISTS public.body_goals (
  user_id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  weight_kg_target    NUMERIC(5,1) CHECK (weight_kg_target    IS NULL OR (weight_kg_target    > 0 AND weight_kg_target    < 500)),
  body_fat_pct_target NUMERIC(4,1) CHECK (body_fat_pct_target IS NULL OR (body_fat_pct_target > 0 AND body_fat_pct_target < 100)),
  lean_mass_kg_floor  NUMERIC(5,1) CHECK (lean_mass_kg_floor  IS NULL OR (lean_mass_kg_floor  > 0 AND lean_mass_kg_floor  < 500)),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.body_goals ENABLE ROW LEVEL SECURITY;

DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'body_goals'
      AND policyname = 'body_goals: owner full access'
  ) THEN
    CREATE POLICY "body_goals: owner full access"
      ON public.body_goals FOR ALL
      USING     (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END
$do$;
