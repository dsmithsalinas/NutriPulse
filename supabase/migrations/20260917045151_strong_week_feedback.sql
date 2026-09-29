-- Keep feedback on each reviewed outlook, even after the weekly outlook is refreshed.
create table public.strong_week_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  strong_week_id uuid not null references public.strong_weeks(id) on delete cascade,
  context_revision uuid not null,
  generated_at timestamptz not null,
  outlook jsonb not null check (jsonb_typeof(outlook) = 'object' and octet_length(outlook::text) <= 20000),
  rating text not null check (rating in ('helpful', 'not_helpful')),
  reasons text[] not null default '{}' check (
    cardinality(reasons) <= 5 and reasons <@ array['too_vague','not_realistic','more_food_ideas','more_movement_detail','tone']::text[]),
  updated_at timestamptz not null default now(),
  unique(user_id, strong_week_id, generated_at)
);
alter table public.strong_week_feedback enable row level security;
revoke all on public.strong_week_feedback from anon, authenticated;
grant select, insert, update, delete on public.strong_week_feedback to authenticated;
create policy "Read own outlook feedback" on public.strong_week_feedback for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Create own outlook feedback" on public.strong_week_feedback for insert to authenticated
  with check ((select auth.uid()) = user_id and exists (
    select 1 from public.strong_weeks w where w.id = strong_week_id and w.user_id = (select auth.uid())
  ));
create policy "Edit own outlook feedback" on public.strong_week_feedback for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id and exists (
    select 1 from public.strong_weeks w where w.id = strong_week_id and w.user_id = (select auth.uid())
  ));
create policy "Delete own outlook feedback" on public.strong_week_feedback for delete to authenticated
  using ((select auth.uid()) = user_id);
create index strong_week_feedback_week_idx on public.strong_week_feedback(strong_week_id);
