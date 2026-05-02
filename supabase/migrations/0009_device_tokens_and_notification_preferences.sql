-- Push tokens + per-user notification preferences.
--
-- device_tokens
--   * One row per (device, app install). A token uniquely identifies a push
--     channel; if a token migrates to a different user (re-login on the same
--     device), the prior row is deleted by the register RPC.
--   * Direct UPDATE/DELETE allowed via RLS (own tokens). Cross-user delete
--     happens only inside the SECURITY DEFINER register RPC.
--   * On profile soft-delete, all of the user's tokens are wiped — no
--     notifications should ever go to a deleted user.
--
-- notification_preferences
--   * 1:1 with profiles. A default row is auto-created via trigger when a
--     profile is inserted, so reads can rely on the row existing.
--   * Quiet hours are stored in the user's timezone (text IANA name).

-- (1) device_tokens table
create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,

  token text not null unique,
  platform text not null
    check (platform in ('ios', 'android', 'web')),

  locale text,
  app_version text,

  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index device_tokens_user_id_idx on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

create policy "device_tokens_select_own"
on public.device_tokens for select
using (auth.uid() = user_id);

create policy "device_tokens_insert_own"
on public.device_tokens for insert
with check (auth.uid() = user_id);

create policy "device_tokens_update_own"
on public.device_tokens for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "device_tokens_delete_own"
on public.device_tokens for delete
using (auth.uid() = user_id);

-- (2) register_device_token RPC: handles cross-user token transfer.
create or replace function public.register_device_token(
  p_token text,
  p_platform text,
  p_locale text default null,
  p_app_version text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  -- A token belongs to exactly one user at a time. If a different user
  -- previously registered this token (e.g., re-login on the same device),
  -- their row is removed first.
  delete from public.device_tokens
  where token = p_token and user_id <> v_user_id;

  insert into public.device_tokens (user_id, token, platform, locale, app_version)
  values (v_user_id, p_token, p_platform, p_locale, p_app_version)
  on conflict (token) do update
    set platform = excluded.platform,
        locale = coalesce(excluded.locale, public.device_tokens.locale),
        app_version = coalesce(excluded.app_version, public.device_tokens.app_version),
        last_seen_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.register_device_token(text, text, text, text) from public, anon;
grant execute on function public.register_device_token(text, text, text, text) to authenticated;

-- (3) unregister_device_token RPC
create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  delete from public.device_tokens
  where token = p_token and user_id = auth.uid();
end;
$$;

revoke all on function public.unregister_device_token(text) from public, anon;
grant execute on function public.unregister_device_token(text) to authenticated;

-- (4) notification_preferences table
create table public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,

  -- channel toggles
  partner_activity_enabled boolean not null default true,
  anniversary_reminders_enabled boolean not null default true,
  marketing_enabled boolean not null default false,

  -- quiet hours in user's timezone (NULL = always allow)
  quiet_hours_start time,
  quiet_hours_end time,
  timezone text not null default 'UTC',

  updated_at timestamptz not null default now(),

  -- both quiet hour bounds set or both null
  check ((quiet_hours_start is null) = (quiet_hours_end is null))
);

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

alter table public.notification_preferences enable row level security;

create policy "notification_preferences_select_own"
on public.notification_preferences for select
using (auth.uid() = user_id);

create policy "notification_preferences_insert_own"
on public.notification_preferences for insert
with check (auth.uid() = user_id);

create policy "notification_preferences_update_own"
on public.notification_preferences for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- (5) Auto-create default prefs row when a profile is inserted.
create or replace function public.profiles_create_default_notification_preferences()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger profiles_create_notif_prefs
after insert on public.profiles
for each row execute function public.profiles_create_default_notification_preferences();

-- Trigger-only function; not callable as an RPC.
revoke all on function public.profiles_create_default_notification_preferences()
  from public, anon, authenticated;

-- (6) On profile soft-delete: drop push tokens (no notifs to deleted users).
create or replace function public.profiles_handle_deleted_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.deleted_at is not null
     and (new.deleted_at is distinct from old.deleted_at) then
    raise exception 'profiles.deleted_at is immutable once set';
  end if;

  if old.deleted_at is null and new.deleted_at is not null then
    update public.couples
    set
      status = 'abandoned',
      ended_at = coalesce(ended_at, now()),
      ended_by = new.id
    where status = 'active'
      and (partner_a_id = new.id or partner_b_id = new.id);

    delete from public.device_tokens where user_id = new.id;
  end if;

  return new;
end;
$$;
