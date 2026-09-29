-- Weekly context is saved before generation, so a failed AI request never loses a
-- user's injury/travel information or leaves an old outlook attached to new context.
CREATE TABLE public.strong_weeks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  week_start date NOT NULL CHECK (extract(isodow from week_start) = 1),
  circumstances text[] NOT NULL DEFAULT '{}' CHECK (
    circumstances <@ ARRAY['travel','busy','easy','injury','usual']::text[]
    AND cardinality(circumstances) <= 5
    AND (NOT ('usual' = ANY(circumstances)) OR cardinality(circumstances) = 1)
  ),
  note text NOT NULL DEFAULT '' CHECK (char_length(note) <= 1000),
  activity_restrictions text NOT NULL DEFAULT '' CHECK (char_length(activity_restrictions) <= 500),
  ongoing boolean NOT NULL DEFAULT false,
  context_revision uuid NOT NULL,
  outlook jsonb,
  generated_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_start),
  CHECK ((outlook IS NULL AND generated_at IS NULL) OR
    (outlook IS NOT NULL AND generated_at IS NOT NULL AND jsonb_typeof(outlook) = 'object'
      AND outlook ?& ARRAY['observation','foodFocus','movementFocus']
      AND jsonb_typeof(outlook->'observation') = 'string'
      AND jsonb_typeof(outlook->'foodFocus') = 'string'
      AND jsonb_typeof(outlook->'movementFocus') = 'string'
      AND char_length(outlook->>'observation') BETWEEN 1 AND 900
      AND char_length(outlook->>'foodFocus') BETWEEN 1 AND 900
      AND char_length(outlook->>'movementFocus') BETWEEN 1 AND 900))
);
ALTER TABLE public.strong_weeks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.strong_weeks FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.strong_weeks TO authenticated;
CREATE POLICY "Read own weeks" ON public.strong_weeks FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Create own week" ON public.strong_weeks FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Update own week" ON public.strong_weeks FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Delete own week" ON public.strong_weeks FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);
