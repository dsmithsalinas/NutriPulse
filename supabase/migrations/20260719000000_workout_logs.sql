-- Workout / activity logs. Manual entries and HealthKit imports share one table,
-- distinguished by `source`, mirroring food_logs' owner-RLS + client-generated-id
-- sync pattern (SyncEngine upserts by id).
--
-- Create-if-absent throughout, per repo convention: re-running against a database
-- that already has these objects is a no-op.

CREATE TABLE IF NOT EXISTS public.workout_logs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  logged_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  log_date         DATE NOT NULL,   -- local calendar date; same convention as food_logs
  -- Manual logs: 'walk' | 'strength' | 'cycling' | 'running' | 'other'.
  -- HealthKit imports: the HKWorkoutActivityType slug — open vocabulary, so no CHECK.
  activity_type    TEXT NOT NULL,
  duration_minutes NUMERIC(6,1) NOT NULL,
  active_calories  NUMERIC(7,1),
  distance_meters  NUMERIC(9,1),
  source           TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','healthkit')),
  healthkit_uuid   TEXT,            -- HKWorkout.uuid for imports; NULL for manual
  started_at       TIMESTAMPTZ NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Primary app query: all workouts for a user on a date
CREATE INDEX IF NOT EXISTS workout_logs_user_date_idx
  ON public.workout_logs (user_id, log_date);

-- Makes the HealthKit import idempotent server-side: re-pushing the same HKWorkout
-- from any device cannot create a duplicate row.
CREATE UNIQUE INDEX IF NOT EXISTS workout_logs_user_hk_uuid_idx
  ON public.workout_logs (user_id, healthkit_uuid)
  WHERE healthkit_uuid IS NOT NULL;

ALTER TABLE public.workout_logs ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY has no IF NOT EXISTS, so guard it by hand.
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'workout_logs'
      AND policyname = 'workout_logs: owner full access'
  ) THEN
    CREATE POLICY "workout_logs: owner full access"
      ON public.workout_logs FOR ALL
      USING     (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END
$do$;
