-- Separate opt-in: agreeing to Pulse never opts an account into food parsing.
-- Existing owner-only SELECT/INSERT/UPDATE policies and auth-user cascade apply.
ALTER TABLE public.pulse_profiles ADD COLUMN IF NOT EXISTS food_ai_consent_at timestamptz;
COMMENT ON COLUMN public.pulse_profiles.food_ai_consent_at IS
  'Explicit permission to send typed/spoken food descriptions to Anthropic for parsing; NULL means no permission. Independent of Pulse consent.';
