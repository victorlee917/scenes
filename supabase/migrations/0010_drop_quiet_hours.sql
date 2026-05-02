-- Drop quiet-hours fields from notification_preferences.
-- Push delivery doesn't yet honor them, so they're dead weight. Re-add later
-- alongside the actual delivery infrastructure if needed.

alter table public.notification_preferences
  drop column quiet_hours_start cascade,
  drop column quiet_hours_end cascade,
  drop column timezone;
