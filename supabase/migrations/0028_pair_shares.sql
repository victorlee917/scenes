-- pair_shares
-- 페어 공유 페이지 설정. 콘텐츠가 pair_id로 묶이고(memory:
-- content_keyed_by_pair_id) 공유도 pair 단위이므로, 공유용 닉네임(slug)도
-- couples row가 아니라 **pair_id 기준**으로 보관한다 — 재페어링(active couple
-- row 교체)에도 공유 URL이 유지된다.
--
-- slug는 도메인 뒤 path로 붙어(scenes.app/s/<slug>) 해당 pair의 공개 데이터를
-- 불러오는 키. 전역 유니크.
--
-- 쓰기 규칙: active 커플만 set/update 가능(memory: active_couple_writes),
-- ended 커플은 read-only.

create table public.pair_shares (
  -- pair_id는 couples에 유니크 제약이 없어(여러 row가 같은 pair 공유) FK는 걸지
  -- 않고 논리 키로만 사용. 한 pair당 공유 설정 한 건이라 PK로 충분.
  pair_id uuid primary key,

  -- 공개 URL path. 소문자 영숫자 + 중간 하이픈, 3~30자, 양끝은 영숫자.
  slug text not null unique
    check (slug ~ '^[a-z0-9]([a-z0-9-]{1,28}[a-z0-9])$'),

  created_by uuid references public.profiles(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger pair_shares_set_updated_at
before update on public.pair_shares
for each row execute function public.set_updated_at();

alter table public.pair_shares enable row level security;

-- SELECT: 해당 pair의 멤버(active/ended 무관 — 본인 페어 공유 설정은 조회 가능).
create policy "pair_shares_select_member"
on public.pair_shares for select
using (
  exists (
    select 1 from public.couples c
    where c.pair_id = pair_shares.pair_id
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- INSERT: active 커플 멤버만, 본인을 created_by로.
create policy "pair_shares_insert_active_member"
on public.pair_shares for insert
with check (
  created_by = auth.uid()
  and exists (
    select 1 from public.couples c
    where c.pair_id = pair_shares.pair_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- UPDATE: active 커플 멤버만 (닉네임 변경).
create policy "pair_shares_update_active_member"
on public.pair_shares for update
using (
  exists (
    select 1 from public.couples c
    where c.pair_id = pair_shares.pair_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
)
with check (
  exists (
    select 1 from public.couples c
    where c.pair_id = pair_shares.pair_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- slug 가용성 체크. SELECT RLS는 본인 pair row만 보이므로 클라가 "이 slug
-- 비어있나"를 직접 조회할 수 없다 — SECURITY DEFINER로 전역 존재 여부만 노출
-- (남의 pair_id/slug 매핑은 반환하지 않음).
create or replace function public.share_slug_available(p_slug text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.pair_shares where slug = lower(p_slug)
  );
$$;

revoke all on function public.share_slug_available(text) from public, anon;
grant execute on function public.share_slug_available(text) to authenticated;
