-- The Instructor Availability ASAP report turned out to be unreliable at
-- the source: ASAP can't scope it to the current term, so it mixes previous
-- and current-term rows with no way to isolate one from the other. The app
-- no longer imports or displays it anywhere (Teachers tab, Daily Digest,
-- Admin → Availability Overrides all dropped it) — this removes the now-dead
-- schema. `cascade` drops each table's RLS policies and index along with it.
-- availability_overrides existed solely to curate instructor_availability
-- rows, so it goes too, and drops before the table it references.

drop function if exists replace_instructor_availability(jsonb, text);
drop table if exists availability_overrides cascade;
drop table if exists instructor_availability cascade;
