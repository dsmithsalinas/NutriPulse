-- Goals and Personal Experiments.
--
-- Definitions are versioned and immutable in application code. Raw manual observations
-- live separately from replaceable progress snapshots, so calculation rules can evolve
-- without rewriting what the user actually recorded. Automatic metrics remain in their
-- canonical Footing/HealthKit stores and are referenced by measurement.source_metric.

BEGIN;

CREATE TABLE public.personal_goals (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status             text NOT NULL DEFAULT 'active'
                     CHECK (status IN ('draft','active','paused','completed','archived')),
  current_version_id uuid,
  created_at         timestamptz NOT NULL DEFAULT now(),
  completed_at       timestamptz,
  UNIQUE (id, user_id)
);

CREATE INDEX personal_goals_user_status_idx
  ON public.personal_goals (user_id, status, created_at DESC);

CREATE TABLE public.goal_versions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id           uuid NOT NULL,
  user_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  version_number    integer NOT NULL CHECK (version_number > 0),
  title             text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  detail            text CHECK (detail IS NULL OR char_length(detail) <= 500),
  period            text NOT NULL
                    CHECK (period IN ('daily','weekly','monthly','annual','custom','ongoing')),
  start_date        date NOT NULL,
  end_date          date,
  timezone_id       text NOT NULL,
  scheduled_weekdays smallint[] NOT NULL DEFAULT ARRAY[1,2,3,4,5,6,7]::smallint[],
  effective_from    date NOT NULL,
  effective_to      date,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (goal_id, version_number),
  UNIQUE (id, user_id),
  FOREIGN KEY (goal_id, user_id)
    REFERENCES public.personal_goals(id, user_id) ON DELETE CASCADE,
  CHECK (end_date IS NULL OR end_date >= start_date),
  CHECK (effective_to IS NULL OR effective_to >= effective_from),
  CHECK (cardinality(scheduled_weekdays) BETWEEN 1 AND 7)
);

CREATE INDEX goal_versions_goal_effective_idx
  ON public.goal_versions (goal_id, effective_from DESC);

ALTER TABLE public.personal_goals
  ADD CONSTRAINT personal_goals_current_version_fk
  FOREIGN KEY (current_version_id, user_id) REFERENCES public.goal_versions(id, user_id);

CREATE TABLE public.goal_measurements (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_version_id     uuid NOT NULL,
  user_id             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role                text NOT NULL DEFAULT 'primary'
                      CHECK (role IN ('primary','supporting','outcome','confounder')),
  name                text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  kind                text NOT NULL
                      CHECK (kind IN ('habit','accumulation','frequency','average','target','threshold','subjective')),
  aggregation         text NOT NULL
                      CHECK (aggregation IN ('latest','sum','count','average','rate')),
  comparison          text NOT NULL
                      CHECK (comparison IN ('equal','at_least','at_most','reach','increase','decrease','none')),
  target_value        numeric,
  unit                text CHECK (unit IS NULL OR char_length(unit) <= 32),
  source_type         text NOT NULL
                      CHECK (source_type IN ('manual_boolean','manual_number','manual_rating','automatic','combined')),
  source_metric       text CHECK (source_metric IS NULL OR source_metric IN (
                        'steps','workouts','workout_minutes','sleep_duration','weight',
                        'protein','water','active_energy','resting_heart_rate','hrv'
                      )),
  minimum_coverage    numeric(4,3) NOT NULL DEFAULT 0.5
                      CHECK (minimum_coverage >= 0 AND minimum_coverage <= 1),
  created_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, user_id),
  FOREIGN KEY (goal_version_id, user_id)
    REFERENCES public.goal_versions(id, user_id) ON DELETE CASCADE,
  CHECK ((source_type IN ('automatic','combined')) = (source_metric IS NOT NULL))
);

CREATE INDEX goal_measurements_version_idx ON public.goal_measurements (goal_version_id);

CREATE TABLE public.goal_checkins (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id     uuid NOT NULL,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  local_date  date NOT NULL,
  note        text CHECK (note IS NULL OR char_length(note) <= 500),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, user_id),
  FOREIGN KEY (goal_id, user_id)
    REFERENCES public.personal_goals(id, user_id) ON DELETE CASCADE
);

CREATE INDEX goal_checkins_goal_date_idx
  ON public.goal_checkins (goal_id, local_date DESC, observed_at DESC);

