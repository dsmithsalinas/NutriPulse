-- ============================================================
-- NutriPulse — Initial Schema
-- Paste this in: Supabase dashboard → SQL Editor → New query → Run
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- PROFILES  (1:1 with auth.users)
-- Created automatically via trigger when a user signs up.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email          TEXT NOT NULL,
  full_name      TEXT,
  dob            DATE,
  sex            TEXT CHECK (sex IN ('male','female','other')),
  height_cm      NUMERIC(5,1),
  activity_level TEXT CHECK (activity_level IN ('sedentary','light','moderate','active','very_active')),
  dietary_prefs  TEXT[] DEFAULT '{}',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles: owner full access"
  ON public.profiles FOR ALL
  USING     (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Trigger: insert a profiles row the moment a user registers.
-- SECURITY DEFINER runs as the function owner (postgres), not the calling user,
-- so it can write to profiles even before the RLS session is established.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ─────────────────────────────────────────────────────────────
-- DAILY GOALS
-- Dated rows: a new row per goal change, not an update in place.
-- GoalRepository fetches the most recent row on-or-before the requested date.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.daily_goals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  effective_date  DATE NOT NULL,
  calories        NUMERIC(7,1) NOT NULL,
  protein_g       NUMERIC(6,1) NOT NULL,
  carbs_g         NUMERIC(6,1) NOT NULL,
  fat_g           NUMERIC(6,1) NOT NULL,
  fiber_g         NUMERIC(5,1) NOT NULL,
  water_ml_target NUMERIC(7,0) NOT NULL DEFAULT 2000,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, effective_date)
);

-- GoalRepository query: .lte("effective_date").order(desc).limit(1)
CREATE INDEX ON public.daily_goals (user_id, effective_date DESC);

ALTER TABLE public.daily_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "daily_goals: owner full access"
  ON public.daily_goals FOR ALL
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- FOOD ITEMS  (shared catalog + per-user cache)
-- user_id IS NULL  → shared catalog row (FatSecret import, readable by all)
-- user_id = <uid>  → private item (manual entry or user-specific cache)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.food_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- NULL = shared
  source        TEXT NOT NULL CHECK (source IN ('fatsecret','manual')),
  external_id   TEXT,          -- FatSecret food_id; null for manual entries
  name          TEXT NOT NULL,
  brand         TEXT,
  serving_desc  TEXT NOT NULL, -- e.g. "1 cup (240 g)"
  serving_grams NUMERIC(7,2) NOT NULL,
  calories      NUMERIC(7,1) NOT NULL,
  protein_g     NUMERIC(6,2) NOT NULL,
  carbs_g       NUMERIC(6,2) NOT NULL,
  fat_g         NUMERIC(6,2) NOT NULL,
  fiber_g       NUMERIC(6,2) NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Prevents duplicate imports of the same FatSecret item
  UNIQUE (source, external_id)
);

CREATE INDEX ON public.food_items (user_id);
CREATE INDEX ON public.food_items (name);  -- text search on food logging screen

ALTER TABLE public.food_items ENABLE ROW LEVEL SECURITY;

-- Read: own rows OR shared catalog rows
CREATE POLICY "food_items: read own and shared"
  ON public.food_items FOR SELECT
  USING (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY "food_items: insert own"
  ON public.food_items FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "food_items: update own"
  ON public.food_items FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "food_items: delete own"
  ON public.food_items FOR DELETE
  USING (user_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- FOOD LOGS
-- Denormalized snapshot pattern: macros are copied from food_items at log time.
-- Editing a food definition later won't silently rewrite history.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.food_logs (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  logged_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  log_date           DATE NOT NULL,   -- local calendar date; avoids TZ ambiguity
  meal               TEXT NOT NULL CHECK (meal IN ('breakfast','lunch','dinner','snack')),
  food_item_id       UUID NOT NULL REFERENCES public.food_items(id),
  quantity           NUMERIC(6,2) NOT NULL DEFAULT 1,  -- number of servings

  -- Snapshot copied from food_items.* × quantity at insert time
  calories_snapshot  NUMERIC(7,1) NOT NULL,
  protein_g_snapshot NUMERIC(6,2) NOT NULL,
  carbs_g_snapshot   NUMERIC(6,2) NOT NULL,
  fat_g_snapshot     NUMERIC(6,2) NOT NULL,
  fiber_g_snapshot   NUMERIC(6,2) NOT NULL DEFAULT 0,

  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Primary app query: fetch all logs for user on a date
CREATE INDEX ON public.food_logs (user_id, log_date);
CREATE INDEX ON public.food_logs (food_item_id);

ALTER TABLE public.food_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "food_logs: owner full access"
  ON public.food_logs FOR ALL
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- FAVORITES
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.favorites (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  food_item_id UUID NOT NULL REFERENCES public.food_items(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, food_item_id)
);

CREATE INDEX ON public.favorites (user_id);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "favorites: owner full access"
  ON public.favorites FOR ALL
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- WEIGHT LOGS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.weight_logs (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  logged_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  weight_kg  NUMERIC(6,2) NOT NULL,
  source     TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','healthkit')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON public.weight_logs (user_id, logged_at DESC);

ALTER TABLE public.weight_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "weight_logs: owner full access"
  ON public.weight_logs FOR ALL
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- WATER LOGS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.water_logs (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  logged_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  log_date   DATE NOT NULL,
  amount_ml  NUMERIC(7,0) NOT NULL,
  source     TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','healthkit')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON public.water_logs (user_id, log_date);

ALTER TABLE public.water_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "water_logs: owner full access"
  ON public.water_logs FOR ALL
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- GLP-1 LOGS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.glp1_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  injected_at TIMESTAMPTZ NOT NULL,
  medication  TEXT NOT NULL,  -- e.g. "Semaglutide", "Tirzepatide"
  dose_mg     NUMERIC(5,2) NOT NULL,
  site        TEXT,           -- injection site description
  next_due_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON public.glp1_logs (user_id, injected_at DESC);

ALTER TABLE public.glp1_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "glp1_logs: owner full access"
  ON public.glp1_logs FOR ALL
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
