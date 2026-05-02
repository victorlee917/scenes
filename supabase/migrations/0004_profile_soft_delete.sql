-- Profile soft-delete
--
-- Default account-deletion flow becomes soft-delete: profile row is preserved
-- (so the surviving partner keeps reading shared content + the deleted
-- partner's masked profile), and only `deleted_at` is set. Active couples
-- transition to 'abandoned' on this event.
--
-- Hard-delete (e.g., GDPR) is handled case-by-case by admin and still works
-- via the 0003 BEFORE DELETE trigger as a safety net. The FK to auth.users
-- is now `on delete restrict` so the auth row can't be removed while a
-- profile still references it — admin must clean up the profile first.
--
-- The client masks `name` / `avatar_url` whenever `deleted_at is not null`,
-- so DB stores the original name; no destructive overwrite needed.

-- (1) profiles.id → auth.users(id): cascade -> restrict
do $$
declare
  r record;
begin
  for r in
    select conname from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'f'
      and conname like '%id_fkey%'
  loop
    execute format('alter table public.profiles drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.profiles
  add constraint profiles_id_fkey
    foreign key (id) references auth.users(id) on delete restrict;

-- (2) deleted_at column.
alter table public.profiles
  add column deleted_at timestamptz;

-- (3) Expand partner read policy: drop the active-only restriction so past
-- partners (any couple status) remain readable.
drop policy if exists "profiles_select_partner" on public.profiles;
create policy "profiles_select_partner"
on public.profiles for select
using (
  exists (
    select 1
    from public.couples c
    where (
      (c.partner_a_id = auth.uid() and c.partner_b_id = profiles.id)
      or (c.partner_b_id = auth.uid() and c.partner_a_id = profiles.id)
    )
  )
);

-- (4) Soft-delete trigger: enforce immutability + abandon active couple on transition.
create or replace function public.profiles_handle_deleted_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Once set, deleted_at cannot be changed (no resurrection from app side).
  if old.deleted_at is not null
     and (new.deleted_at is distinct from old.deleted_at) then
    raise exception 'profiles.deleted_at is immutable once set';
  end if;

  -- On null -> not null transition, abandon active couple involving this user.
  if old.deleted_at is null and new.deleted_at is not null then
    update public.couples
    set
      status = 'abandoned',
      ended_at = coalesce(ended_at, now()),
      ended_by = new.id
    where status = 'active'
      and (partner_a_id = new.id or partner_b_id = new.id);
  end if;

  return new;
end;
$$;

create trigger profiles_deleted_at_trigger
before update of deleted_at on public.profiles
for each row execute function public.profiles_handle_deleted_at();
