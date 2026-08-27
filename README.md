# SFCMC Scheduler

Internal registrar tool for the San Francisco Community Music Center. A single-page web app combining two workflows: finding open lesson slots for student enrollment, and visualizing studio room usage by branch and day.

**Staff use only — not public-facing.** Live at [cmc-reg.netlify.app](https://cmc-reg.netlify.app/), auto-deployed from `main`.

---

## What it does

### Lesson Finder
Filters open lesson slots by instrument, day, lesson length, instructor, and branch. Each result row shows a best-guess room (derived from the instructor's booked schedule that day — see "Room-linking" below). Rows can be multi-selected and copied as plain text for enrollment emails.

### Teachers (tab within Lesson Finder)
Per-instructor roster — instruments taught, branches, and weekly availability — computed entirely from the latest uploaded reports. No manually-maintained fields (age minimums, notes) exist in this version.

### Room Schedule
Visualizes booked studio time by site and day, driven by the Master Scheduler report. Richmond always sorts first and is the default site. Richmond's columns are a curated, stable set — every room tagged `physical` in Admin → Rooms always shows, even with nothing booked there that day — plus any extra room actually booked that day (e.g. a virtual studio) so a real lesson is never hidden. Day tabs show every day present in the uploaded week (Monday through Sunday) with that day's actual calendar date. Prints as 11×17 (tabloid), one page per day per branch, covering both branches and all rooms actually booked — nothing is scoped out or cut off.

### Upload (admin role only)
Upload the three ASAP exports (Open Slots, Master Scheduler, Instructor Availability). Each upload fully replaces the current data for that report type.

### Admin (admin role only)
- **Rooms**: every room seen in a Master Scheduler upload, taggable as physical / virtual / home studio / offsite / needs review. Untagged and non-physical rooms are excluded from the 11×17 print. Tags persist across future uploads. Richmond's 14 physical rooms are seeded directly (see `supabase/migrations/0004_seed_richmond_physical_rooms.sql`) since a room with nothing booked yet in any upload would otherwise never get a row to tag.
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
2. In its SQL editor, run the files in `supabase/migrations/` in order (0001 through 0004).
3. Sign up through the app's login screen (first account defaults to `viewer` role), then in the Supabase SQL editor promote yourself:
   ```sql
   update profiles set role = 'admin' where id =
     (select id from auth.users where email = 'you@example.com');
   ```
4. Reload the app, sign in — the Admin and Upload tabs should now be visible.
5. Upload the three ASAP reports from the Upload screen.

The Supabase project URL and anon public key are hardcoded as constants near the top of `index.html`'s `<script>` (`SUPABASE_URL` / `SUPABASE_ANON_KEY`) — safe to keep in the client since the anon key is meant to be public and row-level security is what actually protects the data. To point this app at a different Supabase project, edit those two constants, commit, and push (Netlify auto-deploys).

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

---

## Dev workflow notes

- `.claude/settings.json` (committed) configures a Stop hook that checks, after each Claude Code turn, whether this repo has uncommitted or unpushed changes — if so, it asks Claude to update this README with a session summary, commit, and push before finishing. See `.claude/hooks/session-summary-check.sh`.
- Sample ASAP report files (`.xls`/`.xlsx`) are gitignored — they contain real instructor/student names and should never be committed.

---

## Recent changes

**2026-08-27** — Full stack wired up and hardened:
- Pushed the entire Supabase rewrite to GitHub as `main` (old Google Sheets-based v1 preserved in full at the `legacy-v1-google-sheets` branch, not deleted).
- Verified the Netlify site (`cmc-reg.netlify.app`, already connected to this repo) auto-deployed the new build correctly.
- Hardcoded the Supabase URL/anon key into `index.html`, removing the "connect to Supabase" screen — one less step for other staff.
- Renamed the app to "SFCMC Scheduler"; header now shows all three report upload times stacked (no more truncation), dropped the settings gear icon, and promoted Upload to its own top-level tab next to Lesson Finder and Room Schedule (Admin now just holds Rooms and Availability Overrides).
- Room Schedule: Richmond now always sorts first and loads by default; its room columns are a stable, curated set (`room_type = 'physical'` in Admin → Rooms) that always show even on days with nothing booked, seeded directly for Richmond's known 14 rooms rather than relying on upload data to discover them. Print simplified down to a single 11×17 (Richmond-only, physical rooms only) button.
- Fixed several real bugs found via live testing: a header-overflow layout bug (long status text was forcing the whole page to overflow horizontally under ~1700px), a missing `min-width: 0` causing the Lesson Finder table to blow out its container on narrower screens, a missing Postgres RLS `UPDATE` policy on `report_uploads` that silently left row counts stuck at 0, and the Supabase-enforced `pg-safeupdate` extension rejecting the upload functions' unqualified `DELETE`s.
- Set up this session's own automation (this Stop hook) for keeping this README current going forward.

**2026-08-27 (2)** — Upload screen: added an "Open in ASAP →" link on each of the three upload cards (Open Slots, Master Scheduler, Instructor Availability), linking directly to the corresponding ASAP Connected report page so staff can pull the source export without hunting for the URL.

**2026-08-27 (3)** — Room Schedule: fixed Saturday (and Sunday) rendering/printing.
- Print no longer scopes to Richmond only or to `physical`-tagged rooms only — it now generates a page per day per branch (both Richmond and Mission), including any room actually booked that day (e.g. home studios, virtual studios). Previously these non-pinned-room bookings were silently dropped from the printed page, which is what made Saturday specifically look cut off (Saturdays have the most home/virtual-studio bookings).
- Day tabs and the print header now show the uploaded week's actual calendar date next to each day (e.g. "Sat Sep 26"), not just the weekday name — added `fmtDateShort()` / `rsDateForSiteDay()` reading the `event_date` already parsed from the Master Scheduler upload.
- The 7-day (Mon–Sun) data plumbing itself was already correct; verified by loading the app in a headless browser with synthetic data shaped like a real upload and confirming both branches, all 7 days, and previously-dropped rooms all render/print correctly with no console errors.
