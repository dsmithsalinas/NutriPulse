-- Preserve existing rows and older clients; day context shares the protected note outbox.
-- Nutrition aggregates do not read this table, regardless of kind.
alter table public.meal_notes
    add column kind text not null default 'meal'
    check (kind in ('meal', 'day_context'));