CREATE TABLE public.goal_observations (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  checkin_id     uuid NOT NULL,
  measurement_id uuid NOT NULL,
  user_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  value_boolean  boolean,
  value_number   numeric,
  value_text     text CHECK (value_text IS NULL OR char_length(value_text) <= 500),
  created_at     timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (checkin_id, user_id)
    REFERENCES public.goal_checkins(id, user_id) ON DELETE CASCADE,
  FOREIGN KEY (measurement_id, user_id)
    REFERENCES public.goal_measurements(id, user_id) ON DELETE CASCADE,
  CHECK (num_nonnulls(value_boolean, value_number, value_text) = 1)
);

CREATE INDEX goal_observations_measurement_idx
  ON public.goal_observations (measurement_id, created_at DESC);

CREATE TABLE public.goal_progress_snapshots (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_version_id     uuid NOT NULL,
  measurement_id      uuid NOT NULL,
  user_id             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  period_start        date NOT NULL,
  period_end          date NOT NULL,
  calculated_at       timestamptz NOT NULL DEFAULT now(),
  algorithm_version   integer NOT NULL CHECK (algorithm_version > 0),
  measured_count      integer NOT NULL DEFAULT 0 CHECK (measured_count >= 0),
  expected_count      integer NOT NULL DEFAULT 0 CHECK (expected_count >= 0),
  value               numeric,
  target_value        numeric,
  status              text NOT NULL
                      CHECK (status IN ('met','not_met','pending','missing','on_track','off_track','insufficient_data')),
  detail              jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (measurement_id, period_start, period_end, algorithm_version),
  FOREIGN KEY (goal_version_id, user_id)
    REFERENCES public.goal_versions(id, user_id) ON DELETE CASCADE,
  FOREIGN KEY (measurement_id, user_id)
    REFERENCES public.goal_measurements(id, user_id) ON DELETE CASCADE,
  CHECK (period_end >= period_start)
);

CREATE TABLE public.personal_experiments (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  intervention_goal_id  uuid NOT NULL,
  question              text NOT NULL CHECK (char_length(question) BETWEEN 1 AND 240),
  status                text NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft','baseline','running','completed','archived')),
  baseline_start        date,
  intervention_start    date NOT NULL,
  end_date              date,
  created_at            timestamptz NOT NULL DEFAULT now(),
  completed_at          timestamptz,
  UNIQUE (id, user_id),
  FOREIGN KEY (intervention_goal_id, user_id)
    REFERENCES public.personal_goals(id, user_id) ON DELETE CASCADE,
  CHECK (end_date IS NULL OR end_date >= intervention_start),
  CHECK (baseline_start IS NULL OR baseline_start <= intervention_start)
);

CREATE INDEX personal_experiments_user_status_idx
  ON public.personal_experiments (user_id, status, created_at DESC);

CREATE TABLE public.experiment_metrics (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name           text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  aggregation    text NOT NULL CHECK (aggregation IN ('latest','sum','count','average','rate')),
  unit           text CHECK (unit IS NULL OR char_length(unit) <= 32),
  source_type    text NOT NULL
                 CHECK (source_type IN ('manual_boolean','manual_number','manual_rating','automatic','combined')),
  source_metric  text CHECK (source_metric IS NULL OR source_metric IN (
                   'steps','workouts','workout_minutes','sleep_duration','weight',
                   'protein','water','active_energy','resting_heart_rate','hrv'
                 )),
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, user_id),
  CHECK ((source_type IN ('automatic','combined')) = (source_metric IS NOT NULL))
);

CREATE TABLE public.experiment_measurements (
  experiment_id  uuid NOT NULL,
  measurement_id uuid NOT NULL,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role            text NOT NULL CHECK (role IN ('primary_outcome','secondary_outcome','confounder')),
  PRIMARY KEY (experiment_id, measurement_id),
  FOREIGN KEY (experiment_id, user_id)
    REFERENCES public.personal_experiments(id, user_id) ON DELETE CASCADE,
  FOREIGN KEY (measurement_id, user_id)
    REFERENCES public.experiment_metrics(id, user_id) ON DELETE CASCADE
);

