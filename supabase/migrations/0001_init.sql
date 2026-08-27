-- SFCMC Reg Tool v2 — initial schema
-- Run this once in the Supabase SQL editor for a fresh project.
--
-- After running, promote your own account to admin (viewers are the default
-- for every new signup):
--   update profiles set role = 'admin' where id =
--     (select id from auth.users where email = 'you@example.com');

-- ── PROFILES ────────────────────────────────────────────────────────────────
-- One row per auth user. Role drives every RLS policy below.

create table profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role         text not null default 'viewer' check (role in ('admin', 'viewer')),
  created_at   timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profiles are readable by any authenticated user"
  on profiles for select
  to authenticated
  using (true);

create policy "users can update their own display_name"
  on profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from profiles where id = auth.uid()));

-- Auto-create a profile (default role: viewer) whenever a new auth user signs up.
create function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', new.email));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Small helper so policies read cleanly.
create function is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  );
$$;

-- ── REPORT UPLOADS (audit log) ──────────────────────────────────────────────

create table report_uploads (
  id           bigint generated always as identity primary key,
  report_type  text not null check (report_type in
                 ('open_slots', 'master_schedule', 'instructor_availability')),
  uploaded_by  uuid references profiles(id),
  uploaded_at  timestamptz not null default now(),
  filename     text,
  row_count    int not null default 0
);

alter table report_uploads enable row level security;

create policy "report_uploads readable by any authenticated user"
  on report_uploads for select
  to authenticated
  using (true);

create policy "report_uploads insertable by admins only"
  on report_uploads for insert
  to authenticated
  with check (is_admin());

create policy "report_uploads updatable by admins only"
  on report_uploads for update
  to authenticated
  using (is_admin())
  with check (is_admin());

-- ── OPEN SLOTS (from OpenSlotsReport) ───────────────────────────────────────
-- Wiped and reloaded wholesale on every upload of this report type.

create table open_slots (
  id              bigint generated always as identity primary key,
  upload_id       bigint references report_uploads(id) on delete cascade,
  department      text,
  instrument      text,
  instructor_name text not null,
  day             text not null,          -- short code: Mo/Tu/We/Th/Fr/Sa/Su
  start_time      time not null,
  end_time        time not null,
  duration_mins   int not null,
  lesson_date     date,
  term            text
);

create index open_slots_instructor_idx on open_slots (instructor_name);
create index open_slots_day_idx on open_slots (day);

alter table open_slots enable row level security;

create policy "open_slots readable by any authenticated user"
  on open_slots for select
  to authenticated
  using (true);

create policy "open_slots writable by admins only"
  on open_slots for all
  to authenticated
  using (is_admin())
  with check (is_admin());

-- ── MASTER SCHEDULE EVENTS (from MasterScheduler) ───────────────────────────

create table master_schedule_events (
  id              bigint generated always as identity primary key,
  upload_id       bigint references report_uploads(id) on delete cascade,
  event_date      date,
  item            text,
  from_time       time not null,
  to_time         time not null,
  day             text not null,          -- short code: Mo/Tu/We/Th/Fr/Sa/Su
  duration_mins   int,
  facility_raw    text not null,          -- exact "Facility" label from the report
  site            text not null,          -- "Richmond Branch" / "Mission Branch"
  instructor_name text not null,          -- normalized "First Last"
  student         text,
  type            text not null default 'LESSON',  -- LESSON | CLASS
  start_date      date,
  end_date        date
);

create index msevents_instructor_day_idx on master_schedule_events (instructor_name, day);
create index msevents_facility_idx on master_schedule_events (site, facility_raw);

alter table master_schedule_events enable row level security;

create policy "master_schedule_events readable by any authenticated user"
  on master_schedule_events for select
  to authenticated
  using (true);

create policy "master_schedule_events writable by admins only"
  on master_schedule_events for all
  to authenticated
  using (is_admin())
  with check (is_admin());

-- ── INSTRUCTOR AVAILABILITY (from Instructor Availability report) ──────────
-- Only "Is Available = Yes" rows are imported — "No" rows carry stale times
-- and are dropped at parse time, not stored here.

create table instructor_availability (
  id         bigint generated always as identity primary key,
  upload_id  bigint references report_uploads(id) on delete cascade,
  first_name text not null,
  last_name  text not null,
  day        text not null,               -- short code: Mo/Tu/We/Th/Fr/Sa/Su
  start_time time not null,
  end_time   time not null
);

create index instr_avail_name_day_idx on instructor_availability (last_name, first_name, day);

alter table instructor_availability enable row level security;

create policy "instructor_availability readable by any authenticated user"
  on instructor_availability for select
  to authenticated
  using (true);

create policy "instructor_availability writable by admins only"
  on instructor_availability for all
  to authenticated
  using (is_admin())
  with check (is_admin());

-- ── ROOMS (curated registry, seeded from Master Scheduler facility labels) ──

create table rooms (
  id                bigint generated always as identity primary key,
  site              text not null,
  raw_facility_label text not null,       -- exact label as it appears in the report
  canonical_name    text,                 -- admin-editable display name; falls back to raw label
  room_type         text not null default 'needs_review'
                      check (room_type in ('needs_review', 'physical', 'virtual', 'home_studio', 'offsite')),
  display_order     int,
  created_at        timestamptz not null default now(),
  unique (site, raw_facility_label)
);

alter table rooms enable row level security;

create policy "rooms readable by any authenticated user"
  on rooms for select
  to authenticated
  using (true);

create policy "rooms writable by admins only"
  on rooms for all
  to authenticated
  using (is_admin())
  with check (is_admin());

-- ── AVAILABILITY OVERRIDES (persistent, survives every re-upload) ──────────
-- Admin-curated suppression list for stale/default availability rows
-- (e.g. an unedited generic 9am-5pm block). Matched by name+day at query
-- time against instructor_availability — never touched by the replace-on-
-- upload functions below.

create table availability_overrides (
  id         bigint generated always as identity primary key,
  first_name text not null,
  last_name  text not null,
  day        text not null,
  action     text not null default 'ignore' check (action in ('ignore')),
  note       text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  unique (first_name, last_name, day)
);

alter table availability_overrides enable row level security;

create policy "availability_overrides readable by any authenticated user"
  on availability_overrides for select
  to authenticated
  using (true);

create policy "availability_overrides writable by admins only"
  on availability_overrides for all
  to authenticated
  using (is_admin())
  with check (is_admin());

-- ── REPLACE-ON-UPLOAD FUNCTIONS ──────────────────────────────────────────────
-- Each takes the parsed rows as a jsonb array (client parses the report file
-- and maps columns by name before calling this) plus the original filename.
-- Runs as the calling user (not security definer) so the RLS admin-only
-- policies above apply naturally; the explicit is_admin() check just gives a
-- clearer error message than a raw RLS violation would.

create function replace_open_slots(rows jsonb, p_filename text)
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

create function replace_master_schedule(rows jsonb, p_filename text)
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

  -- Seed any newly-seen rooms as needs_review. Never removes rooms that
  -- disappear from this upload — an admin cleans those up deliberately.
  insert into rooms (site, raw_facility_label)
  select distinct site, facility_raw
  from master_schedule_events
  where upload_id = v_upload_id
  on conflict (site, raw_facility_label) do nothing;

  return v_upload_id;
end;
$$;

create function replace_instructor_availability(rows jsonb, p_filename text)
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
