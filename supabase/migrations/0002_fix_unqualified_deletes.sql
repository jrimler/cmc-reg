-- Fix: Supabase enforces pg-safeupdate, which rejects any DELETE/UPDATE
-- without a WHERE clause — including the intentional full-table wipes in
-- the replace-on-upload functions below. Adding `where true` keeps the
-- same behavior (delete every row) while satisfying that check.
--
-- Safe to run against an existing project that already has 0001_init.sql
-- applied — this only redefines the three functions, no data is touched.

create or replace function replace_open_slots(rows jsonb, p_filename text)
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

  insert into report_uploads (report_type, uploaded_by, filename)
  values ('open_slots', auth.uid(), p_filename)
  returning id into v_upload_id;

  delete from open_slots where true;

  insert into open_slots
    (upload_id, department, instrument, instructor_name, day, start_time, end_time, duration_mins, lesson_date, term)
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
    r ->> 'term'
  from jsonb_array_elements(rows) as r;

  get diagnostics v_count = row_count;
  update report_uploads set row_count = v_count where id = v_upload_id;

  return v_upload_id;
end;
$$;

create or replace function replace_master_schedule(rows jsonb, p_filename text)
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

  insert into report_uploads (report_type, uploaded_by, filename)
  values ('master_schedule', auth.uid(), p_filename)
  returning id into v_upload_id;

  delete from master_schedule_events where true;

  insert into master_schedule_events
    (upload_id, event_date, item, from_time, to_time, day, duration_mins,
     facility_raw, site, instructor_name, student, type, start_date, end_date)
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
    nullif(r ->> 'end_date', '')::date
  from jsonb_array_elements(rows) as r;

  get diagnostics v_count = row_count;
  update report_uploads set row_count = v_count where id = v_upload_id;

  insert into rooms (site, raw_facility_label)
  select distinct site, facility_raw
  from master_schedule_events
  where upload_id = v_upload_id
  on conflict (site, raw_facility_label) do nothing;

  return v_upload_id;
end;
$$;

create or replace function replace_instructor_availability(rows jsonb, p_filename text)
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

  insert into report_uploads (report_type, uploaded_by, filename)
  values ('instructor_availability', auth.uid(), p_filename)
  returning id into v_upload_id;

  delete from instructor_availability where true;

  insert into instructor_availability (upload_id, first_name, last_name, day, start_time, end_time)
  select
    v_upload_id,
    r ->> 'first_name',
    r ->> 'last_name',
    r ->> 'day',
    (r ->> 'start_time')::time,
    (r ->> 'end_time')::time
  from jsonb_array_elements(rows) as r;

  get diagnostics v_count = row_count;
  update report_uploads set row_count = v_count where id = v_upload_id;

  return v_upload_id;
end;
$$;
