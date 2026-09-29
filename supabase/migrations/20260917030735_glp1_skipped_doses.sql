-- Skips are scheduled-dose decisions, never synthetic injections.
CREATE TABLE public.glp1_skipped_doses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  injection_id uuid NOT NULL REFERENCES public.glp1_logs(id) ON DELETE CASCADE,
  scheduled_at timestamptz NOT NULL,
  next_reminder_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (injection_id, scheduled_at),
  -- Allow local-calendar weeks across daylight-saving transitions.
  CHECK (next_reminder_at - scheduled_at BETWEEN interval '6 days 22 hours' AND interval '7 days 2 hours')
);
ALTER TABLE public.glp1_skipped_doses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.glp1_skipped_doses FROM anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.glp1_skipped_doses TO authenticated;
CREATE POLICY "Read own skipped doses" ON public.glp1_skipped_doses
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Skip own scheduled dose" ON public.glp1_skipped_doses
  FOR INSERT TO authenticated WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND EXISTS (SELECT 1 FROM public.glp1_logs AS injection
      WHERE injection.id = injection_id AND injection.user_id = (SELECT auth.uid())
        AND injection.next_due_at IS NOT NULL AND scheduled_at >= injection.next_due_at)
  );
CREATE POLICY "Undo own skipped dose" ON public.glp1_skipped_doses
  FOR DELETE TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE INDEX glp1_skipped_doses_user_date_idx ON public.glp1_skipped_doses(user_id, scheduled_at DESC);
