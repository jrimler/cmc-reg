# SFCMC Reg Tool (v2)

Internal registrar tool for the San Francisco Community Music Center. A single-page web app combining two workflows: finding open lesson slots for student enrollment, and visualizing studio room usage by branch and day.

**Staff use only — not public-facing.**

---

## What it does

### Lesson Finder
Filters open lesson slots by instrument, day, lesson length, instructor, and branch. Each result row shows a best-guess room (derived from the instructor's booked schedule that day — see "Room-linking" below). Rows can be multi-selected and copied as plain text for enrollment emails.

### Teachers (tab within Lesson Finder)
Per-instructor roster — instruments taught, branches, and weekly availability — computed entirely from the latest uploaded reports. No manually-maintained fields (age minimums, notes) exist in this version.

### Room Schedule
Visualizes booked studio time by site and day, driven by the Master Scheduler report. Room columns come from the curated `rooms` registry. Includes a standard letter-size print and an 11×17 (tabloid) print scoped to Richmond's physical rooms only.

### Admin (admin role only)
- **Upload Reports**: upload the three ASAP exports (Open Slots, Master Scheduler, Instructor Availability). Each upload fully replaces the current data for that report type.
- **Rooms**: every room seen in a Master Scheduler upload, taggable as physical / virtual / home studio / offsite / needs review. Untagged and non-physical rooms are excluded from the 11×17 print. Tags persist across future uploads.
- **Availability Overrides**: mark specific instructor/day availability rows to ignore (e.g. an unedited generic 9–5 block from ASAP). Persists across future uploads.

---

## Data sources

Three ASAP report exports, uploaded through the Admin screen. They arrive as HTML tables saved with an `.xls`/`.xlsx` extension (an ASAP/RadGrid export quirk) — the app sniffs the file type and parses either a real XLSX or an HTML table. Columns are matched by name, not position.

| Report | Columns | Feeds |
|---|---|---|
| Open Slots Report | `Department, Subject, Instructor, Day, Time, Duration, Date, TimePeriod` | Lesson Finder |
| Master Scheduler Report | `Date, Item, From, To, Day, Duration, Facility, Site, Instructor, PL Student, Type, Start Date, End Date` | Room Schedule, room registry, room-linking |
| Instructor Availability | `Employee ID, Employee Type, First Name, Last Name, Day of Week, Is Available, Start Time, End Time, Break 1/2 Start/End, Exception Date, Exception Note` | Teachers tab |

---

## Tech stack

- Vanilla JavaScript, single HTML file — no build step.
- [Supabase](https://supabase.com) (Postgres + Auth) as the backend — see `supabase/migrations/0001_init.sql` for the full schema, RLS policies, and replace-on-upload functions.
- XLSX.js (CDN) for real `.xlsx` parsing; native `DOMParser` for the HTML-table export format.
- Hosted on Netlify (`netlify.toml` included), deployed from this GitHub repo.
- Google Fonts: DM Serif Display, DM Mono, DM Sans.

---

## First-time setup

1. Create a Supabase project.
2. In its SQL editor, run `supabase/migrations/0001_init.sql`.
3. Sign up through the app's login screen (first account defaults to `viewer` role), then in the Supabase SQL editor promote yourself:
   ```sql
   update profiles set role = 'admin' where id =
     (select id from auth.users where email = 'you@example.com');
   ```
4. Reload the app, sign in — the Admin tab should now be visible.
5. On first load, the app asks for your Supabase project URL and anon public key (Project Settings → API in the Supabase dashboard). These are saved in `localStorage`.
6. Upload the three ASAP reports from the Admin → Upload Reports screen.

## Running locally

```
npm start
```

Serves `index.html` at `http://localhost:3000` via `npx serve`.

---

## Architecture

### Auth & roles
Supabase Auth (email/password). A `profiles` row (role: `admin` | `viewer`) is auto-created on signup via a Postgres trigger, defaulting to `viewer`. RLS policies: viewers can read all data tables; only admins can write to report data, `rooms`, and `availability_overrides`.

### Upload flow
Admin picks a file → client parses and column-maps it in-browser → a Postgres RPC function (`replace_open_slots` / `replace_master_schedule` / `replace_instructor_availability`) deletes the existing rows for that report type and bulk-inserts the new ones inside one transaction, logging the upload to `report_uploads`. A Master Scheduler upload also seeds any newly-seen rooms into the `rooms` registry as `needs_review`.

### Room-linking heuristic
Open Slots rows don't carry a room. To show where a proposed lesson would likely happen, the app looks at the instructor's booked events that day (from Master Scheduler) and infers the room from whichever booking is adjacent (immediately before/after) the open slot. If adjacent bookings use different rooms, both are shown as an ambiguous guess rather than picking one. With no bookings that day at all, it falls back to the instructor's most-frequently-used room, labeled "Usually …". This is recomputed live — not stored.

### Why Room Schedule has no room-specific availability blocks
The Instructor Availability report has no room/facility column, so (unlike the old app's manually-maintained availability sheet) there's no reliable way to place a green "available" block in a specific room column. Availability instead powers the Teachers tab's weekly-availability view, which doesn't need a room.

---

## Known limitations

- No manual overlay for instructor age minimums or notes — deliberately dropped to avoid stale, hand-maintained data. May be revisited later.
- The room-linking guess is a heuristic, not ground truth — verify before communicating a specific room to a family for a lesson that hasn't been booked yet.
- Report uploads fully replace prior data for that type; there's no partial/incremental upload.
