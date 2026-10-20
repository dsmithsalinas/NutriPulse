create table public.usual_meals (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null check (length(btrim(name)) between 1 and 80 and name !~ '^[[:space:]]*$'),
    meal text not null check (meal in ('breakfast','lunch','dinner','snack')),
    items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) between 1 and 40),
    created_at timestamptz not null default now()
);
create index usual_meals_user_idx on public.usual_meals(user_id);
alter table public.usual_meals enable row level security;
revoke all on public.usual_meals from public, anon;
grant select, insert, update, delete on public.usual_meals to authenticated;
create policy usual_meals_select on public.usual_meals for select to authenticated using ((select auth.uid()) = user_id);
create policy usual_meals_insert on public.usual_meals for insert to authenticated with check ((select auth.uid()) = user_id);
create policy usual_meals_update on public.usual_meals for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy usual_meals_delete on public.usual_meals for delete to authenticated using ((select auth.uid()) = user_id);
