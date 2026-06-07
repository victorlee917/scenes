-- 예약어 slug 차단
-- 공유 URL이 scenes.id/<slug> (도메인 바로 뒤)로 바뀌면서 slug가 정적 라우트/
-- 시스템 경로와 충돌할 수 있다(예: privacy, terms). 라우트로 쓰이거나 혼동되는
-- 단어는 slug로 못 쓰게 한다.
--   * CHECK 제약: 직접 쓰기까지 하드 차단.
--   * share_slug_available: 예약어면 false 반환 → 클라 가용성 체크가 즉시 막음.

alter table public.pair_shares
  add constraint pair_shares_slug_not_reserved
  check (
    slug !~ '^(privacy|terms|s|www|api|app|admin|about|help|support|contact|login|logout|signin|signup|signout|auth|oauth|settings|account|profile|scenes|scene|home|index|static|public|assets|asset|og-image|favicon|robots|sitemap|manifest|new|edit|me|root|share|null|undefined)$'
  );

create or replace function public.share_slug_available(p_slug text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    lower(p_slug) !~ '^(privacy|terms|s|www|api|app|admin|about|help|support|contact|login|logout|signin|signup|signout|auth|oauth|settings|account|profile|scenes|scene|home|index|static|public|assets|asset|og-image|favicon|robots|sitemap|manifest|new|edit|me|root|share|null|undefined)$'
    and not exists (
      select 1 from public.pair_shares where slug = lower(p_slug)
    );
$$;
