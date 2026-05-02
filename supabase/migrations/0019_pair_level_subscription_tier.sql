-- Pair-level subscription tier
--
-- Rule: a pair gets HD-tier benefits if at least one of its current active
-- partners has a fully-valid scenes_hd subscription. 0018 incorrectly checked
-- only the caller's own tier; this migration replaces that with a function
-- that walks the pair.
--
-- "Fully valid" means:
--   * partner is in an active couple for this pair_id
--   * partner's profile is not soft-deleted
--   * subscription_tier = 'scenes_hd'
--   * subscription_status = 'active'
--   * expires_at is null OR > now()  (defense against stale rows)
--
-- Function takes text (folder name from storage path) and casts safely so a
-- malformed path returns false rather than raising.

create or replace function public.pair_has_active_hd(p_pair_id_text text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pair_id uuid;
begin
  begin
    v_pair_id := p_pair_id_text::uuid;
  exception when invalid_text_representation then
    return false;
  end;

  return exists (
    select 1
    from public.couples c
    join public.profiles p
      on p.id in (c.partner_a_id, c.partner_b_id)
    where c.pair_id = v_pair_id
      and c.status = 'active'
      and p.deleted_at is null
      and p.subscription_tier = 'scenes_hd'
      and p.subscription_status = 'active'
      and (p.subscription_expires_at is null
           or p.subscription_expires_at > now())
  );
end;
$$;

revoke all on function public.pair_has_active_hd(text) from public, anon;
grant execute on function public.pair_has_active_hd(text) to authenticated;

-- Replace the scene_media INSERT policy: pair-level instead of caller-level
drop policy if exists "scene_media_insert_active_pair_tier_limited"
  on storage.objects;

create policy "scene_media_insert_active_pair_tier_limited"
on storage.objects for insert
with check (
  bucket_id = 'scene_media'
  and exists (
    select 1
    from public.couples c
    where c.pair_id::text = (storage.foldername(name))[1]
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
  and (metadata->>'size')::bigint <=
    case
      when public.pair_has_active_hd((storage.foldername(name))[1])
      then 52428800   -- 50 MiB (HD pair)
      else 5242880    --  5 MiB (free pair)
    end
);
