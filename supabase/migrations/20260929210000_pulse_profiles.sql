-- "What Pulse knows about you" and the Pulse settings (docs/daylight-redesign.md, step 8).
--
-- Preferences: allergies and intolerances (safety-relevant, always saved by the user, never
-- inferred), how they eat, and foods they love or would rather skip. Food access keeps its own
-- table (food_access_preferences).
--
-- Settings live here, not on the device, so turning Pulse off follows the account to every
-- device and coach-chat can refuse to run for it. ai_consent_at records when the user agreed to
-- Pulse's data being sent to the AI provider; NULL means not yet asked or declined.

-- Every element non-empty and at most `max_len` characters. CHECK constraints can't hold
-- subqueries, so the per-element rule lives in an immutable helper.
CREATE OR REPLACE FUNCTION public.pulse_text_items_ok(items text[], max_len integer)
RETURNS boolean
LANGUAGE sql IMMUTABLE
SET search_path = ''
AS $$
  SELECT coalesce(bool_and(char_length(btrim(item)) BETWEEN 1 AND max_len), true)
  FROM unnest(items) AS item
$$;

CREATE TABLE IF NOT EXISTS public.pulse_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  allergies text[] NOT NULL DEFAULT '{}' CHECK (
    cardinality(allergies) <= 20 AND public.pulse_text_items_ok(allergies, 60)
  ),
  allergy_note text NOT NULL DEFAULT '' CHECK (char_length(allergy_note) <= 300),
  eating_patterns text[] NOT NULL DEFAULT '{}' CHECK (
    eating_patterns <@ ARRAY['vegetarian','vegan','pescatarian','halal','kosher','dairy_free','gluten_free']::text[]
    AND cardinality(eating_patterns) <= 7
  ),
  loves text[] NOT NULL DEFAULT '{}' CHECK (
    cardinality(loves) <= 30 AND public.pulse_text_items_ok(loves, 60)
  ),
  avoids text[] NOT NULL DEFAULT '{}' CHECK (
    cardinality(avoids) <= 30 AND public.pulse_text_items_ok(avoids, 60)
  ),
  pulse_enabled boolean NOT NULL DEFAULT true,
  pulse_on_today boolean NOT NULL DEFAULT true,
  ai_consent_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pulse_profiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pulse_profiles FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pulse_profiles TO authenticated;
REVOKE ALL ON FUNCTION public.pulse_text_items_ok(text[], integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pulse_text_items_ok(text[], integer) TO authenticated, service_role;

DROP POLICY IF EXISTS "Read own pulse profile" ON public.pulse_profiles;
DROP POLICY IF EXISTS "Create own pulse profile" ON public.pulse_profiles;
DROP POLICY IF EXISTS "Update own pulse profile" ON public.pulse_profiles;
DROP POLICY IF EXISTS "Delete own pulse profile" ON public.pulse_profiles;
CREATE POLICY "Read own pulse profile" ON public.pulse_profiles FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Create own pulse profile" ON public.pulse_profiles FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Update own pulse profile" ON public.pulse_profiles FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Delete own pulse profile" ON public.pulse_profiles FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

COMMENT ON TABLE public.pulse_profiles IS
  'What Pulse knows about the user (allergies, eating patterns, loves, avoids) and Pulse settings (on/off, on Today, AI consent). Owner-only.';
