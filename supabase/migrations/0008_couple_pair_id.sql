-- Stable pair identity across re-pairings.
--
-- Two people who pair, disconnect, and pair again share the same pair_id
-- across all their couples rows. Content tables (scenes, etc.) reference
-- pair_id rather than couple_id so re-pairing reunites the timeline.
--
-- Constraints:
--   * pair_id is immutable once set on a row.
--   * For any canonical (partner_a_id, partner_b_id) pair, every couples row
--     for that pair shares the same pair_id (enforced by trigger).
--   * The redeem RPC computes pair_id by looking up any prior row for the
--     same partner pair; falls back to a fresh uuid for first-time pairs.

-- (1) pair_id column
alter table public.couples
  add column pair_id uuid not null default gen_random_uuid();

create index couples_pair_id_idx on public.couples(pair_id);

-- (2) Stability trigger
create or replace function public.couples_enforce_stable_pair_id()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_existing_pair_id uuid;
begin
  if tg_op = 'UPDATE' and new.pair_id is distinct from old.pair_id then
    raise exception 'couples.pair_id is immutable';
  end if;

  if tg_op = 'INSERT'
     and new.partner_a_id is not null
     and new.partner_b_id is not null then
    select pair_id into v_existing_pair_id
    from public.couples
    where partner_a_id = new.partner_a_id
      and partner_b_id = new.partner_b_id
    limit 1;

    if v_existing_pair_id is not null
       and v_existing_pair_id <> new.pair_id then
      raise exception
        'pair_id must match the existing pair_id for this partner pair';
    end if;
  end if;

  return new;
end;
$$;

create trigger couples_pair_id_stability
before insert or update on public.couples
for each row execute function public.couples_enforce_stable_pair_id();

-- (3) redeem_couple_invite: reuse prior pair_id, generate new for first-time pairs.
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
  v_pair_id      uuid;
  v_a            uuid;
  v_b            uuid;
begin
  if v_redeemer_id is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_redeemer_id and deleted_at is null
  ) then
    raise exception 'redeemer has no active profile' using errcode = 'P0001';
  end if;

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

  if not exists (
    select 1 from public.profiles
    where id = v_invite.inviter_id and deleted_at is null
  ) then
    raise exception 'inviter no longer available' using errcode = 'P0001';
  end if;

  if v_invite.inviter_id < v_redeemer_id then
    v_a := v_invite.inviter_id;
    v_b := v_redeemer_id;
  else
    v_a := v_redeemer_id;
    v_b := v_invite.inviter_id;
  end if;

  -- Reuse pair_id if this pair has any prior row; otherwise mint a new one.
  select pair_id into v_pair_id
  from public.couples
  where partner_a_id = v_a and partner_b_id = v_b
  limit 1;

  if v_pair_id is null then
    v_pair_id := gen_random_uuid();
  end if;

  insert into public.couples (partner_a_id, partner_b_id, pair_id)
  values (v_a, v_b, v_pair_id)
  returning id into v_couple_id;

  update public.couple_invites
  set redeemed_at = now(),
      redeemed_by = v_redeemer_id,
      couple_id = v_couple_id
  where id = v_invite.id;

  return v_couple_id;
end;
$$;
