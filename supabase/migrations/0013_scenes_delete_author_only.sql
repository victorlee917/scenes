-- Restrict scene DELETE to the author only.
--
-- Scene deletion cascades to all contents inside (contents.scene_id has
-- on delete cascade), which is destructive across both partners' content.
-- Limit this authority to the scene's author. UPDATE remains jointly editable
-- (scene metadata is shared curation).

drop policy if exists "scenes_delete_active_pair_member" on public.scenes;

create policy "scenes_delete_author_active"
on public.scenes for delete
using (
  created_by = auth.uid()
  and exists (
    select 1 from public.couples c
    where c.pair_id = scenes.pair_id
      and c.status = 'active'
      and auth.uid() in (c.partner_a_id, c.partner_b_id)
  )
);
