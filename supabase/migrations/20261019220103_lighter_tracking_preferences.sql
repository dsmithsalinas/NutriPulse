-- One current setting per account. Independent of Pulse consent and medication tracking.
CREATE TABLE public.tracking_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  enabled boolean NOT NULL DEFAULT false,
  reason text CHECK (reason IN ('vacation', 'feeling_unwell', 'busy_stretch')),
  started_at timestamptz,
  ends_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tracking_preferences_valid_window CHECK (
    (enabled AND started_at IS NOT NULL AND (ends_at IS NULL OR ends_at > started_at))
    OR (NOT enabled AND reason IS NULL AND started_at IS NULL AND ends_at IS NULL)
  )
);
ALTER TABLE public.tracking_preferences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.tracking_preferences FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tracking_preferences TO authenticated;
CREATE POLICY "tracking_preferences_select_own" ON public.tracking_preferences
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "tracking_preferences_insert_own" ON public.tracking_preferences
  FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "tracking_preferences_update_own" ON public.tracking_preferences
  FOR UPDATE TO authenticated USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "tracking_preferences_delete_own" ON public.tracking_preferences
  FOR DELETE TO authenticated USING ((SELECT auth.uid()) = user_id);
