-- contents.shared
-- 콘텐츠(=moment)를 공유 페이지에 노출할지 여부. 기본 false(옵트인).
--
-- 토글 권한: contents의 일반 편집은 created_by만 가능(0012 authorship rule)
-- 하지만 "공유 여부"는 콘텐츠 편집이 아니라 페어 차원의 결정이라, **active
-- 페어 멤버 누구나** 토글할 수 있어야 한다. created_by-only UPDATE 정책을
-- 건드리지 않고, SECURITY DEFINER RPC로 shared만 갱신한다.

alter table public.contents
  add column shared boolean not null default false;

-- 특정 scene의 콘텐츠 공유 상태를 일괄 설정.
-- p_shared_ids에 든 콘텐츠는 shared=true, 같은 scene의 나머지는 false.
-- 호출자는 그 scene이 속한 pair의 active 멤버여야 한다.
create or replace function public.set_scene_shared_contents(
  p_scene_id uuid,
  p_shared_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pair_id uuid;
begin
  select pair_id into v_pair_id
  from public.scenes
  where id = p_scene_id;

  if v_pair_id is null then
    raise exception 'scene not found';
  end if;

  if not exists (
    select 1 from public.couples c
    where c.pair_id = v_pair_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  ) then
    raise exception 'not an active pair member';
  end if;

  update public.contents
  set shared = (id = any(p_shared_ids))
  where scene_id = p_scene_id;
end;
$$;

revoke all on function public.set_scene_shared_contents(uuid, uuid[])
  from public, anon;
grant execute on function public.set_scene_shared_contents(uuid, uuid[])
  to authenticated;
