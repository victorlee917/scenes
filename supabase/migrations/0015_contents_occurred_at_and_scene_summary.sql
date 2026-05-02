-- contents.occurred_at + scene_summary view
--
-- occurred_at distinguishes "when this content's event happened" (photo taken
-- date, film watch date, place visit timestamp, etc.) from created_at ("when
-- the row was inserted, i.e., uploaded"). Photos can populate this from EXIF
-- on the client; other types may leave it null if unknown.
--
-- scene_summary aggregates per-type counts and the earliest/latest occurred_at
-- per scene, denormalized with scene metadata so the home screen can render a
-- card with a single read. security_invoker = on so base-table RLS applies.

-- (1) occurred_at column
alter table public.contents
  add column occurred_at timestamptz;

create index contents_scene_id_occurred_at_idx
  on public.contents(scene_id, occurred_at);

-- (2) scene_summary view
create view public.scene_summary
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
  c.latest_occurred_at
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
) c on c.scene_id = s.id;
