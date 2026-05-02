-- profiles
-- 1:1 with auth.users. Created explicitly by the app after onboarding finishes,
-- not by an auth trigger, so `name` can stay NOT NULL.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,

  name text not null
    check (char_length(name) between 1 and 12),
  avatar_url text,

  locale text not null default 'en'
    check (locale in ('en', 'ko')),

  onboarding_completed_at timestamptz,

  subscription_tier text not null default 'free'
    check (subscription_tier in ('free', 'scenes_hd')),
  subscription_status text not null default 'active'
    check (subscription_status in ('active', 'expired', 'canceled', 'trialing')),
  subscription_expires_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- updated_at auto-bump
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- RLS
alter table public.profiles enable row level security;

create policy "profiles_select_own"
on public.profiles for select
using (auth.uid() = id);

create policy "profiles_insert_own"
on public.profiles for insert
with check (auth.uid() = id);

create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- NOTE: partner read policy is added in the couples migration,
-- since it depends on the couples table existing.

-- avatars storage bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- avatar files live under `<user_id>/<filename>`
-- Public bucket: files are served via direct object URL without needing a
-- broad SELECT policy. We intentionally omit one so clients cannot list the bucket.

create policy "avatars_insert_own"
on storage.objects for insert
with check (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "avatars_update_own"
on storage.objects for update
using (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "avatars_delete_own"
on storage.objects for delete
using (
  bucket_id = 'avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);
