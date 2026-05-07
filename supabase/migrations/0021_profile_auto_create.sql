-- 0021_profile_auto_create
-- Supabase Auth가 새 user를 만들 때 profiles row를 자동 생성.
--
-- 0001 주석은 "trigger 안 쓰고 클라가 명시 생성"이었지만, 카카오 OIDC 도입 후
-- idToken에 nickname/email이 들어오므로 그걸 초기 name으로 채워 row를 만들 수
-- 있다. profile-setup 화면은 사용자가 원하면 name·avatar 편집하는 단계로
-- 의미가 바뀜 (`onboarding_completed_at` null이면 라우터가 그쪽으로 보냄).
--
-- name 결정 우선순위:
--   1. raw_user_meta_data->>'nickname' (Kakao OIDC nickname claim)
--   2. raw_user_meta_data->>'name'
--   3. raw_user_meta_data->>'preferred_username'
--   4. email의 '@' 앞부분
--   5. fallback 'User'
-- 길이는 12자로 자른다 (profiles.name CHECK 제약).

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  raw_name text;
  final_name text;
begin
  raw_name := coalesce(
    new.raw_user_meta_data->>'nickname',
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'preferred_username',
    split_part(coalesce(new.email, ''), '@', 1),
    'User'
  );

  -- 12자 초과 시 cut. 빈 문자열이면 'User' fallback.
  final_name := substring(raw_name, 1, 12);
  if char_length(final_name) = 0 then
    final_name := 'User';
  end if;

  insert into public.profiles (id, name, locale)
  values (
    new.id,
    final_name,
    -- raw_user_meta_data->>'locale'이 있으면 사용 (Kakao는 보통 안 보냄).
    case
      when new.raw_user_meta_data->>'locale' = 'ko' then 'ko'
      else 'en'
    end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();
