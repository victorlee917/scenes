-- pair_stats view
--
-- Per-pair aggregated counts shown on the profile screen. Only active pairs
-- are surfaced; ended/abandoned pairs are excluded. Counts include the entire
-- history under the pair_id (which is stable across re-pairings), so old
-- scenes from prior pairing sessions of the same two people are also counted.
--
-- security_invoker = on so the view runs under the caller's permissions and
-- the base-table RLS naturally restricts visibility:
--   * pair members see their own pair's row with full counts
--   * non-members see no rows
--
-- The client should fetch its own active pair_id from couples first, then
-- query pair_stats with that id. There is at most one active pair per user
-- (enforced by 0003 trigger), so this is a single-row read.

create view public.pair_stats
with (security_invoker = on)
as
select
  active_pairs.pair_id,
  coalesce(s.cnt, 0)::int as scenes_count,
  coalesce(c.photos, 0)::int as photos_count,
  coalesce(c.films, 0)::int as films_count,
  coalesce(c.musics, 0)::int as musics_count,
  coalesce(c.places, 0)::int as places_count
from (
  select distinct pair_id
  from public.couples
  where status = 'active'
) active_pairs
left join (
  select pair_id, count(*) as cnt
  from public.scenes
  group by pair_id
) s on s.pair_id = active_pairs.pair_id
left join (
  select sc.pair_id,
    count(*) filter (where co.type = 'photo') as photos,
    count(*) filter (where co.type = 'film')  as films,
    count(*) filter (where co.type = 'music') as musics,
    count(*) filter (where co.type = 'place') as places
  from public.contents co
  join public.scenes sc on sc.id = co.scene_id
  group by sc.pair_id
) c on c.pair_id = active_pairs.pair_id;
