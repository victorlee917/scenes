-- Content reactions (replacement for content_likes).
--
-- One reaction per user per content (PK enforces). Re-tap edits in place.
-- Comments are HD-only — enforced by BEFORE INSERT/UPDATE trigger that checks
-- pair_has_active_hd. Free pair members can still react with emoji.
--
-- Allowed emoji set is fixed (CHECK constraint) — stable cross-platform render
-- + simple analytics. Set: ❤️ 🥰 😂 😮 🔥 🥹.
--
-- Old content_likes table is left intact for now; client stops calling it.
-- Future migration can drop after data migration if needed.

create table public.content_reactions (
  user_id uuid not null references public.profiles(id) on delete cascade,
  content_id uuid not null references public.contents(id) on delete cascade,
  emoji text not null check (
    emoji in ('❤️', '🥰', '😂', '😮', '🔥', '🥹')
  ),
  comment text check (
    comment is null or char_length(comment) <= 200
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, content_id)
);

create index content_reactions_content_id_idx
  on public.content_reactions(content_id);

create trigger content_reactions_set_updated_at
before update on public.content_reactions
for each row execute function public.set_updated_at();

-- Comment HD-only check. Free pair에선 comment를 set하면 거절. 빈 문자열은
-- null로 normalize해 통과(이모지만 보낸 케이스).
create or replace function public.content_reactions_enforce_comment_tier()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pair_id uuid;
  v_is_hd boolean;
begin
  if new.comment is not null and char_length(trim(new.comment)) = 0 then
    new.comment := null;
  end if;
  if new.comment is null then
    return new;
  end if;

  select s.pair_id into v_pair_id
  from public.contents c
  join public.scenes s on s.id = c.scene_id
  where c.id = new.content_id;

  if v_pair_id is null then
    return new;
  end if;

  v_is_hd := public.pair_has_active_hd(v_pair_id::text);
  if not v_is_hd then
    raise exception 'reaction_comment_requires_hd'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

create trigger content_reactions_enforce_comment_tier_trigger
before insert or update on public.content_reactions
for each row execute function public.content_reactions_enforce_comment_tier();

-- RLS
alter table public.content_reactions enable row level security;

-- SELECT: pair member of the scene's pair (status agnostic — read after
-- disconnect 그대로).
create policy "content_reactions_select_pair_member"
on public.content_reactions for select
using (
  exists (
    select 1
    from public.contents c
    join public.scenes s on s.id = c.scene_id
    join public.couples cp on cp.pair_id = s.pair_id
    where c.id = content_reactions.content_id
      and auth.uid() in (cp.partner_a_id, cp.partner_b_id)
  )
);

-- INSERT: own row, active couple member.
create policy "content_reactions_insert_own_active"
on public.content_reactions for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.contents c
    join public.scenes s on s.id = c.scene_id
    join public.couples cp on cp.pair_id = s.pair_id
    where c.id = content_reactions.content_id
      and cp.status = 'active'
      and auth.uid() in (cp.partner_a_id, cp.partner_b_id)
  )
);

-- UPDATE: 같은 게이트.
create policy "content_reactions_update_own_active"
on public.content_reactions for update
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.contents c
    join public.scenes s on s.id = c.scene_id
    join public.couples cp on cp.pair_id = s.pair_id
    where c.id = content_reactions.content_id
      and cp.status = 'active'
      and auth.uid() in (cp.partner_a_id, cp.partner_b_id)
  )
)
with check (
  user_id = auth.uid()
);

-- DELETE: own row.
create policy "content_reactions_delete_own"
on public.content_reactions for delete
using (user_id = auth.uid());
