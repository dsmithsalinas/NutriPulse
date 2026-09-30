-- "I've paused" / "I've stopped" for GLP-1 tracking (Profile → GLP-1 tracker).
--
-- While paused or stopped the app hides everything about the shot: the dose card, the shot
-- cycle, check-ins, reminders, cycle insights, and what Pulse is told. Past logs stay. It lives
-- on the account, not the device, so every device agrees and a reinstall doesn't bring the shot
-- prompts back. Additive with a default: existing rows read as 'active' and older app versions,
-- which never select these columns by name, are unaffected.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS glp1_tracking text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS glp1_tracking_changed_at timestamptz;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_glp1_tracking_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_glp1_tracking_check CHECK (glp1_tracking IN ('active', 'paused', 'stopped'));

COMMENT ON COLUMN public.profiles.glp1_tracking IS
  'GLP-1 tracking: active, paused or stopped. Paused/stopped hides shot prompts, reminders and cycle insights; history is kept.';
