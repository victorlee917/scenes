-- content_likes
--
-- One row per (content, user). Composite PK enforces "at most one like per
-- user per content" naturally and is enough as a primary access path.
--
-- Following the active-couple-write rule, INSERT and DELETE are blocked
-- outside of an active couple — disconnect/abandon makes likes read-only on
-- historical content.
--
-- toggle_content_like RPC handles the like/unlike toggle in one round trip
-- and is the recommended client path; direct INSERT/DELETE is also allowed
-- (RLS still enforces the same rules).

create table public.content_likes (
  content_id uuid not null references public.contents(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (content_id, user_id)
);

create index content_likes_user_id_idx on public.content_likes(user_id);

alter table public.content_likes enable row level security;

-- SELECT: any pair member of the content's pair (status agnostic)
create policy "content_likes_select_pair_member"
on public.content_likes for select
using (
  exists (
    select 1
    from public.contents c
    join public.scenes s   on s.id = c.scene_id
    join public.couples cp on cp.pair_id = s.pair_id
    where c.id = content_likes.content_id
      and auth.uid() in (cp.partner_a_id, cp.partner_b_id)
  )
);

-- INSERT: own user_id, in an active couple of the content's pair
create policy "content_likes_insert_own_active"
on public.content_likes for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.contents c
    join public.scenes s   on s.id = c.scene_id
    join public.couples cp on cp.pair_id = s.pair_id
    where c.id = content_likes.content_id
      and cp.status = 'active'
      and auth.uid() in (cp.partner_a_id, cp.partner_b_id)
  )
);

-- DELETE: own likes only, in an active couple (unlike also blocked after disconnect)
create policy "content_likes_delete_own_active"
on public.content_likes for delete
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.contents c
    join public.scenes s   on s.id = c.scene_id
    join public.couples cp on cp.pair_id = s.pair_id
    where c.id = content_likes.content_id
      and cp.status = 'active'
      and auth.uid() in (cp.partner_a_id, cp.partner_b_id)
  )
);

-- toggle_content_like(content_id) -> boolean (true = now liked, false = now unliked)
create or replace function public.toggle_content_like(p_content_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_pair_id uuid;
begin
  if v_user_id is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  -- Resolve content -> pair_id
  select s.pair_id into v_pair_id
  from public.contents c
  join public.scenes s on s.id = c.scene_id
  where c.id = p_content_id;

  if v_pair_id is null then
    raise exception 'content not found' using errcode = 'P0001';
  end if;

  -- Caller must be in an active couple for this pair
  if not exists (
    select 1 from public.couples
    where pair_id = v_pair_id
      and status = 'active'
      and v_user_id in (partner_a_id, partner_b_id)
  ) then
    raise exception 'cannot toggle like outside active couple'
      using errcode = 'P0001';
  end if;

  -- Toggle: try DELETE first; fall through to INSERT if nothing was there
  delete from public.content_likes
  where content_id = p_content_id and user_id = v_user_id;

  if found then
    return false;
  end if;

  insert into public.content_likes (content_id, user_id)
  values (p_content_id, v_user_id);

  return true;
end;
$$;

revoke all on function public.toggle_content_like(uuid) from public, anon;
grant execute on function public.toggle_content_like(uuid) to authenticated;

-- Replace scene_summary to include total likes_count across the scene's contents
create or replace view public.scene_summary
with (security_invoker = on)
as
select
  s.id                      as scene_id,
  s.pair_id,
  s.number,
  s.position,
  s.title,
  s.dates,
  s.cover_storage_path,
  s.created_by,
  s.created_at,
  s.updated_at,
  coalesce(c.photos, 0)::int as photos_count,
  coalesce(c.films,  0)::int as films_count,
  coalesce(c.musics, 0)::int as musics_count,
  coalesce(c.places, 0)::int as places_count,
  coalesce(c.total,  0)::int as total_count,
  c.earliest_occurred_at,
  c.latest_occurred_at,
  coalesce(l.likes, 0)::int  as likes_count
from public.scenes s
left join (
  select
    scene_id,
    count(*) filter (where type = 'photo') as photos,
    count(*) filter (where type = 'film')  as films,
    count(*) filter (where type = 'music') as musics,
    count(*) filter (where type = 'place') as places,
    count(*)                               as total,
    min(occurred_at)                       as earliest_occurred_at,
    max(occurred_at)                       as latest_occurred_at
  from public.contents
  group by scene_id
) c on c.scene_id = s.id
left join (
  select co.scene_id, count(*) as likes
  from public.content_likes cl
  join public.contents co on co.id = cl.content_id
  group by co.scene_id
) l on l.scene_id = s.id;
