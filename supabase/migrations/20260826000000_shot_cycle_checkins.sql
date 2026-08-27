-- Optional daily GLP-1 experience check-ins. These describe the user's experience;
-- they are not dosing instructions and are intentionally separate from glp1_logs.
CREATE TABLE public.shot_cycle_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  checkin_date date NOT NULL,
  cycle_day integer NOT NULL CHECK (cycle_day BETWEEN 0 AND 30),
  appetite smallint NOT NULL CHECK (appetite BETWEEN 1 AND 5),
  fullness smallint NOT NULL CHECK (fullness BETWEEN 1 AND 5),
  nausea smallint NOT NULL CHECK (nausea BETWEEN 1 AND 5),
  energy smallint NOT NULL CHECK (energy BETWEEN 1 AND 5),
  digestion smallint NOT NULL CHECK (digestion BETWEEN 1 AND 5),
  note text CHECK (char_length(note) <= 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, checkin_date)
);

ALTER TABLE public.shot_cycle_checkins ENABLE ROW LEVEL SECURITY;

-- New public-schema tables are no longer guaranteed to be exposed to Data API roles.
-- The iOS app needs CRUD as an authenticated user; anonymous clients need nothing.
REVOKE ALL ON TABLE public.shot_cycle_checkins FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.shot_cycle_checkins TO authenticated;

CREATE POLICY "Users read own shot cycle check-ins"
  ON public.shot_cycle_checkins FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users insert own shot cycle check-ins"
  ON public.shot_cycle_checkins FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users update own shot cycle check-ins"
  ON public.shot_cycle_checkins FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users delete own shot cycle check-ins"
  ON public.shot_cycle_checkins FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE INDEX shot_cycle_checkins_user_date_idx
  ON public.shot_cycle_checkins (user_id, checkin_date DESC);
