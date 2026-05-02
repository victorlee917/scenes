-- couples lifecycle hardening
--
-- (1) Cross-side active uniqueness
--     0002's partial unique indexes only catch same-side duplicates because of
--     the partner_a_id < partner_b_id normalization. A user can still appear
--     as partner_a in one active couple and partner_b in another. A trigger
--     enforces "one active couple per user" across both sides.
--
-- (2) Account deletion = 'abandoned', never restorable
--     When a profile is deleted the couple row stays so the surviving partner
--     can read history. Status transitions to 'abandoned' and is read-only
--     forever (active requires both partners present).

-- Allow null partners (set by FK SET NULL on profile deletion).
alter table public.couples
  alter column partner_a_id drop not null,
  alter column partner_b_id drop not null;

-- Replace partner FKs: cascade -> set null
do $$
declare
  r record;
begin
  for r in
    select conname from pg_constraint
    where conrelid = 'public.couples'::regclass
      and contype = 'f'
  loop
    execute format('alter table public.couples drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.couples
  add constraint couples_partner_a_id_fkey
    foreign key (partner_a_id) references public.profiles(id) on delete set null,
  add constraint couples_partner_b_id_fkey
    foreign key (partner_b_id) references public.profiles(id) on delete set null;

-- Replace check constraints with named ones that handle null partners + abandoned.
do $$
declare
  r record;
begin
  for r in
    select conname from pg_constraint
    where conrelid = 'public.couples'::regclass
      and contype = 'c'
  loop
    execute format('alter table public.couples drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.couples
  add constraint couples_status_check
    check (status in ('active', 'ended', 'abandoned')),
  add constraint couples_partner_order_check
    check (partner_a_id is null or partner_b_id is null or partner_a_id < partner_b_id),
  add constraint couples_terminal_state_check
    check ((status in ('ended', 'abandoned')) = (ended_at is not null)),
  add constraint couples_ended_by_terminal_only_check
    check (ended_by is null or status in ('ended', 'abandoned')),
  add constraint couples_active_requires_both_partners_check
    check (status <> 'active' or (partner_a_id is not null and partner_b_id is not null));

-- (1) Cross-side active uniqueness via trigger.
create or replace function public.couples_enforce_single_active_per_user()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'active' then
    if exists (
      select 1 from public.couples c
      where c.id <> new.id
        and c.status = 'active'
        and (
          c.partner_a_id in (new.partner_a_id, new.partner_b_id)
          or c.partner_b_id in (new.partner_a_id, new.partner_b_id)
        )
    ) then
      raise exception 'user is already in an active couple'
        using errcode = '23505';
    end if;
  end if;
  return new;
end;
$$;

create trigger couples_single_active_per_user
before insert or update on public.couples
for each row execute function public.couples_enforce_single_active_per_user();

-- (2) On profile deletion: abandon active couples, drop rows with no surviving reader.
create or replace function public.couples_handle_profile_deletion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Active couples involving this user become 'abandoned' BEFORE the FK SET NULL
  -- fires, so we don't violate couples_active_requires_both_partners_check.
  update public.couples
  set
    status = 'abandoned',
    ended_at = coalesce(ended_at, now()),
    ended_by = old.id
  where status = 'active'
    and (partner_a_id = old.id or partner_b_id = old.id);

  -- If the other side is already null, this user was the last reader; drop it.
  delete from public.couples
  where (partner_a_id = old.id and partner_b_id is null)
     or (partner_b_id = old.id and partner_a_id is null);

  return old;
end;
$$;

create trigger profiles_before_delete_handle_couples
before delete on public.profiles
for each row execute function public.couples_handle_profile_deletion();