CREATE TABLE public.experiment_observations (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_id  uuid NOT NULL,
  measurement_id uuid NOT NULL,
  user_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  observed_at    timestamptz NOT NULL DEFAULT now(),
  local_date     date NOT NULL,
  value_boolean  boolean,
  value_number   numeric,
  value_text     text CHECK (value_text IS NULL OR char_length(value_text) <= 500),
  created_at     timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (experiment_id, user_id)
    REFERENCES public.personal_experiments(id, user_id) ON DELETE CASCADE,
  FOREIGN KEY (measurement_id, user_id)
    REFERENCES public.experiment_metrics(id, user_id) ON DELETE CASCADE,
  CHECK (num_nonnulls(value_boolean, value_number, value_text) = 1)
);

CREATE INDEX experiment_observations_metric_date_idx
  ON public.experiment_observations (measurement_id, local_date DESC);

CREATE TABLE public.experiment_conclusions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_id      uuid NOT NULL,
  user_id            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  algorithm_version  integer NOT NULL CHECK (algorithm_version > 0),
  generated_at       timestamptz NOT NULL DEFAULT now(),
  summary            text NOT NULL CHECK (char_length(summary) <= 4000),
  coverage           jsonb NOT NULL DEFAULT '{}'::jsonb,
  comparison         jsonb NOT NULL DEFAULT '{}'::jsonb,
  limitations        jsonb NOT NULL DEFAULT '[]'::jsonb,
  prompt_version     text,
  model              text,
  UNIQUE (experiment_id, algorithm_version),
  FOREIGN KEY (experiment_id, user_id)
    REFERENCES public.personal_experiments(id, user_id) ON DELETE CASCADE
);

-- Data API access is explicit because new Supabase projects no longer expose new tables
-- automatically. RLS still provides the row-level authorization boundary.
REVOKE ALL ON TABLE
  public.personal_goals,
  public.goal_versions,
  public.goal_measurements,
  public.goal_checkins,
  public.goal_observations,
  public.goal_progress_snapshots,
  public.personal_experiments,
  public.experiment_metrics,
  public.experiment_measurements,
  public.experiment_observations,
  public.experiment_conclusions
FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.personal_goals,
  public.goal_versions,
  public.goal_measurements,
  public.goal_checkins,
  public.goal_observations,
  public.goal_progress_snapshots,
  public.personal_experiments,
  public.experiment_metrics,
  public.experiment_measurements,
  public.experiment_observations,
  public.experiment_conclusions
TO authenticated;

ALTER TABLE public.personal_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_measurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_progress_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_experiments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.experiment_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.experiment_measurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.experiment_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.experiment_conclusions ENABLE ROW LEVEL SECURITY;

DO $policies$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'personal_goals', 'goal_versions', 'goal_measurements', 'goal_checkins',
    'goal_observations', 'goal_progress_snapshots', 'personal_experiments',
    'experiment_metrics', 'experiment_measurements', 'experiment_observations',
    'experiment_conclusions'
  ]
  LOOP
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id)',
      table_name || ': owner select', table_name
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = user_id)',
      table_name || ': owner insert', table_name
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id)',
      table_name || ': owner update', table_name
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING ((SELECT auth.uid()) = user_id)',
      table_name || ': owner delete', table_name
    );
  END LOOP;
END
$policies$;

-- Definition versions and raw observations are append-only. Corrections create a new
-- version/check-in; calculated snapshots and lifecycle rows remain updateable.
REVOKE UPDATE ON TABLE
  public.goal_versions,
  public.goal_measurements,
  public.goal_checkins,
  public.goal_observations,
  public.experiment_metrics,
  public.experiment_measurements,
  public.experiment_observations,
  public.experiment_conclusions
FROM authenticated;

DROP POLICY "goal_versions: owner update" ON public.goal_versions;
DROP POLICY "goal_measurements: owner update" ON public.goal_measurements;
DROP POLICY "goal_checkins: owner update" ON public.goal_checkins;
DROP POLICY "goal_observations: owner update" ON public.goal_observations;
DROP POLICY "experiment_metrics: owner update" ON public.experiment_metrics;
DROP POLICY "experiment_measurements: owner update" ON public.experiment_measurements;
DROP POLICY "experiment_observations: owner update" ON public.experiment_observations;
DROP POLICY "experiment_conclusions: owner update" ON public.experiment_conclusions;

COMMIT;
