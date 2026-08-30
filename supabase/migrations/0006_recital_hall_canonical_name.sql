-- Every other Richmond room keeps its letter visible after the app's
-- display fallback strips the raw label's leading "(X) " prefix, because
-- the letter is also baked into the room name itself ("Room B" from
-- "(B) Room B -- RDB", "Room C" from "(C) Room C -- RDB", etc.). The
-- Recital Hall has no such luck: stripping "(A) " from
-- "(A) Recital Hall -- RDB" leaves "Recital Hall -- RDB" — the "A" is
-- gone, so it can't be identified or sorted by letter anywhere the app
-- shows a bare room name (Daily Digest's room tags, Room Schedule's
-- column header).
--
-- Fixed via canonical_name (an explicit override the app already checks
-- before falling back to the stripped raw label), not raw_facility_label —
-- that has to keep matching the ASAP export exactly, or a future Master
-- Scheduler upload won't link back to this room and it reverts to
-- "needs_review". A leading "(A)" also sorts correctly ahead of "Room B",
-- "Room C", etc., since "(" precedes any letter.

update rooms
set canonical_name = '(A) Recital -- RDB'
where site = 'Richmond Branch' and raw_facility_label = '(A) Recital Hall -- RDB';
