-- Richmond's Rooms G, H and N have been deleted from ASAP outright (they
-- were storage — see 0007), so they'll never appear in a Master Scheduler
-- export again and there's nothing left to link back to. Remove their
-- registry rows rather than leaving them tagged 'storage' forever.
--
-- Also clears any Room Signs print snapshot for them (0008), so they can't
-- surface as a "Take down" entry. Nothing else references rooms by id.
--
-- Runs after 0004 on a fresh setup, so it also undoes 0004's seeding of
-- these three. The 'storage' room type from 0007 stays available.

delete from rooms
where site = 'Richmond Branch'
  and raw_facility_label in ('(G) Room G -- RDB', '(H) Room H -- RDB', '(N) Room N -- RDB');

delete from room_sign_prints
where site = 'Richmond Branch'
  and raw_facility_label in ('(G) Room G -- RDB', '(H) Room H -- RDB', '(N) Room N -- RDB');
