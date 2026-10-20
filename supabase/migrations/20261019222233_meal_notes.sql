-- Meal notes deliberately have no nutrition fields and never enter nutrition aggregates.
create table public.meal_notes (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    log_date date not null,
    meal text not null check (meal in ('breakfast', 'lunch', 'dinner', 'snack')),
    body text not null check (length(btrim(body)) between 1 and 1000),
    created_at timestamptz not null default now()
);
create index meal_notes_user_date_idx on public.meal_notes(user_id, log_date);
alter table public.meal_notes enable row level security;
revoke all on public.meal_notes from public, anon;
grant select, insert, update, delete on public.meal_notes to authenticated;
create policy meal_notes_select on public.meal_notes for select to authenticated using ((select auth.uid()) = user_id);
create policy meal_notes_insert on public.meal_notes for insert to authenticated with check ((select auth.uid()) = user_id);
create policy meal_notes_update on public.meal_notes for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy meal_notes_delete on public.meal_notes for delete to authenticated using ((select auth.uid()) = user_id);
