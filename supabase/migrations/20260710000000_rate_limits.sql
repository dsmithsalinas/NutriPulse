-- ─────────────────────────────────────────────────────────────
-- RATE LIMITS
-- Per-user, per-endpoint fixed-window counters, enforced server-side from the
-- edge functions (coach-chat, parse-food). A JWT is already required there, but
-- sign-up is open, so without this one throwaway account can loop those functions
-- and run up the Anthropic / FatSecret bill. The per-request input caps bound the
-- cost of ONE call; this bounds how many calls per window.
--
-- One row per (user, bucket): bounded by users × endpoints, so no cleanup job.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.rate_limits (
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  bucket            TEXT NOT NULL,
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  count             INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, bucket)
);

-- RLS on, and deliberately NO policies: the only writer is check_rate_limit() below,
-- which runs SECURITY DEFINER. Direct PostgREST access (anon / authenticated) is denied,
-- so a user can't read or reset their own counter to dodge the limit.
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- Atomically records a hit and reports whether the caller is still within `p_max` hits per
-- `p_window_seconds`. Fixed window: the first hit after the window elapses resets the count.
-- SECURITY DEFINER so it can write past RLS; the user is taken from the JWT (auth.uid()),
-- never from a parameter, so callers can only ever bump their own bucket.
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_bucket         TEXT,
  p_max            INTEGER,
  p_window_seconds INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user  UUID := auth.uid();
  v_now   TIMESTAMPTZ := NOW();
  v_count INTEGER;
BEGIN
  -- No authenticated user → deny. The functions already require a JWT; this is defence in depth.
  IF v_user IS NULL THEN
    RETURN FALSE;
  END IF;

  INSERT INTO public.rate_limits AS rl (user_id, bucket, window_started_at, count)
  VALUES (v_user, p_bucket, v_now, 1)
  ON CONFLICT (user_id, bucket) DO UPDATE
    SET
      count = CASE
        WHEN rl.window_started_at < v_now - make_interval(secs => p_window_seconds)
          THEN 1
        ELSE rl.count + 1
      END,
      window_started_at = CASE
        WHEN rl.window_started_at < v_now - make_interval(secs => p_window_seconds)
          THEN v_now
        ELSE rl.window_started_at
      END
  RETURNING rl.count INTO v_count;

  RETURN v_count <= p_max;
END;
$$;

-- Callable only by signed-in users (and the service role); never anon.
REVOKE ALL ON FUNCTION public.check_rate_limit(TEXT, INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(TEXT, INTEGER, INTEGER) TO authenticated, service_role;
