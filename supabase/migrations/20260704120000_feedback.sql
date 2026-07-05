-- ─────────────────────────────────────────────────────────────
-- FEEDBACK — in-app "Send Feedback" (Phase 1C)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category    TEXT NOT NULL DEFAULT 'general' CHECK (category IN ('bug', 'idea', 'general')),
  message     TEXT NOT NULL,
  app_version TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON public.feedback (user_id);

ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- Feedback is a one-way report to the team, not a mutable user record —
-- users can submit and read their own, but never update or delete it.
CREATE POLICY "feedback: owner insert"
  ON public.feedback FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "feedback: owner read own"
  ON public.feedback FOR SELECT
  USING (user_id = auth.uid());
