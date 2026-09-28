-- Richmond's Rooms G, H and N are in use as storage for the foreseeable
-- future, not teaching space. Tagged 'physical' (by 0004), they were pinned
-- as always-visible columns on Room Detail and Room Plan's 17x11 Fixed Rooms
-- print — three permanently empty columns eating width from real rooms.
--
-- A dedicated 'storage' type (rather than reusing 'offsite' or deleting the
-- rows) keeps the reason legible in Admin → Rooms and keeps the rows around,
-- so a future Master Scheduler upload still links back to them instead of
-- re-seeding them as "needs_review". When a room goes back into service,
-- flip it back to Physical in Admin → Rooms — no migration needed.
--
-- Note: re-running 0004 would reset these three to 'physical' (its ON
-- CONFLICT clause forces room_type). Re-run this file afterward if so.

alter table rooms drop constraint if exists rooms_room_type_check;
alter table rooms add constraint rooms_room_type_check
  check (room_type in ('needs_review', 'physical', 'virtual', 'home_studio', 'offsite', 'storage'));

update rooms
set room_type = 'storage'
where site = 'Richmond Branch'
  and raw_facility_label in ('(G) Room G -- RDB', '(H) Room H -- RDB', '(N) Room N -- RDB');
