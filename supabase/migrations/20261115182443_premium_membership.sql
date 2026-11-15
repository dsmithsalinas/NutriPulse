-- Membership state is server-written only. RPCs use invoker rights and are callable
-- only by service_role after Edge Functions verify the request's current auth user.
create table public.membership_campaign (
 id boolean primary key default true check (id),
 enabled boolean not null default false,
 claimed integer not null default 0 check (claimed between 0 and 50)
);
insert into public.membership_campaign(id) values(true);
create table public.founding_memberships (
 user_id uuid primary key references auth.users(id) on delete cascade,
 claimed_at timestamptz not null default now(),
 expires_at timestamptz not null,
 check(expires_at > claimed_at)
);
create table public.apple_subscriptions (
 original_transaction_id text not null,
 user_id uuid not null references auth.users(id) on delete cascade,
 environment text not null check(environment in ('Production','Sandbox')),
 product_id text not null check(product_id='com.dustin.nutripulse.premium.monthly'),
 transaction_id text not null,
 status integer not null check(status between 1 and 5),
 expires_at timestamptz not null,
 revoked boolean not null default false,
 signed_at timestamptz not null,
 checked_at timestamptz not null,
 primary key(environment,original_transaction_id)
);
create index apple_subscriptions_owner on public.apple_subscriptions(user_id);
create table public.membership_ai_usage (
 user_id uuid not null references auth.users(id) on delete cascade,
 month date not null,
 bucket text not null check(bucket in ('pulse','food')),
 used integer not null default 0 check(used >= 0),
 primary key(user_id,month,bucket)
);
create table public.membership_global_usage (
 month date primary key,
 used integer not null default 0 check(used >= 0)
);
-- No Data API grants or owner-write policies: a client cannot mint its own access.
alter table public.membership_campaign enable row level security;
alter table public.founding_memberships enable row level security;
alter table public.apple_subscriptions enable row level security;
alter table public.membership_ai_usage enable row level security;
alter table public.membership_global_usage enable row level security;
revoke all on public.membership_campaign, public.founding_memberships, public.apple_subscriptions,
 public.membership_ai_usage, public.membership_global_usage from public, anon, authenticated;
grant all on public.membership_campaign, public.founding_memberships, public.apple_subscriptions,
 public.membership_ai_usage, public.membership_global_usage to service_role;

create function public.membership_snapshot(p_user_id uuid,p_allow_sandbox boolean default false) returns jsonb
language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
 'user_id',p_user_id,
 'founder_expires_at',(select expires_at from public.founding_memberships where user_id=p_user_id),
 'premium_expires_at',(select max(expires_at) from (
   select expires_at from public.founding_memberships where user_id=p_user_id
   union all
   select least(expires_at,checked_at+interval '24 hours') from public.apple_subscriptions
    where user_id=p_user_id and (environment='Production' or p_allow_sandbox) and status in (1,4) and not revoked
 ) dates),
 'founder_available',(select enabled and claimed<50 from public.membership_campaign where id),
 'founder_claimed',exists(select 1 from public.founding_memberships where user_id=p_user_id),
 'subscription_expires_at',(select max(expires_at) from public.apple_subscriptions where user_id=p_user_id and (environment='Production' or p_allow_sandbox) and status in (1,4) and not revoked),
 'pulse_used',coalesce((select used from public.membership_ai_usage where user_id=p_user_id and month=date_trunc('month',now() at time zone 'UTC')::date and bucket='pulse'),0),
 'food_used',coalesce((select used from public.membership_ai_usage where user_id=p_user_id and month=date_trunc('month',now() at time zone 'UTC')::date and bucket='food'),0));
$$;

