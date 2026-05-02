-- Periodically delete dead couple_invites rows.
--
-- Cleanup policy:
--   * unredeemed + expired more than 7 days ago  → delete
--   * redeemed more than 90 days ago             → delete (audit retention)
--
-- pg_cron runs daily at 03:00 UTC. The function is SECURITY DEFINER so it
-- bypasses RLS, but execute is revoked from non-superusers — only the cron
-- scheduler invokes it.

create extension if not exists pg_cron;

create or replace function public.cleanup_expired_couple_invites()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  with deleted as (
    delete from public.couple_invites
    where (expires_at <= now() - interval '7 days' and redeemed_at is null)
       or (redeemed_at is not null and redeemed_at <= now() - interval '90 days')
    returning 1
  )
  select count(*) into v_deleted from deleted;

  return v_deleted;
end;
$$;

revoke all on function public.cleanup_expired_couple_invites() from public, anon, authenticated;

select cron.schedule(
  'cleanup_expired_couple_invites',
  '0 3 * * *',
  $$select public.cleanup_expired_couple_invites();$$
);
