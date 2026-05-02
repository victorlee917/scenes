-- scene_media private bucket
--
-- Path convention: <pair_id>/<scene_id>/<filename>
--   * The first folder (pair_id) is what RLS validates.
--   * scene_id is for organization/debugging only.
--
-- Visibility / authorship:
--   * Private bucket — files served via signed URLs, not direct URL.
--   * SELECT (signed-URL request): any pair member, status agnostic. Old
--     content stays viewable after disconnect/abandon.
--   * INSERT: only active-couple members, into their own pair's path.
--   * UPDATE / DELETE: only the file's owner (the uploader), still requires
--     active couple. Aligns with content authorship rule.
--
-- Tier-gated upload size:
--   * scenes_hd subscribers: full bucket allowance (50 MiB).
--   * free tier: capped at 5 MiB per upload (clients should downscale photos
--     before upload, e.g., to ~1920 px on the long edge).
--   The RLS check on (metadata->>'size') is the server-side guardrail; the
--   client enforces the same limit pre-upload to give a faster UX.
--
-- (avatars bucket already exists from 0001; this migration only touches
-- scene_media.)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'scene_media',
  'scene_media',
  false,
  52428800,                                                 -- 50 MiB hard cap
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do nothing;

-- SELECT: any pair member of the path's pair (status agnostic)
create policy "scene_media_select_pair_member"
on storage.objects for select
using (
  bucket_id = 'scene_media'
  and exists (
    select 1
    from public.couples c
    where c.pair_id::text = (storage.foldername(name))[1]
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- INSERT: active pair member + path matches caller's pair + tier-based size cap
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
      when (select subscription_tier from public.profiles where id = auth.uid())
           = 'scenes_hd'
      then 52428800   -- 50 MiB
      else 5242880    --  5 MiB
    end
);

-- UPDATE: only the uploader, in an active couple of the same pair
create policy "scene_media_update_owner_active"
on storage.objects for update
using (
  bucket_id = 'scene_media'
  and owner = auth.uid()
  and exists (
    select 1
    from public.couples c
    where c.pair_id::text = (storage.foldername(name))[1]
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);

-- DELETE: only the uploader, in an active couple of the same pair
create policy "scene_media_delete_owner_active"
on storage.objects for delete
using (
  bucket_id = 'scene_media'
  and owner = auth.uid()
  and exists (
    select 1
    from public.couples c
    where c.pair_id::text = (storage.foldername(name))[1]
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);
