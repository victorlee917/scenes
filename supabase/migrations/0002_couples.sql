-- couples
-- Two profiles linked together. Re-pairing the same two profiles after an
-- 'ended' state creates a NEW row; old rows stay as history.
--
-- Design rule for all couple-scoped tables: only `status = 'active'` couples
-- can accept new writes / updates. 'ended' couples are read-only.

create table public.couples (
  id uuid primary key default gen_random_uuid(),

  partner_a_id uuid not null references public.profiles(id) on delete cascade,
  partner_b_id uuid not null references public.profiles(id) on delete cascade,

  linked_at timestamptz not null default now(),
  since_date date not null default current_date,

  status text not null default 'active'
    check (status in ('active', 'ended')),

  ended_at timestamptz,
  ended_by uuid references public.profiles(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- canonicalize pair ordering so (A,B) and (B,A) can't both exist
  check (partner_a_id < partner_b_id),
  -- ended <=> ended_at present
  check ((status = 'ended') = (ended_at is not null)),
  -- ended_by only meaningful when ended
  check (ended_by is null or status = 'ended')
);

-- one active couple per pair
create unique index couples_active_pair_unique
  on public.couples (partner_a_id, partner_b_id)
  where status = 'active';

-- one active couple per user (each side indexed separately)
create unique index couples_active_partner_a_unique
  on public.couples (partner_a_id)
  where status = 'active';
create unique index couples_active_partner_b_unique
  on public.couples (partner_b_id)
  where status = 'active';

create trigger couples_set_updated_at
before update on public.couples
for each row execute function public.set_updated_at();

-- RLS
alter table public.couples enable row level security;

create policy "couples_select_member"
on public.couples for select
using (auth.uid() in (partner_a_id, partner_b_id));

create policy "couples_insert_member"
on public.couples for insert
with check (auth.uid() in (partner_a_id, partner_b_id));

-- Only active couples are mutable. Flipping status to 'ended' is allowed
-- because USING checks the OLD row; once ended, all further updates fail.
create policy "couples_update_active_member"
on public.couples for update
using (
  auth.uid() in (partner_a_id, partner_b_id)
  and status = 'active'
)
with check (
  auth.uid() in (partner_a_id, partner_b_id)
);

-- Deferred from 0001: a profile is readable by their active partner.
create policy "profiles_select_partner"
on public.profiles for select
using (
  exists (
    select 1
    from public.couples c
    where c.status = 'active'
      and (
        (c.partner_a_id = auth.uid() and c.partner_b_id = profiles.id)
        or (c.partner_b_id = auth.uid() and c.partner_a_id = profiles.id)
      )
  )
);

-- couple_invites
-- One-shot invite codes. 24h TTL by default. Redemption marks the row and
-- links it to the created couple. Direct UPDATE is not exposed via RLS;
-- redemption should go through a SECURITY DEFINER RPC (added separately)
-- so anon clients cannot scan codes.

create table public.couple_invites (
  id uuid primary key default gen_random_uuid(),
  code text not null unique
    check (char_length(code) between 6 and 12),

  inviter_id uuid not null references public.profiles(id) on delete cascade,

  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),

  redeemed_at timestamptz,
  redeemed_by uuid references public.profiles(id) on delete set null,
  couple_id uuid references public.couples(id) on delete set null,

  -- redemption fields are all-or-nothing
  check ((redeemed_at is null) = (redeemed_by is null)),
  check ((redeemed_at is null) = (couple_id is null)),
  -- can't redeem your own invite
  check (inviter_id <> redeemed_by)
);

create index couple_invites_inviter_id_idx on public.couple_invites(inviter_id);

alter table public.couple_invites enable row level security;

-- Inviter sees their own invites.
create policy "couple_invites_select_inviter"
on public.couple_invites for select
using (auth.uid() = inviter_id);

-- Redeemer sees the invite they redeemed.
create policy "couple_invites_select_redeemer"
on public.couple_invites for select
using (auth.uid() = redeemed_by);

-- Inserting an invite: only as yourself, and only as a fresh (un-redeemed) row.
create policy "couple_invites_insert_inviter"
on public.couple_invites for insert
with check (
  auth.uid() = inviter_id
  and redeemed_at is null
  and redeemed_by is null
  and couple_id is null
);

-- No UPDATE / DELETE policy: redemption goes through a SECURITY DEFINER RPC.
