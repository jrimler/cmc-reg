-- Quarter crossover: keep two datasets side by side instead of one.
--
--   scope = 'current'  the quarter in session (a rolling week from today)
--   scope = 'next'     the upcoming quarter (one typical week, e.g. Mar 15–21)
--
-- A scope is a *role*, not a quarter name, so the crossover needs no
-- migration step: when Winter starts, the "current" uploads simply start
-- landing in Winter and "next" is pointed at Spring's typical week.
--
-- Every existing row becomes 'current' (the column default), which is what it
-- was. Open Slots is only ever uploaded for 'next' going forward — it's the
-- registration tool — so the app ignores any 'current' open_slots rows left
-- over from before; they're not deleted here.
--
-- The replace-on-upload functions now only wipe the scope they're loading,
-- so uploading Winter's week can't disturb Fall's. p_scope defaults to
-- 'current' so a browser tab still running the previous version of the app
-- (which sends no p_scope) keeps working until it's reloaded. The old
-- 2-argument functions are dropped first: leaving them beside the new
-- 3-argument ones would make a 2-argument call ambiguous.
--
-- Safe to re-run.

alter table report_uploads
  add column if not exists scope text not null default 'current'
    check (scope in ('current', 'next'));

alter table open_slots
  add column if not exists scope text not null default 'current'
    check (scope in ('current', 'next'));

alter table master_schedule_events
  add column if not exists scope text not null default 'current'
    check (scope in ('current', 'next'));

drop function if exists replace_open_slots(jsonb, text);
drop function if exists replace_master_schedule(jsonb, text);

create or replace function replace_open_slots(rows jsonb, p_filename text, p_scope text default 'current')
returns bigint
language plpgsql
as $$
declare
  v_upload_id bigint;
  v_count     int;
begin
  if not is_admin() then
    raise exception 'only admins can upload reports';
  end if;
  if p_scope not in ('current', 'next') then
    raise exception 'unknown scope %', p_scope;
  end if;

  insert into report_uploads (report_type, uploaded_by, filename, scope)
  values ('open_slots', auth.uid(), p_filename, p_scope)
  returning id into v_upload_id;

  delete from open_slots where scope = p_scope;

  insert into open_slots
    (upload_id, department, instrument, instructor_name, day, start_time, end_time, duration_mins, lesson_date, term, scope)
  select
    v_upload_id,
    r ->> 'department',
    r ->> 'instrument',
    r ->> 'instructor_name',
    r ->> 'day',
    (r ->> 'start_time')::time,
    (r ->> 'end_time')::time,
    (r ->> 'duration_mins')::int,
    nullif(r ->> 'lesson_date', '')::date,
    r ->> 'term',
    p_scope
  from jsonb_array_elements(rows) as r;

  get diagnostics v_count = row_count;
  update report_uploads set row_count = v_count where id = v_upload_id;

  return v_upload_id;
end;
$$;

create or replace function replace_master_schedule(rows jsonb, p_filename text, p_scope text default 'current')
returns bigint
language plpgsql
as $$
declare
  v_upload_id bigint;
  v_count     int;
begin
  if not is_admin() then
    raise exception 'only admins can upload reports';
  end if;
  if p_scope not in ('current', 'next') then
    raise exception 'unknown scope %', p_scope;
  end if;

  insert into report_uploads (report_type, uploaded_by, filename, scope)
  values ('master_schedule', auth.uid(), p_filename, p_scope)
  returning id into v_upload_id;

  delete from master_schedule_events where scope = p_scope;

  insert into master_schedule_events
    (upload_id, event_date, item, from_time, to_time, day, duration_mins,
     facility_raw, site, instructor_name, student, type, start_date, end_date, scope)
  select
    v_upload_id,
    nullif(r ->> 'event_date', '')::date,
    r ->> 'item',
    (r ->> 'from_time')::time,
    (r ->> 'to_time')::time,
    r ->> 'day',
    (r ->> 'duration_mins')::int,
    r ->> 'facility_raw',
    r ->> 'site',
    r ->> 'instructor_name',
    r ->> 'student',
    coalesce(r ->> 'type', 'LESSON'),
    nullif(r ->> 'start_date', '')::date,
    nullif(r ->> 'end_date', '')::date,
    p_scope
  from jsonb_array_elements(rows) as r;

  get diagnostics v_count = row_count;
  update report_uploads set row_count = v_count where id = v_upload_id;

  -- Seed any newly-seen rooms as needs_review (either scope: next quarter may
  -- bring a room the current one doesn't have). Never removes rooms that
  -- disappear from an upload — an admin cleans those up deliberately.
  insert into rooms (site, raw_facility_label)
  select distinct site, facility_raw
  from master_schedule_events
  where upload_id = v_upload_id
  on conflict (site, raw_facility_label) do nothing;

  return v_upload_id;
end;
$$;
