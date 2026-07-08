-- ============================================================
-- Schema drift repair: tables and functions the app has always used but that
-- were never checked in as migrations (they were created by hand in the
-- dashboard). Without these, a fresh environment — staging, CI, `supabase db
-- reset`, a new laptop, disaster recovery — 404s on favorites, the Pulse coach,
-- and body composition.
--
-- ⚠ RECONSTRUCTED FROM CLIENT USAGE, NOT DUMPED FROM PRODUCTION.
--   Before applying anywhere that already has these objects, diff against prod
--   (`supabase db diff --linked`) — the CREATE OR REPLACE FUNCTION statements
--   below WILL overwrite the live function bodies.
--
-- Column shapes are derived from:
--   food_favorites        ← FavoriteRepository.swift
--   coach_messages        ← CoachRepository.swift, Models/CoachMessage.swift
--   body_composition_logs ← BodyCompositionRepository.swift, Models/BodyCompositionLog.swift
--   get_favorite_quick_adds  ← Models/FoodFavorite.swift (FavoriteQuickAdd)
--   upsert_body_composition  ← Models/BodyCompositionLog.swift (UpsertBodyCompParams)
--
-- The ON DELETE CASCADE on every user_id is what makes the App-Store-compliance
-- account deletion (supabase/functions/delete-account) actually delete this data.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- FOOD FAVORITES
-- Supersedes the unused `public.favorites` table from the initial schema, which
-- no code has ever referenced. Left in place here rather than dropped — confirm
-- it's empty in production, then drop it separately.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.food_favorites (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  food_item_id UUID NOT NULL REFERENCES public.food_items(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- FoodSearchViewModel.logFood relies on this to make a duplicate favorite a no-op.
  UNIQUE (user_id, food_item_id)
);

CREATE INDEX IF NOT EXISTS food_favorites_user_id_idx ON public.food_favorites (user_id);

ALTER TABLE public.food_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "food_favorites: owner full access" ON public.food_favorites;
CREATE POLICY "food_favorites: owner full access"
  ON public.food_favorites FOR ALL
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

COMMENT ON TABLE public.favorites IS
  'DEPRECATED — superseded by public.food_favorites. Unreferenced by any client code.';


-- ─────────────────────────────────────────────────────────────
-- COACH MESSAGES  (Pulse chat history)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.coach_messages (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role         TEXT NOT NULL CHECK (role IN ('user','assistant')),
  content      TEXT NOT NULL,
  message_type TEXT NOT NULL DEFAULT 'chat'
                 CHECK (message_type IN ('chat','checkin','weekly_summary')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Serves both fetchHistory (newest 30) and lastWeeklySummaryDate.
CREATE INDEX IF NOT EXISTS coach_messages_user_created_idx
  ON public.coach_messages (user_id, created_at DESC);

ALTER TABLE public.coach_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coach_messages: owner full access" ON public.coach_messages;
CREATE POLICY "coach_messages: owner full access"
  ON public.coach_messages FOR ALL
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- BODY COMPOSITION LOGS
-- One row per user per day; written through upsert_body_composition below.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.body_composition_logs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  log_date          DATE NOT NULL,
  weight_kg         NUMERIC(6,2),
  body_fat_pct      NUMERIC(5,2),   -- stored as percent (22.4), not a fraction
  bmi               NUMERIC(5,2),
  lean_body_mass_kg NUMERIC(6,2),
  source            TEXT NOT NULL DEFAULT 'manual'
                      CHECK (source IN ('manual','healthkit')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, log_date)
);

CREATE INDEX IF NOT EXISTS body_composition_logs_user_date_idx
  ON public.body_composition_logs (user_id, log_date DESC);

ALTER TABLE public.body_composition_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "body_composition_logs: owner full access" ON public.body_composition_logs;
CREATE POLICY "body_composition_logs: owner full access"
  ON public.body_composition_logs FOR ALL
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- upsert_body_composition()
-- COALESCE on update is load-bearing: the HealthKit auto-sync calls this with
-- only p_weight_kg set, and must not null out a body-fat percentage the user
-- entered by hand earlier the same day.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.upsert_body_composition(
  p_log_date          DATE,
  p_weight_kg         NUMERIC DEFAULT NULL,
  p_body_fat_pct      NUMERIC DEFAULT NULL,
  p_bmi               NUMERIC DEFAULT NULL,
  p_lean_body_mass_kg NUMERIC DEFAULT NULL,
  p_source            TEXT    DEFAULT 'manual'
)
RETURNS VOID
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
  INSERT INTO public.body_composition_logs
    (user_id, log_date, weight_kg, body_fat_pct, bmi, lean_body_mass_kg, source)
  VALUES
    (auth.uid(), p_log_date, p_weight_kg, p_body_fat_pct, p_bmi, p_lean_body_mass_kg, p_source)
  ON CONFLICT (user_id, log_date) DO UPDATE SET
    weight_kg         = COALESCE(EXCLUDED.weight_kg,         body_composition_logs.weight_kg),
    body_fat_pct      = COALESCE(EXCLUDED.body_fat_pct,      body_composition_logs.body_fat_pct),
    bmi               = COALESCE(EXCLUDED.bmi,               body_composition_logs.bmi),
    lean_body_mass_kg = COALESCE(EXCLUDED.lean_body_mass_kg, body_composition_logs.lean_body_mass_kg),
    source            = EXCLUDED.source;
$$;


-- ─────────────────────────────────────────────────────────────
-- get_favorite_quick_adds()
-- Returns each favorited food with the macros and serving count from the user's
-- most recent log of it, so a one-tap quick-add reproduces what they last ate.
-- Falls back to the food_items definition at 1 serving if never logged.
-- Every reference is table-qualified: the OUT parameter names below collide with
-- real column names, and an unqualified reference would be ambiguous.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_favorite_quick_adds()
RETURNS TABLE (
  food_item_id       UUID,
  name               TEXT,
  brand              TEXT,
  serving_desc       TEXT,
  quantity           NUMERIC,
  calories_snapshot  NUMERIC,
  protein_g_snapshot NUMERIC,
  carbs_g_snapshot   NUMERIC,
  fat_g_snapshot     NUMERIC,
  fiber_g_snapshot   NUMERIC
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    fi.id,
    fi.name,
    fi.brand,
    fi.serving_desc,
    COALESCE(recent.quantity, 1)::NUMERIC,
    COALESCE(recent.calories_snapshot,  fi.calories),
    COALESCE(recent.protein_g_snapshot, fi.protein_g),
    COALESCE(recent.carbs_g_snapshot,   fi.carbs_g),
    COALESCE(recent.fat_g_snapshot,     fi.fat_g),
    COALESCE(recent.fiber_g_snapshot,   fi.fiber_g)
  FROM public.food_favorites ff
  JOIN public.food_items fi ON fi.id = ff.food_item_id
  LEFT JOIN LATERAL (
    SELECT
      fl.quantity,
      fl.calories_snapshot,
      fl.protein_g_snapshot,
      fl.carbs_g_snapshot,
      fl.fat_g_snapshot,
      fl.fiber_g_snapshot
    FROM public.food_logs fl
    WHERE fl.food_item_id = ff.food_item_id
      AND fl.user_id      = ff.user_id
    ORDER BY fl.logged_at DESC
    LIMIT 1
  ) recent ON TRUE
  WHERE ff.user_id = auth.uid()
  ORDER BY ff.created_at DESC;
$$;
