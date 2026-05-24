-- Reorder contents within a scene.
--
-- 기존 contents UPDATE RLS는 created_by = auth.uid()로 제한 — 작성자만 자기
-- row를 수정. 근데 reorder는 scene 안의 모든 contents의 position을 한꺼번에
-- 바꿔야 하고 contents의 작성자가 본인/파트너 섞여있을 수 있어 일반 UPDATE로
-- 처리 불가. security definer RPC로 권한 체크 (active couple member) 후
-- position만 일괄 update.

create or replace function public.reorder_scene_contents(
  p_scene_id uuid,
  p_ordered_ids uuid[]
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pair_id uuid;
  v_caller uuid;
begin
  v_caller := auth.uid();
  if v_caller is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  select s.pair_id into v_pair_id
  from public.scenes s
  where s.id = p_scene_id;

  if v_pair_id is null then
    raise exception 'scene not found' using errcode = 'P0001';
  end if;

  -- active couple 멤버만 reorder 가능 — disconnect 후엔 read-only.
  if not exists (
    select 1
    from public.couples c
    where c.pair_id = v_pair_id
      and c.status = 'active'
      and v_caller in (c.partner_a_id, c.partner_b_id)
  ) then
    raise exception 'not authorized to reorder this scene'
      using errcode = '42501';
  end if;

  -- 배열 순서대로 position 1..N 부여. scene_id가 다른 row가 섞여 들어와도
  -- 영향 없도록 where 절에 scene_id 같이 매칭.
  for i in 1..coalesce(array_length(p_ordered_ids, 1), 0) loop
    update public.contents
    set position = i
    where id = p_ordered_ids[i]
      and scene_id = p_scene_id;
  end loop;
end;
$$;

revoke all on function public.reorder_scene_contents(uuid, uuid[])
  from public, anon;
grant execute on function public.reorder_scene_contents(uuid, uuid[])
  to authenticated;
