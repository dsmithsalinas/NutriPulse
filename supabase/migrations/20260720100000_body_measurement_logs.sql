-- Tape measurements (waist, hips, chest, upper arm, thigh). Long format — one row per
-- site per entry — so future sites are data, not DDL. Mirrors body_composition_logs'
-- direct-write pattern (no client-generated-id sync; inserts only, ids DB-generated).
--
-- Create-if-absent throughout, per repo convention.

CREATE TABLE IF NOT EXISTS public.body_measurement_logs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  logged_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  log_date       DATE NOT NULL,   -- local calendar date; same convention as food_logs
  -- MeasurementSite raw values. CHECKed because the app's site enum is the only writer;
  -- widen this list in a follow-up migration when new sites ship.
  site           TEXT NOT NULL CHECK (site IN ('waist','hips','chest','upperArm','thigh')),
  value_cm       NUMERIC(6,2) NOT NULL CHECK (value_cm > 0 AND value_cm < 500),
  source         TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','healthkit')),
  healthkit_uuid TEXT,            -- reserved for anchored HK imports; NULL today
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Primary app queries: latest per site, and per-site history windows.
CREATE INDEX IF NOT EXISTS body_measurement_logs_user_site_date_idx
  ON public.body_measurement_logs (user_id, site, log_date DESC);

-- Backstop against duplicate HealthKit imports if/when imports carry the sample uuid.
CREATE UNIQUE INDEX IF NOT EXISTS body_measurement_logs_user_hk_uuid_idx
  ON public.body_measurement_logs (user_id, healthkit_uuid)
  WHERE healthkit_uuid IS NOT NULL;

ALTER TABLE public.body_measurement_logs ENABLE ROW LEVEL SECURITY;

DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'body_measurement_logs'
      AND policyname = 'body_measurement_logs: owner full access'
  ) THEN
    CREATE POLICY "body_measurement_logs: owner full access"
      ON public.body_measurement_logs FOR ALL
      USING     (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END
$do$;
