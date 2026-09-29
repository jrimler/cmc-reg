-- Richmond's Rooms I and M were renamed in ASAP:
--   (I) Room I -- RDB  →  (I) Multi-Purpose -- RDB
--   (M) Room M -- RDB  →  (M) Piano Lab -- RDB
--
-- Rooms are matched to bookings by exact raw_facility_label, so the old label
-- has to be rewritten everywhere it's stored, or the next Master Scheduler
-- upload re-seeds the new label as a fresh "needs_review" room (dropping it
-- from every physical-only view) while the old row sits orphaned:
--   * rooms — keeps its id, room_type 'physical' and display_order
--   * master_schedule_events — so the currently loaded week keeps linking
--     without waiting for a re-upload
--   * room_sign_prints — keeps the print history; the sign's room name
--     changed, so Room Signs will correctly flag both as needing a reprint
--
-- If a Master Scheduler upload already ran after the ASAP rename, it seeded
-- the new label as a needs_review row; drop that first so the rename doesn't
-- hit the (site, raw_facility_label) unique constraint.
--
-- Also sets canonical_name to keep the door letter visible. The app strips a
-- label's leading "(X) " for display, which is harmless for "(B) Room B" but
-- would leave just "Piano Lab" / "Multi-Purpose" — same fix 0006 applied to
-- the Recital Hall. Editable in Admin → Rooms.
--
-- Safe to re-run: every statement is a no-op once the old labels are gone.

delete from rooms r
where r.site = 'Richmond Branch'
  and r.raw_facility_label in ('(I) Multi-Purpose -- RDB', '(M) Piano Lab -- RDB')
  and exists (
    select 1 from rooms old
    where old.site = r.site
      and old.raw_facility_label = case r.raw_facility_label
        when '(I) Multi-Purpose -- RDB' then '(I) Room I -- RDB'
        when '(M) Piano Lab -- RDB'     then '(M) Room M -- RDB'
      end
  );

delete from room_sign_prints p
where p.site = 'Richmond Branch'
  and p.raw_facility_label in ('(I) Multi-Purpose -- RDB', '(M) Piano Lab -- RDB')
  and exists (
    select 1 from room_sign_prints old
    where old.site = p.site
      and old.raw_facility_label = case p.raw_facility_label
        when '(I) Multi-Purpose -- RDB' then '(I) Room I -- RDB'
        when '(M) Piano Lab -- RDB'     then '(M) Room M -- RDB'
      end
  );

update rooms set raw_facility_label = '(I) Multi-Purpose -- RDB'
where site = 'Richmond Branch' and raw_facility_label = '(I) Room I -- RDB';
update rooms set raw_facility_label = '(M) Piano Lab -- RDB'
where site = 'Richmond Branch' and raw_facility_label = '(M) Room M -- RDB';

update master_schedule_events set facility_raw = '(I) Multi-Purpose -- RDB'
where site = 'Richmond Branch' and facility_raw = '(I) Room I -- RDB';
update master_schedule_events set facility_raw = '(M) Piano Lab -- RDB'
where site = 'Richmond Branch' and facility_raw = '(M) Room M -- RDB';

update room_sign_prints set raw_facility_label = '(I) Multi-Purpose -- RDB'
where site = 'Richmond Branch' and raw_facility_label = '(I) Room I -- RDB';
update room_sign_prints set raw_facility_label = '(M) Piano Lab -- RDB'
where site = 'Richmond Branch' and raw_facility_label = '(M) Room M -- RDB';

update rooms set canonical_name = '(I) Multi-Purpose -- RDB'
where site = 'Richmond Branch' and raw_facility_label = '(I) Multi-Purpose -- RDB'
  and (canonical_name is null or canonical_name = '');
update rooms set canonical_name = '(M) Piano Lab -- RDB'
where site = 'Richmond Branch' and raw_facility_label = '(M) Piano Lab -- RDB'
  and (canonical_name is null or canonical_name = '');
