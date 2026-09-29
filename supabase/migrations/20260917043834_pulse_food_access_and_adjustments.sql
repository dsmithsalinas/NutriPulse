ALTER TABLE public.strong_weeks ADD COLUMN adjustments text[] NOT NULL DEFAULT '{}'
  CHECK (adjustments <@ ARRAY['simpler','more_food_ideas','less_activity']::text[] AND cardinality(adjustments) <= 3);

CREATE TABLE public.food_access_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  choices text[] NOT NULL DEFAULT '{}' CHECK (
    choices <@ ARRAY['rarely_cook','eat_out','budget_friendly','limited_kitchen','quick_meals']::text[]
    AND cardinality(choices) <= 5
  ),
  note text NOT NULL DEFAULT '' CHECK (char_length(note) <= 500),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.food_access_preferences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.food_access_preferences FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.food_access_preferences TO authenticated;
CREATE POLICY "Read own food access" ON public.food_access_preferences FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Create own food access" ON public.food_access_preferences FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Update own food access" ON public.food_access_preferences FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Delete own food access" ON public.food_access_preferences FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);