create function public.claim_founding_membership(p_user_id uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare campaign public.membership_campaign; stamp timestamptz:=now();
begin
 -- Serializes the last place and repeat requests. Deletion never decrements claimed.
 select * into strict campaign from public.membership_campaign where id for update;
 if exists(select 1 from public.founding_memberships where user_id=p_user_id) then
   return public.membership_snapshot(p_user_id);
 end if;
 if not campaign.enabled or campaign.claimed>=50 then raise exception 'founder_unavailable'; end if;
 -- The Edge Function checks confirmed auth identity before invoking this service-only RPC.
 -- service_role deliberately has no direct SELECT grant on auth.users in production.
 -- The FK rejects a nonexistent/deleted owner and rolls the whole claim back.
 -- Don't consume a free place for an already paying account.
 if exists(select 1 from public.apple_subscriptions where user_id=p_user_id and status in (1,4) and not revoked and expires_at>stamp) then
   raise exception 'already_subscribed';
 end if;
 insert into public.founding_memberships(user_id,claimed_at,expires_at) values(p_user_id,stamp,stamp+interval '3 months');
 update public.membership_campaign set claimed=claimed+1 where id;
 return public.membership_snapshot(p_user_id);
end $$;

create function public.record_apple_subscription(p_user_id uuid,p_original text,p_environment text,
 p_product text,p_transaction text,p_status integer,p_expires timestamptz,p_revoked boolean,
 p_signed timestamptz,p_checked timestamptz) returns void
language plpgsql security invoker set search_path='' as $$
begin
 if p_signed>now()+interval '5 minutes' or p_checked>now()+interval '5 minutes' then raise exception 'invalid_timestamp'; end if;
 insert into public.apple_subscriptions as current(user_id,original_transaction_id,environment,product_id,transaction_id,status,expires_at,revoked,signed_at,checked_at)
 values(p_user_id,p_original,p_environment,p_product,p_transaction,p_status,p_expires,p_revoked,p_signed,p_checked)
 on conflict(environment,original_transaction_id) do update set transaction_id=excluded.transaction_id,status=excluded.status,
 expires_at=excluded.expires_at,revoked=excluded.revoked,signed_at=excluded.signed_at,checked_at=excluded.checked_at
 where current.user_id=excluded.user_id and current.environment=excluded.environment
 and excluded.signed_at>=current.signed_at and excluded.checked_at>=current.checked_at;
 if exists(select 1 from public.apple_subscriptions where original_transaction_id=p_original and environment=p_environment and user_id<>p_user_id) then
  raise exception 'subscription_owner_mismatch';
 end if;
end $$;

-- Counts attempted provider operations, including retries. Bounds per-account and global
-- monthly volume atomically. Both entitlement and quota lookup failures fail closed.
create function public.reserve_membership_ai(p_user_id uuid,p_bucket text,p_limit integer,p_global_limit integer,p_allow_sandbox boolean default false) returns text
language plpgsql security invoker set search_path='' as $$
declare m date:=date_trunc('month',now() at time zone 'UTC')::date; used_count integer;
begin
 if p_bucket not in ('pulse','food') or p_limit<1 or p_global_limit<1 then raise exception 'invalid_quota'; end if;
 if not exists(select 1 from public.founding_memberships where user_id=p_user_id and expires_at>now())
 and not exists(select 1 from public.apple_subscriptions where user_id=p_user_id and (environment='Production' or p_allow_sandbox) and status in (1,4) and not revoked and expires_at>now() and checked_at>now()-interval '24 hours') then
  return 'membership_required';
 end if;
 insert into public.membership_global_usage(month) values(m) on conflict do nothing;
 select used into used_count from public.membership_global_usage where month=m for update;
 if used_count>=p_global_limit then return 'ai_temporarily_unavailable'; end if;
 insert into public.membership_ai_usage(user_id,month,bucket) values(p_user_id,m,p_bucket) on conflict do nothing;
 select used into used_count from public.membership_ai_usage where user_id=p_user_id and month=m and bucket=p_bucket for update;
 if used_count>=p_limit then return 'membership_limit_reached'; end if;
 update public.membership_ai_usage set used=used+1 where user_id=p_user_id and month=m and bucket=p_bucket;
 update public.membership_global_usage set used=used+1 where month=m;
 return 'allowed';
end $$;
revoke all on function public.membership_snapshot(uuid,boolean),public.claim_founding_membership(uuid),
 public.record_apple_subscription(uuid,text,text,text,text,integer,timestamptz,boolean,timestamptz,timestamptz),
 public.reserve_membership_ai(uuid,text,integer,integer,boolean) from public,anon,authenticated;
grant execute on function public.membership_snapshot(uuid,boolean),public.claim_founding_membership(uuid),
 public.record_apple_subscription(uuid,text,text,text,text,integer,timestamptz,boolean,timestamptz,timestamptz),
 public.reserve_membership_ai(uuid,text,integer,integer,boolean) to service_role;
