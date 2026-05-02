-- contents
-- A content row is one media item inside a scene (a photo, film reference,
-- music track, place, etc.). Each row has a `type` discriminator and a
-- `payload` jsonb whose shape depends on type. New types can be added later
-- by extending the type check + adding payload structure on the client.
--
-- Authorship rule: only the author (created_by) can update or delete their
-- own content. Partners can only read. (scenes themselves are jointly
-- editable; this read-vs-write split applies to content rows only.)
--
-- Authoring lifecycle:
--   * On profile soft-delete (deleted_at set), the deleted user can no longer
--     sign in, so their own contents become naturally uneditable. Partner's
--     read access continues.
--   * On profile hard-delete, FK on created_by is `set null`, attribution is
--     lost but the row survives so the partner can still read.

create table public.contents (
  id uuid primary key default gen_random_uuid(),
  scene_id uuid not null references public.scenes(id) on delete cascade,

  type text not null
    check (type in ('photo', 'film', 'music', 'place')),
  payload jsonb not null,

  position int not null default 0,

  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index contents_scene_id_position_idx on public.contents(scene_id, position);
create index contents_created_by_idx on public.contents(created_by);
create index contents_type_idx on public.contents(type);

create trigger contents_set_updated_at
before update on public.contents
for each row execute function public.set_updated_at();

-- Auto-assign position on insert; enforce immutability of scene_id/type.
create or replace function public.contents_manage_position_and_immutables()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    select coalesce(max(position), 0) + 1 into new.position
    from public.contents
    where scene_id = new.scene_id;
  elsif tg_op = 'UPDATE' then
    if new.scene_id is distinct from old.scene_id then
      raise exception 'contents.scene_id is immutable';
    end if;
    if new.type is distinct from old.type then
      raise exception 'contents.type is immutable';
    end if;
  end if;
  return new;
end;
$$;

create trigger contents_manage_position_and_immutables_trigger
before insert or update on public.contents
for each row execute function public.contents_manage_position_and_immutables();

-- RLS
alter table public.contents enable row level security;

-- SELECT: any pair member of the scene's pair (status agnostic — read after disconnect)
create policy "contents_select_pair_member"
on public.contents for select
using (
  exists (
    select 1
    from public.scenes s
    join public.couples c on c.pair_id = s.pair_id
    where s.id = contents.scene_id
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- INSERT: only by the author themselves, into a scene of an active couple
create policy "contents_insert_author_active"
on public.contents for insert
with check (
  created_by = auth.uid()
  and exists (
    select 1
    from public.scenes s
    join public.couples c on c.pair_id = s.pair_id
    where s.id = contents.scene_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- UPDATE: only the author, in an active couple
create policy "contents_update_author_active"
on public.contents for update
using (
  created_by = auth.uid()
  and exists (
    select 1
    from public.scenes s
    join public.couples c on c.pair_id = s.pair_id
    where s.id = contents.scene_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
)
with check (
  created_by = auth.uid()
  and exists (
    select 1
    from public.scenes s
    join public.couples c on c.pair_id = s.pair_id
    where s.id = contents.scene_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- DELETE: same as UPDATE
create policy "contents_delete_author_active"
on public.contents for delete
using (
  created_by = auth.uid()
  and exists (
    select 1
    from public.scenes s
    join public.couples c on c.pair_id = s.pair_id
    where s.id = contents.scene_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);
