-- Scene media bucket size cap tightening
--
-- After client-side WebP q80 + 1920px cap is in place, real photo uploads
-- are <500KB. The previous tier-differentiated 5 MiB free / 50 MiB HD cap
-- is dead weight (never exercised) and primarily serves as defense against
-- malicious / pathological uploads. Tighten to a single 2 MiB ceiling
-- across all tiers — still 4× the typical real upload, leaves headroom for
-- edge cases (very large source HEIC compressed at higher quality), and
-- closes the door on accidental 50 MiB uploads.
--
-- Existing larger objects already in storage are unaffected.

drop policy if exists "scene_media_insert_active_pair_tier_limited"
  on storage.objects;

create policy "scene_media_insert_active_pair"
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
  and (metadata->>'size')::bigint <= 2097152  -- 2 MiB
);
