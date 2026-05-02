-- redeem_couple_invite(invite_code text) -> uuid (couple_id)
--
-- SECURITY DEFINER RPC that takes a one-shot invite code and atomically:
--   1) validates the invite (exists, not expired, not redeemed, not self)
--   2) checks both parties are eligible (have a profile, not soft-deleted)
--   3) inserts a couples row with normalized partner ordering
--   4) marks the invite as redeemed and links it to the new couple
--
-- The 0003 single-active-per-user trigger fires on the insert and rejects
-- the call if either party is already in another active couple — that error
-- propagates back to the client unchanged.
--
-- Direct UPDATE on couple_invites has no RLS policy; redemption *must* go
-- through this RPC so anon clients can't scan codes via the SELECT policy.

create or replace function public.redeem_couple_invite(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite       public.couple_invites%rowtype;
  v_redeemer_id  uuid := auth.uid();
  v_couple_id    uuid;
  v_a            uuid;
  v_b            uuid;
begin
  if v_redeemer_id is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  -- redeemer must have a non-deleted profile
  if not exists (
    select 1 from public.profiles
    where id = v_redeemer_id and deleted_at is null
  ) then
    raise exception 'redeemer has no active profile' using errcode = 'P0001';
  end if;

  -- lock the invite row so concurrent redeem attempts serialize
  select * into v_invite
  from public.couple_invites
  where code = invite_code
  for update;

  if not found then
    raise exception 'invalid invite code' using errcode = 'P0001';
  end if;
  if v_invite.redeemed_at is not null then
    raise exception 'invite already redeemed' using errcode = 'P0001';
  end if;
  if v_invite.expires_at <= now() then
    raise exception 'invite expired' using errcode = 'P0001';
  end if;
  if v_invite.inviter_id = v_redeemer_id then
    raise exception 'cannot redeem own invite' using errcode = 'P0001';
  end if;

  -- inviter must still have a non-deleted profile
  if not exists (
    select 1 from public.profiles
    where id = v_invite.inviter_id and deleted_at is null
  ) then
    raise exception 'inviter no longer available' using errcode = 'P0001';
  end if;

  -- canonicalize partner ordering (partner_a_id < partner_b_id)
  if v_invite.inviter_id < v_redeemer_id then
    v_a := v_invite.inviter_id;
    v_b := v_redeemer_id;
  else
    v_a := v_redeemer_id;
    v_b := v_invite.inviter_id;
  end if;

  -- couples_enforce_single_active_per_user fires here and raises 23505
  -- if either party is already in another active couple.
  insert into public.couples (partner_a_id, partner_b_id)
  values (v_a, v_b)
  returning id into v_couple_id;

  update public.couple_invites
  set redeemed_at = now(),
      redeemed_by = v_redeemer_id,
      couple_id = v_couple_id
  where id = v_invite.id;

  return v_couple_id;
end;
$$;

-- Callable only by authenticated users.
revoke all on function public.redeem_couple_invite(text) from public, anon;
grant execute on function public.redeem_couple_invite(text) to authenticated;
