-- Approved practical memories. The model cannot write to this table.
create table public.pulse_memories (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    content text not null check (length(btrim(content)) between 1 and 300 and content !~ '^[[:space:]]*$'),
    approved_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create unique index pulse_memories_content_idx on public.pulse_memories(user_id, lower(btrim(content)));
alter table public.pulse_memories enable row level security;
revoke all on public.pulse_memories from public, anon;
grant select, insert, update, delete on public.pulse_memories to authenticated;
create policy pulse_memories_select on public.pulse_memories for select to authenticated using ((select auth.uid()) = user_id);
create policy pulse_memories_insert on public.pulse_memories for insert to authenticated with check ((select auth.uid()) = user_id);
create policy pulse_memories_update on public.pulse_memories for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy pulse_memories_delete on public.pulse_memories for delete to authenticated using ((select auth.uid()) = user_id);

create table public.pulse_attention_preferences (
    user_id uuid primary key references auth.users(id) on delete cascade,
    attention_limit text not null default 'one' check (attention_limit in ('one','quiet'))
);
alter table public.pulse_attention_preferences enable row level security;
revoke all on public.pulse_attention_preferences from public, anon;
grant select, insert, update, delete on public.pulse_attention_preferences to authenticated;
create policy pulse_attention_owner on public.pulse_attention_preferences for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- One reservation for ALL proactive Pulse notifications, including Monday's outlook.
-- Reservations are conservative: cancel/dismiss does not replenish the day's allowance.
create table public.pulse_attention_reservations (
    user_id uuid not null references auth.users(id) on delete cascade,
    local_day date not null,
    token uuid not null,
    primary key (user_id, local_day)
);
alter table public.pulse_attention_reservations enable row level security;
revoke all on public.pulse_attention_reservations from public, anon;
grant select, insert on public.pulse_attention_reservations to authenticated;
create policy pulse_attention_reservations_select on public.pulse_attention_reservations for select to authenticated using ((select auth.uid()) = user_id);
create policy pulse_attention_reservations_insert on public.pulse_attention_reservations for insert to authenticated with check ((select auth.uid()) = user_id);
create function public.reserve_pulse_attention(p_day date, p_token uuid) returns boolean
language plpgsql security invoker set search_path = '' as $$
declare owner_id uuid := auth.uid(); allowed boolean;
begin
    if owner_id is null or p_token is null or p_day is null or p_day < (now() at time zone 'UTC')::date - 1 or p_day > (now() at time zone 'UTC')::date + 8 then return false; end if;
    perform pg_advisory_xact_lock(hashtextextended(owner_id::text, 0));
    if exists (select 1 from public.pulse_attention_preferences where user_id = owner_id and attention_limit = 'quiet') then return false; end if;
    insert into public.pulse_attention_reservations(user_id, local_day, token) values(owner_id, p_day, p_token) on conflict do nothing;
    select token = p_token into allowed from public.pulse_attention_reservations where user_id = owner_id and local_day = p_day;
    return coalesce(allowed, false);
end;
$$;
revoke all on function public.reserve_pulse_attention(date, uuid) from public, anon;
grant execute on function public.reserve_pulse_attention(date, uuid) to authenticated;

alter table public.usual_meals add constraint usual_meals_owner_id_unique unique(user_id,id);
create table public.breakfast_checkin_preferences (
    user_id uuid primary key references auth.users(id) on delete cascade,
    usual_meal_id uuid not null,
    foreign key(user_id, usual_meal_id) references public.usual_meals(user_id,id) on delete cascade
);
alter table public.breakfast_checkin_preferences enable row level security;
revoke all on public.breakfast_checkin_preferences from public, anon;
grant select, insert, update, delete on public.breakfast_checkin_preferences to authenticated;
create policy breakfast_preferences_owner on public.breakfast_checkin_preferences for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Qualitative records, intentionally no calories, portions or protein columns.
create table public.breakfast_checkins (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    local_day date not null,
    usual_meal_id uuid,
    name text not null check (length(btrim(name)) between 1 and 80 and name !~ '^[[:space:]]*$'),
    created_at timestamptz not null default now(),
    unique(user_id, local_day),
    foreign key(user_id, usual_meal_id) references public.usual_meals(user_id,id) on delete set null (usual_meal_id)
);
alter table public.breakfast_checkins enable row level security;
revoke all on public.breakfast_checkins from public, anon;
grant select, insert, update, delete on public.breakfast_checkins to authenticated;
create policy breakfast_checkins_owner on public.breakfast_checkins for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
