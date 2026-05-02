-- contents.occurred_at default
--
-- Behavior:
--   * Client supplies occurred_at when known (e.g., photo EXIF DateTimeOriginal).
--   * If null on insert, the trigger fills it with created_at (upload time)
--     so every content row always has *some* timestamp.
--   * User can later UPDATE occurred_at to correct it. UPDATE to null is
--     rejected by the NOT NULL constraint.
--
-- The view scene_summary's min/max never returns null for scenes with at
-- least one content (since every row has a non-null occurred_at).

-- Extend the existing INSERT/UPDATE trigger function to default occurred_at.
create or replace function public.contents_manage_position_and_immutables()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    select coalesce(max(position), 0) + 1 into new.position
    from public.contents
    where scene_id = new.scene_id;

    -- Fall back to upload time when EXIF / explicit date is missing.
    if new.occurred_at is null then
      new.occurred_at := new.created_at;
    end if;
  elsif tg_op = 'UPDATE' then
    if new.scene_id is distinct from old.scene_id then
      raise exception 'contents.scene_id is immutable';
    end if;
    if new.type is distinct from old.type then
      raise exception 'contents.type is immutable';
    end if;
  end if;
  return new;
end;
$$;

-- Now that the trigger guarantees a value, lock the column.
alter table public.contents
  alter column occurred_at set not null;
