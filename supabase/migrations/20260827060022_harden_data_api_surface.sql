-- Restrict the Data API surface and make legacy owner policies explicit and efficient.

-- Trigger-only function: auth owns the trigger invocation; clients never need EXECUTE.
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated, service_role;

-- These RPCs operate entirely on caller-owned rows, so RLS can enforce ownership.
ALTER FUNCTION public.get_favorite_quick_adds() SECURITY INVOKER;
REVOKE ALL ON FUNCTION public.get_favorite_quick_adds() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_favorite_quick_adds() TO authenticated, service_role;

ALTER FUNCTION public.upsert_body_composition(DATE, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT)
  SECURITY INVOKER;
REVOKE ALL ON FUNCTION public.upsert_body_composition(DATE, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upsert_body_composition(DATE, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT)
  TO authenticated, service_role;

-- Direct access to counters is never required. A service-role-only RPC below owns writes.
REVOKE ALL ON TABLE public.rate_limits FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.check_rate_limit_for_user(
  p_user_id UUID,
  p_bucket TEXT,
  p_max INTEGER,
  p_window_seconds INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
  v_count INTEGER;
BEGIN
  IF p_user_id IS NULL
     OR p_bucket IS NULL OR length(p_bucket) NOT BETWEEN 1 AND 80
     OR p_max NOT BETWEEN 1 AND 10000
     OR p_window_seconds NOT BETWEEN 1 AND 86400 THEN
    RETURN FALSE;
  END IF;

  INSERT INTO public.rate_limits AS rl (user_id, bucket, window_started_at, count)
  VALUES (p_user_id, p_bucket, v_now, 1)
  ON CONFLICT (user_id, bucket) DO UPDATE
    SET count = CASE
          WHEN rl.window_started_at < v_now - make_interval(secs => p_window_seconds) THEN 1
          ELSE rl.count + 1
        END,
        window_started_at = CASE
          WHEN rl.window_started_at < v_now - make_interval(secs => p_window_seconds) THEN v_now
          ELSE rl.window_started_at
        END
  RETURNING rl.count INTO v_count;

  RETURN v_count <= p_max;
END;
$$;

REVOKE ALL ON FUNCTION public.check_rate_limit_for_user(UUID, TEXT, INTEGER, INTEGER)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_rate_limit_for_user(UUID, TEXT, INTEGER, INTEGER)
  TO service_role;

-- Cover the two foreign keys identified by the database advisor.
CREATE INDEX IF NOT EXISTS favorites_food_item_id_idx
  ON public.favorites (food_item_id);
CREATE INDEX IF NOT EXISTS food_favorites_food_item_id_idx
  ON public.food_favorites (food_item_id);

-- Legacy policies predated explicit roles and init-plan caching. Keep their behavior while
-- ensuring they only run for signed-in users and evaluate auth.uid() once per statement.
ALTER POLICY "Users manage own body composition" ON public.body_composition_logs
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "body_goals: owner full access" ON public.body_goals
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "body_measurement_logs: owner full access" ON public.body_measurement_logs
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "Users manage own coach messages" ON public.coach_messages
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "daily_goals: owner full access" ON public.daily_goals
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "favorites: owner full access" ON public.favorites
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "Users manage own favorites" ON public.food_favorites
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "food_logs: owner full access" ON public.food_logs
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "glp1_logs: owner full access" ON public.glp1_logs
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "water_logs: owner full access" ON public.water_logs
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "workout_logs: owner full access" ON public.workout_logs
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

ALTER POLICY "feedback: owner insert" ON public.feedback
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "feedback: owner read own" ON public.feedback
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

ALTER POLICY "food_items: read own and shared" ON public.food_items
  TO authenticated
  USING (user_id IS NULL OR (SELECT auth.uid()) = user_id);
ALTER POLICY "food_items: insert own" ON public.food_items
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "food_items: update own" ON public.food_items
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
ALTER POLICY "food_items: delete own" ON public.food_items
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);
