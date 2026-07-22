-- ─────────────────────────────────────────────────────────────
-- DAILY STATUS REPORT — get_daily_status()
-- One function, one JSONB blob of aggregates, consumed by
-- scripts/status-report.mjs (GitHub Actions cron, see
-- .github/workflows/status-report.yml and docs/status-report.md).
--
-- Privacy is structural: the report can only ever contain what this
-- function returns — counts, per-day totals, and the feedback users
-- deliberately submitted. No names, emails, or individual logs.
-- Accounts with an @example.com email (demo profiles, the healthcheck
-- account) are excluded from every user-derived number.
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_daily_status(p_tz TEXT DEFAULT 'America/Los_Angeles')
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  -- "Yesterday" in the report timezone. log_date columns already hold the
  -- user's local calendar date; timestamptz columns are bracketed with the
  -- report-tz day boundaries — close enough for a daily pulse.
  v_day       DATE;
  v_day_start TIMESTAMPTZ;
  v_day_end   TIMESTAMPTZ;
  v_result    JSONB;
BEGIN
  v_day       := (NOW() AT TIME ZONE p_tz)::date - 1;
  v_day_start := v_day::timestamp AT TIME ZONE p_tz;
  v_day_end   := v_day_start + INTERVAL '1 day';

  WITH real_users AS (
    SELECT id, created_at
    FROM public.profiles
    WHERE email NOT LIKE '%@example.com'
  )
  SELECT jsonb_build_object(
    'report_date', v_day,
    'tz',          p_tz,

    'users', jsonb_build_object(
      'total',         (SELECT COUNT(*) FROM real_users),
      'new_yesterday', (SELECT COUNT(*) FROM real_users
                         WHERE created_at >= v_day_start AND created_at < v_day_end),
      'new_last_7d',   (SELECT COUNT(*) FROM real_users
                         WHERE created_at >= v_day_start - INTERVAL '6 days')
    ),

    'activity', jsonb_build_object(
      'active_users_yesterday',
        (SELECT COUNT(DISTINCT f.user_id) FROM public.food_logs f
          JOIN real_users u ON u.id = f.user_id WHERE f.log_date = v_day),
      'food_logs_yesterday',
        (SELECT COUNT(*) FROM public.food_logs f
          JOIN real_users u ON u.id = f.user_id WHERE f.log_date = v_day),
      'water_logs_yesterday',
        (SELECT COUNT(*) FROM public.water_logs w
          JOIN real_users u ON u.id = w.user_id WHERE w.log_date = v_day),
      'weight_logs_yesterday',
        (SELECT COUNT(*) FROM public.weight_logs w
          JOIN real_users u ON u.id = w.user_id
          WHERE w.logged_at >= v_day_start AND w.logged_at < v_day_end),
      'workout_logs_yesterday',
        (SELECT COUNT(*) FROM public.workout_logs w
          JOIN real_users u ON u.id = w.user_id WHERE w.log_date = v_day),
      'glp1_shots_yesterday',
        (SELECT COUNT(*) FROM public.glp1_logs g
          JOIN real_users u ON u.id = g.user_id
          WHERE g.injected_at >= v_day_start AND g.injected_at < v_day_end),
      'body_measurements_yesterday',
        (SELECT COUNT(*) FROM public.body_measurement_logs b
          JOIN real_users u ON u.id = b.user_id WHERE b.log_date = v_day)
    ),

    'coach', jsonb_build_object(
      -- role = 'user' so assistant turns don't double the number
      'messages_yesterday',
        (SELECT COUNT(*) FROM public.coach_messages c
          JOIN real_users u ON u.id = c.user_id
          WHERE c.role = 'user'
            AND c.created_at >= v_day_start AND c.created_at < v_day_end),
      'users_chatting_yesterday',
        (SELECT COUNT(DISTINCT c.user_id) FROM public.coach_messages c
          JOIN real_users u ON u.id = c.user_id
          WHERE c.role = 'user'
            AND c.created_at >= v_day_start AND c.created_at < v_day_end)
    ),

    -- Buckets running hot since yesterday: an abuse / cost-spike canary.
    -- Bucket + count only; no user ids in the report.
    'rate_limit_hot',
      (SELECT COALESCE(jsonb_agg(jsonb_build_object('bucket', r.bucket, 'count', r.count)
                                 ORDER BY r.count DESC), '[]'::jsonb)
        FROM public.rate_limits r
        WHERE r.window_started_at >= v_day_start AND r.count >= 30),

    -- Everything submitted since yesterday 12:00am report-tz. Runs at ~6am,
    -- so early-morning feedback lands today AND tomorrow — a duplicate beats
    -- a gap for a signal this important during beta.
    'feedback_new',
      (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'category',    f.category,
                'message',     LEFT(f.message, 2000),
                'app_version', f.app_version,
                'created_at',  f.created_at) ORDER BY f.created_at), '[]'::jsonb)
        FROM public.feedback f
        WHERE f.created_at >= v_day_start),

    'trend_7d',
      (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'date',         d.day::date,
                'food_logs',    COALESCE(t.logs, 0),
                'active_users', COALESCE(t.users, 0)) ORDER BY d.day), '[]'::jsonb)
        FROM generate_series(v_day - 6, v_day, INTERVAL '1 day') AS d(day)
        LEFT JOIN (
          SELECT f.log_date, COUNT(*) AS logs, COUNT(DISTINCT f.user_id) AS users
          FROM public.food_logs f
          JOIN real_users u ON u.id = f.user_id
          WHERE f.log_date BETWEEN v_day - 6 AND v_day
          GROUP BY f.log_date
        ) t ON t.log_date = d.day::date)
  )
  INTO v_result;

  RETURN v_result;
END;
$$;

-- Service-role only: this reads across all users (past RLS), so neither anon
-- nor signed-in app users may ever call it.
REVOKE ALL ON FUNCTION public.get_daily_status(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_status(TEXT) TO service_role;
