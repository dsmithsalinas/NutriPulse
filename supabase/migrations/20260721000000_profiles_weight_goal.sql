-- The lose/maintain/gain direction, previously asked once at onboarding and never
-- stored — the retarget flow had to infer intent from the calorie gap. Recorded from
-- now on by onboarding and by the new Recalculate Targets flow; existing rows stay
-- NULL until the user goes through either.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS weight_goal TEXT
  CHECK (weight_goal IS NULL OR weight_goal IN ('lose','maintain','gain'));
