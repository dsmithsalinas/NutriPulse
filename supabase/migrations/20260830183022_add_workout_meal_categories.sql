BEGIN;

-- Preserve all existing values while widening the allowed meal categories.
-- The client stores these stable slugs and renders user-facing labels separately.
ALTER TABLE public.food_logs
  DROP CONSTRAINT IF EXISTS food_logs_meal_check;

ALTER TABLE public.food_logs
  ADD CONSTRAINT food_logs_meal_check
  CHECK (meal IN (
    'breakfast',
    'lunch',
    'dinner',
    'snack',
    'pre_workout',
    'post_workout'
  ));

COMMIT;
