-- scenes
-- A scene is a folder/container for related content (photo / film / music /
-- place / etc.). Each pair has its own scene namespace; scenes are bound to
-- pair_id (per the content_keyed_by_pair_id rule) so re-pairing of the same
-- two people keeps the timeline.
--
-- Two ordering fields:
--   * number   — permanent, system-assigned (1, 2, 3, ...) per pair. Immutable
--                once set. Used for "Scene I / II / III" labels.
--   * position — user-editable display order (e.g., drag-and-drop). Trigger
--                appends to end of list on insert; the user reorders later.
--
-- Cover image is optional; the client falls back to the first content's image,
-- then to a default placeholder, when cover_storage_path is null.

create table public.scenes (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null,

  number int not null,
  position int not null default 0,

  title text not null
    check (char_length(title) between 1 and 100),

  -- One scene can span multiple dates (weekend trip, holiday, etc.)
  dates date[] not null
    check (cardinality(dates) >= 1),

  -- Optional explicit cover. Null = client falls back.
  cover_storage_path text,

  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (pair_id, number)
);

create index scenes_pair_id_position_idx on public.scenes(pair_id, position);
create index scenes_pair_id_created_at_idx on public.scenes(pair_id, created_at desc);

-- updated_at auto-bump (reuses 0001's set_updated_at)
create trigger scenes_set_updated_at
before update on public.scenes
for each row execute function public.set_updated_at();

-- Auto-assign number/position on insert; enforce immutability on update.
create or replace function public.scenes_manage_number_and_position()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    select coalesce(max(number), 0) + 1 into new.number
    from public.scenes
    where pair_id = new.pair_id;

    select coalesce(max(position), 0) + 1 into new.position
    from public.scenes
    where pair_id = new.pair_id;
  elsif tg_op = 'UPDATE' then
    if new.number is distinct from old.number then
      raise exception 'scenes.number is immutable';
    end if;
    if new.pair_id is distinct from old.pair_id then
      raise exception 'scenes.pair_id is immutable';
    end if;
  end if;
  return new;
end;
$$;

create trigger scenes_manage_number_and_position_trigger
before insert or update on public.scenes
for each row execute function public.scenes_manage_number_and_position();

-- RLS
alter table public.scenes enable row level security;

-- SELECT: any member of the pair (status agnostic — can read after disconnect)
create policy "scenes_select_pair_member"
on public.scenes for select
using (
  exists (
    select 1 from public.couples c
    where c.pair_id = scenes.pair_id
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- INSERT: only members of an *active* couple for this pair, attributing to self
create policy "scenes_insert_active_pair_member"
on public.scenes for insert
with check (
  created_by = auth.uid()
  and exists (
    select 1 from public.couples c
    where c.pair_id = scenes.pair_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- UPDATE: either partner of an active couple may edit any scene of the pair
create policy "scenes_update_active_pair_member"
on public.scenes for update
using (
  exists (
    select 1 from public.couples c
    where c.pair_id = scenes.pair_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
)
with check (
  exists (
    select 1 from public.couples c
    where c.pair_id = scenes.pair_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- DELETE: same as UPDATE
create policy "scenes_delete_active_pair_member"
on public.scenes for delete
using (
  exists (
    select 1 from public.couples c
    where c.pair_id = scenes.pair_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);
