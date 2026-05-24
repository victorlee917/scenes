-- Drop deprecated content_likes table + related artifacts.
--
-- Replaced by content_reactions (0024) which covers the same like UX (❤️
-- emoji as one of 6 reactions) plus more. UI no longer calls the like RPC.
--
-- scene_summary view had a likes_count column that depended on content_likes
-- — recreate the view without it (client never used the column). Recreating
-- atomically in the same transaction so callers see no missing-view window.

drop view if exists public.scene_summary;

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

drop trigger if exists content_likes_notify_partner_activity
  on public.content_likes;

drop function if exists public.toggle_content_like(uuid);

drop table if exists public.content_likes;
