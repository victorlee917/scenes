-- Per-scene content count limit by tier.
--
-- Free pair: 30 contents per scene.
-- HD pair  : 100 contents per scene.
--
-- Enforced by BEFORE INSERT trigger that derives the active HD status from
-- pair_has_active_hd() (introduced in 0019). A small race window between two
-- concurrent inserts can let the count drift by 1 over limit; acceptable for
-- couple-app scale and avoids serializing all inserts on a scene-row lock.
--
-- Existing scenes that already exceed the limit are not retroactively pruned;
-- they are simply blocked from accepting new inserts until they fall back
-- under (via deletion) or the pair upgrades to HD.

create or replace function public.contents_enforce_per_scene_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pair_id uuid;
  v_count int;
  v_is_hd boolean;
  v_limit int;
begin
  select s.pair_id into v_pair_id
  from public.scenes s
  where s.id = new.scene_id;

  if v_pair_id is null then
    -- Scene missing — let downstream RLS / FK reject this row.
    return new;
  end if;

  v_is_hd := public.pair_has_active_hd(v_pair_id::text);
  v_limit := case when v_is_hd then 100 else 30 end;

  select count(*) into v_count
  from public.contents
  where scene_id = new.scene_id;

  if v_count >= v_limit then
    raise exception 'scene_content_limit_reached'
      using errcode = 'P0001',
            hint = format(
              'limit=%s tier=%s',
              v_limit,
              case when v_is_hd then 'hd' else 'free' end
            );
  end if;

  return new;
end;
$$;

-- Trigger name sorts before contents_manage_position_and_immutables_trigger
-- (e < m), so the limit guard fires first.
drop trigger if exists contents_enforce_per_scene_limit_trigger
  on public.contents;

create trigger contents_enforce_per_scene_limit_trigger
before insert on public.contents
for each row execute function public.contents_enforce_per_scene_limit();
