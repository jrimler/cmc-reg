-- Room Signs: remembers what each room's door sign said the last time it was
-- printed, so the app can flag which signs actually changed after a new
-- upload instead of forcing a full reprint every week. Compared against the
-- last *print*, not the last upload — several uploads between reprints is
-- normal, and "different from what's on the door" is the question.
--
-- Stored server-side (not localStorage) so a print made from one staff
-- computer counts for everyone. One row per room, overwritten on each
-- confirmed print. Keyed by (site, raw_facility_label) rather than a rooms.id
-- FK so deleting/re-seeding a room in Admin doesn't silently lose its history.
--
-- snapshot is the sign's rendered content, not raw events:
--   { "roomName": "Room B", "notice": "...",
--     "days": { "Mo": [{ "name": "...", "span": "3:00 PM–7:00 PM" }], ... } }
-- so a notice/wording change also marks every sign as changed.

create table room_sign_prints (
  id                 bigint generated always as identity primary key,
  site               text not null,
  raw_facility_label text not null,
  snapshot           jsonb not null,
  printed_at         timestamptz not null default now(),
  printed_by         uuid references profiles(id) default auth.uid(),
  unique (site, raw_facility_label)
);

alter table room_sign_prints enable row level security;

create policy "room_sign_prints readable by any authenticated user"
  on room_sign_prints for select
  to authenticated
  using (true);

create policy "room_sign_prints writable by admins only"
  on room_sign_prints for all
  to authenticated
  using (is_admin())
  with check (is_admin());
