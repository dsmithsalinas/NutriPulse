-- Explicit authenticated-owner rules keep each operation auditable.
drop policy if exists "profiles owner full access" on public.profiles;
drop policy if exists "profiles: owner full access" on public.profiles;
drop policy if exists "weight_logs owner full access" on public.weight_logs;
drop policy if exists "weight_logs: owner full access" on public.weight_logs;

create policy "profiles owner select" on public.profiles
for select to authenticated using ((select auth.uid()) = id);
create policy "profiles owner insert" on public.profiles
for insert to authenticated with check ((select auth.uid()) = id);
create policy "profiles owner update" on public.profiles
for update to authenticated using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "weight_logs owner select" on public.weight_logs
for select to authenticated using ((select auth.uid()) = user_id);
create policy "weight_logs owner insert" on public.weight_logs
for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "weight_logs owner update" on public.weight_logs
for update to authenticated using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "weight_logs owner delete" on public.weight_logs
for delete to authenticated using ((select auth.uid()) = user_id);

revoke all privileges on table public.profiles from anon;
revoke all privileges on table public.weight_logs from anon;
revoke all privileges on table public.profiles from authenticated;
revoke all privileges on table public.weight_logs from authenticated;
grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.weight_logs to authenticated;
grant all privileges on table public.profiles to service_role;
grant all privileges on table public.weight_logs to service_role;
