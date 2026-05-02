-- disconnect_couple() -> uuid (the disconnected couple_id)
--
-- SECURITY DEFINER RPC that ends the caller's active couple in a single,
-- explicit action: status='ended', ended_at=now(), ended_by=caller.
--
-- After this, the row is read-only: the couples_update_active_member RLS
-- policy's USING clause checks status='active', so subsequent updates fail.
-- Re-pairing later creates a *new* couples row (option A from design).

create or replace function public.disconnect_couple()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id   uuid := auth.uid();
  v_couple_id uuid;
begin
  if v_user_id is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  -- The single-active-per-user invariant guarantees at most one match.
  select id into v_couple_id
  from public.couples
  where status = 'active'
    and (partner_a_id = v_user_id or partner_b_id = v_user_id)
  for update;

  if not found then
    raise exception 'no active couple to disconnect' using errcode = 'P0001';
  end if;

  update public.couples
  set status   = 'ended',
      ended_at = now(),
      ended_by = v_user_id
  where id = v_couple_id;

  return v_couple_id;
end;
$$;

revoke all on function public.disconnect_couple() from public, anon;
grant execute on function public.disconnect_couple() to authenticated;
