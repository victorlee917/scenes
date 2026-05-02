-- Subscription event log + profile fields for RevenueCat-driven billing.
--
-- Source of truth split:
--   * profiles.subscription_*  — current state cache, used by RLS / app reads.
--   * subscription_events      — raw event log of every webhook + manual
--                                 admin change. Read for audit, replay, CS.
--
-- The Edge Function (revenuecat-webhook) writes to both: appends an event
-- row, then patches profiles per the event type. Service role only — there
-- is no INSERT policy on subscription_events, and the Edge Function uses
-- the service role key to bypass RLS.

create table public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,

  -- RC event_type values: INITIAL_PURCHASE, RENEWAL, CANCELLATION,
  -- UNCANCELLATION, NON_RENEWING_PURCHASE, EXPIRATION, BILLING_ISSUE,
  -- PRODUCT_CHANGE, TRANSFER, SUBSCRIBER_ALIAS, SUBSCRIPTION_PAUSED,
  -- TEMPORARY_ENTITLEMENT_GRANT, TEST
  event_type text not null,
  source text not null
    check (source in ('revenuecat', 'manual', 'system')),

  product_id text,
  store text
    check (store is null or store in (
      'app_store', 'play_store', 'stripe',
      'promotional', 'amazon', 'mac_app_store'
    )),
  original_transaction_id text,

  -- Full webhook body for replay / debugging
  raw_payload jsonb not null,

  occurred_at timestamptz not null,
  received_at timestamptz not null default now()
);

create index subscription_events_user_id_idx on public.subscription_events(user_id);
create index subscription_events_event_type_idx on public.subscription_events(event_type);
create index subscription_events_occurred_at_idx on public.subscription_events(occurred_at desc);

alter table public.subscription_events enable row level security;

-- Users can read their own event history (e.g., billing screen).
create policy "subscription_events_select_own"
on public.subscription_events for select
using (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE policies — only service_role (Edge Function) writes.

-- profiles: who provisioned the current subscription, for support context.
alter table public.profiles
  add column subscription_provider text
    check (subscription_provider in (
      'app_store', 'play_store', 'promotional', 'manual'
    ));
