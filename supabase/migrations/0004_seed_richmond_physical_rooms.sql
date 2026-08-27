-- Richmond's physical, in-building rooms don't always appear in a given
-- week's Master Scheduler export — a room with nothing booked yet has no
-- row to seed from, so relying purely on upload-time seeding leaves it
-- un-taggable and permanently missing from the pinned "physical" room set.
-- This seeds the known, fixed Richmond Branch room list directly.
--
-- Safe to re-run: matches by (site, raw_facility_label), so a future
-- Master Scheduler upload that includes one of these rooms will find the
-- existing row (via the ON CONFLICT DO NOTHING in replace_master_schedule)
-- rather than creating a duplicate "needs_review" entry.

insert into rooms (site, raw_facility_label, room_type, display_order)
values
  ('Richmond Branch', '(A) Recital Hall -- RDB', 'physical', 1),
  ('Richmond Branch', '(B) Room B -- RDB',       'physical', 2),
  ('Richmond Branch', '(C) Room C -- RDB',       'physical', 3),
  ('Richmond Branch', '(D) Room D -- RDB',       'physical', 4),
  ('Richmond Branch', '(E) Room E -- RDB',       'physical', 5),
  ('Richmond Branch', '(F) Room F -- RDB',       'physical', 6),
  ('Richmond Branch', '(G) Room G -- RDB',       'physical', 7),
  ('Richmond Branch', '(H) Room H -- RDB',       'physical', 8),
  ('Richmond Branch', '(I) Room I -- RDB',       'physical', 9),
  ('Richmond Branch', '(J) Room J -- RDB',       'physical', 10),
  ('Richmond Branch', '(K) Room K -- RDB',       'physical', 11),
  ('Richmond Branch', '(L) Room L -- RDB',       'physical', 12),
  ('Richmond Branch', '(M) Room M -- RDB',       'physical', 13),
  ('Richmond Branch', '(N) Room N -- RDB',       'physical', 14)
on conflict (site, raw_facility_label)
do update set room_type = 'physical', display_order = excluded.display_order;
