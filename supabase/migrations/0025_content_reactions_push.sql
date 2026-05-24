-- Push notifications for content_reactions.
--
-- Fires on INSERT only — emoji 변경(이후 UPDATE)이나 comment 추가도 별도
-- 알림은 안 보냄 (사용자 요청). 알림 설정은 기존 partner_activity_enabled를
-- 그대로 사용.
--
-- Push payload:
--   title: actor 이름
--   body : "Reacted to your moment"
--          "Left a comment on your moment"
--
-- 콘텐츠 종류 (photo/film/music/place)와 무관하게 generic 'moment' 사용 —
-- 우리 앱의 noun 톤과 일치. medium별 분기 X.

create or replace function public.notify_partner_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_partner uuid;
  v_pair_id uuid;
  v_scene_id uuid;
  v_kind text;
  v_title text;
  v_body text;
  v_pref boolean;
  v_actor_name text;
begin
  if tg_table_name = 'scenes' then
    v_actor := new.created_by;
    v_pair_id := new.pair_id;
    v_scene_id := new.id;
    v_kind := 'scene';
    v_title := 'New scene';
    v_body := new.title;
  elsif tg_table_name = 'contents' then
    v_actor := new.created_by;
    select pair_id into v_pair_id from public.scenes where id = new.scene_id;
    v_scene_id := new.scene_id;
    v_kind := new.type;
    v_title := 'New ' || new.type;
    v_body := 'Your person added a ' || new.type;
  elsif tg_table_name = 'content_likes' then
    v_actor := new.user_id;
    select s.pair_id, c.scene_id into v_pair_id, v_scene_id
    from public.contents c
    join public.scenes s on s.id = c.scene_id
    where c.id = new.content_id;
    v_kind := 'like';
    v_title := 'A moment got a like';
    v_body := 'Your person liked a moment';
  elsif tg_table_name = 'content_reactions' then
    v_actor := new.user_id;
    select s.pair_id, c.scene_id into v_pair_id, v_scene_id
    from public.contents c
    join public.scenes s on s.id = c.scene_id
    where c.id = new.content_id;

    select name into v_actor_name from public.profiles where id = v_actor;
    v_actor_name := coalesce(nullif(trim(v_actor_name), ''), 'Your person');

    v_kind := 'reaction';
    v_title := v_actor_name;
    if new.comment is not null and char_length(trim(new.comment)) > 0 then
      v_body := 'Left a comment on your moment';
    else
      v_body := 'Reacted to your moment';
    end if;
  else
    return new;
  end if;

  -- v_actor의 active 파트너 한 명 찾기
  select case
    when c.partner_a_id = v_actor then c.partner_b_id
    else c.partner_a_id
  end into v_partner
  from public.couples c
  where c.pair_id = v_pair_id
    and c.status = 'active'
    and v_actor in (c.partner_a_id, c.partner_b_id)
  limit 1;

  if v_partner is null then
    return new;
  end if;

  -- 파트너의 알림 설정 — 행이 없으면 기본 true로 간주.
  select partner_activity_enabled into v_pref
  from public.notification_preferences
  where user_id = v_partner;
  if coalesce(v_pref, true) = false then
    return new;
  end if;

  perform net.http_post(
    url := 'https://cmnzpmswkaykjjlmxkut.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'user_id', v_partner,
      'title', v_title,
      'body', v_body,
      'data', jsonb_build_object(
        'scene_id', v_scene_id,
        'kind', v_kind
      )
    )
  );

  return new;
end;
$$;

-- INSERT만 — UPDATE는 트리거 안 함(사용자 요청).
drop trigger if exists content_reactions_notify_partner_activity
  on public.content_reactions;

create trigger content_reactions_notify_partner_activity
after insert on public.content_reactions
for each row execute function public.notify_partner_activity();
