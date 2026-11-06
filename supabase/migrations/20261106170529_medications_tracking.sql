-- Effective schedules, activation intervals, dated dose snapshots and audit events are
-- committed together. Revision + write_id provide CAS and idempotent network retries.
create table public.medication_tracking (
    user_id uuid primary key references auth.users(id) on delete cascade,
    revision bigint not null check (revision > 0),
    write_id uuid not null,
    document jsonb not null check (
        jsonb_typeof(document) = 'object'
        and jsonb_typeof(document->'enabled') = 'boolean'
        and jsonb_typeof(document->'intervals') = 'array'
        and jsonb_typeof(document->'schedules') = 'array'
        and jsonb_typeof(document->'doses') = 'object'
        and jsonb_typeof(document->'events') = 'array'
        and document ?& array['enabled','intervals','schedules','doses','events']
    ),
    updated_at timestamptz not null default now()
);
alter table public.medication_tracking enable row level security;
revoke all on public.medication_tracking from public, anon, authenticated;
grant select, insert, update on public.medication_tracking to authenticated;
create policy medication_tracking_select on public.medication_tracking for select to authenticated
    using ((select auth.uid()) = user_id);
create policy medication_tracking_insert on public.medication_tracking for insert to authenticated
    with check ((select auth.uid()) = user_id);
create policy medication_tracking_update on public.medication_tracking for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create function public.save_medication_tracking(expected_revision bigint, new_document jsonb, new_write_id uuid)
returns setof public.medication_tracking
language plpgsql security invoker set search_path = '' as $$
declare
    owner_id uuid := auth.uid();
begin
    if owner_id is null or expected_revision is null or expected_revision < 0 or new_write_id is null then
        raise exception 'Invalid medication write' using errcode = '22023';
    end if;
    if expected_revision = 0 then
        insert into public.medication_tracking(user_id, revision, write_id, document)
        values (owner_id, 1, new_write_id, new_document)
        on conflict (user_id) do nothing;
    end if;
    -- A response may be lost after commit. Returning the existing write lets the
    -- durable outbox acknowledge that retry without duplicating its events.
    return query select m.* from public.medication_tracking m
        where m.user_id = owner_id and m.write_id = new_write_id;
    if found then return; end if;
    return query update public.medication_tracking m
        set document = new_document, revision = m.revision + 1,
            write_id = new_write_id, updated_at = now()
        where m.user_id = owner_id and m.revision = expected_revision
        returning m.*;
    -- Zero rows means a revision conflict; the client retains its local document.
end;
$$;
revoke all on function public.save_medication_tracking(bigint, jsonb, uuid) from public, anon;
grant execute on function public.save_medication_tracking(bigint, jsonb, uuid) to authenticated;
