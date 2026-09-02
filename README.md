# SFCMC Scheduler

Internal registrar tool for the San Francisco Community Music Center. A single-page web app combining two workflows: finding open lesson slots for student enrollment, and visualizing studio room usage by branch and day.

**Staff use only — not public-facing.** Live at [cmc-reg.netlify.app](https://cmc-reg.netlify.app/), auto-deployed from `main`.

---

## What it does

### Lesson Finder
Filters open lesson slots by instrument, day, lesson length, instructor, and branch. Each result row shows a best-guess room (derived from the instructor's booked schedule that day — see "Room-linking" below). Rows can be multi-selected and copied as plain text for enrollment emails.

### Teachers (tab within Lesson Finder)
Per-instructor roster — instruments taught and branches — computed entirely from the latest uploaded reports. No manually-maintained fields (age minimums, notes) exist in this version.

### Room Schedule
Visualizes booked studio time by site and day, driven by the Master Scheduler report. Richmond always sorts first and is the default site. Richmond's columns are a curated, stable set — every room tagged `physical` in Admin → Rooms always shows, even with nothing booked there that day — plus any extra room actually booked that day (e.g. a virtual studio) so a real lesson is never hidden. Day tabs show every day present in the uploaded week (Monday through Sunday) with that day's actual calendar date.

Two Richmond-only print formats, each with an "all week" or single-day picker:
- **17×11 (Fixed Rooms)**: every `physical`-tagged Richmond room as a column, every time, whether booked or not — the same chart prints the same way day to day.
- **11×8.5 (Booked Only)**: just the `physical` rooms actually booked that day, so the page stays compact with no empty columns.

Both scale row height and column width to the day's actual time range and room count so a full day always fits on one physical page, and both are excluded from what they don't cover — non-`physical` rooms (home/virtual studios) never appear on either print, only in the on-screen view. Both are ink-light: events print as plain outlined boxes on white (no color fill), with lesson vs. class distinguished by a thicker left border rather than by color — the on-screen view keeps its blue/tan color coding.

### Daily Digest
A Richmond front-desk "where's the teacher" sheet, driven entirely by the Master Scheduler report. One row per teacher, showing which `physical` room(s) they're in as at-a-glance pills and their overall teaching span that day — the earliest student's start to the latest student's end, not a list of individual lessons. No student names or per-lesson detail; this answers "where's Ms. Grizzell right now," not "who's on her schedule." Only lists teachers/rooms with a real booking that day. All three columns (Teacher, Room(s), Schedule) are click-to-sort — click again to reverse direction; defaults to alphabetical by last name. Defaults to today's weekday whenever it falls within the uploaded week (not persisted across refresh, deliberately — a stale leftover day would defeat the point), falling back to the first day with data otherwise. Has one landscape-letter print button with an "all week" or single-day picker, producing one page per day: **By Room** and **By Instructor** side by side as two columns, each with its own title — "who's using Room B right now" and "where's Ms. Grizzell" both visible on the same sheet, no page-flipping or format picker. Room order matches Room Schedule's curated Richmond set; the instructor side is always alphabetical regardless of the on-screen sort. By Room groups rows under a gray room-name bar (grouping pays for itself there — several teachers can share a room); By Instructor is a flat single line per teacher (name, room(s), span) since a teacher has no equivalent grouping to lean on. The whole page automatically shrinks (fonts, padding — never below a legible floor) to whatever a given day's actual content needs, so a busy day still fits on the one page without manual tuning. The print header leads with the day of the week in large type (what a staffer actually needs at a glance, e.g. mid-shift, grabbing the right page off a stack) with the date beside it in smaller text; "Richmond" is tucked into a small corner label.

### Upload (admin role only)
Upload the two ASAP exports (Open Slots, Master Scheduler). Each upload fully replaces the current data for that report type.

### Admin (admin role only)
**Rooms**: every room seen in a Master Scheduler upload, taggable as physical / virtual / home studio / offsite / needs review. Untagged and non-physical rooms are excluded from both Room Schedule prints. Tags persist across future uploads. Richmond's 14 physical rooms are seeded directly (see `supabase/migrations/0004_seed_richmond_physical_rooms.sql`) since a room with nothing booked yet in any upload would otherwise never get a row to tag.

---

## Data sources

Two ASAP report exports, uploaded through the Admin screen. They arrive as HTML tables saved with an `.xls`/`.xlsx` extension (an ASAP/RadGrid export quirk) — the app sniffs the file type and parses either a real XLSX or an HTML table. Columns are matched by name, not position.

| Report | Columns | Feeds |
|---|---|---|
| Open Slots Report | `Department, Subject, Instructor, Day, Time, Duration, Date, TimePeriod` | Lesson Finder |
| Master Scheduler Report | `Date, Item, From, To, Day, Duration, Facility, Site, Instructor, PL Student, Type, Start Date, End Date` | Room Schedule, Daily Digest, room registry, room-linking |

A third report, Instructor Availability, was dropped entirely (see the 2026-08-29 changelog entry below) — ASAP can't scope that export to the current term, so it mixed previous- and current-term rows with no reliable way to isolate one from the other.

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
2. In its SQL editor, run the files in `supabase/migrations/` in order (0001 through 0006).
3. Sign up through the app's login screen (first account defaults to `viewer` role), then in the Supabase SQL editor promote yourself:
   ```sql
   update profiles set role = 'admin' where id =
     (select id from auth.users where email = 'you@example.com');
   ```
4. Reload the app, sign in — the Admin and Upload tabs should now be visible.
5. Upload the two ASAP reports from the Upload screen.

The Supabase project URL and anon public key are hardcoded as constants near the top of `index.html`'s `<script>` (`SUPABASE_URL` / `SUPABASE_ANON_KEY`) — safe to keep in the client since the anon key is meant to be public and row-level security is what actually protects the data. To point this app at a different Supabase project, edit those two constants, commit, and push (Netlify auto-deploys).

## Running locally

```
npm start
```

Serves `index.html` at `http://localhost:3000` via `npx serve`.

---

## Architecture

### Auth & roles
Supabase Auth (email/password). A `profiles` row (role: `admin` | `viewer`) is auto-created on signup via a Postgres trigger, defaulting to `viewer`. RLS policies: viewers can read all data tables; only admins can write to report data and `rooms`.

### Upload flow
Admin picks a file → client parses and column-maps it in-browser → a Postgres RPC function (`replace_open_slots` / `replace_master_schedule`) deletes the existing rows for that report type and bulk-inserts the new ones inside one transaction, logging the upload to `report_uploads`. A Master Scheduler upload also seeds any newly-seen rooms into the `rooms` registry as `needs_review`.

### Room-linking heuristic
Open Slots rows don't carry a room. To show where a proposed lesson would likely happen, the app looks at the instructor's booked events that day (from Master Scheduler) and infers the room from whichever booking is adjacent (immediately before/after) the open slot. If adjacent bookings use different rooms, both are shown as an ambiguous guess rather than picking one. With no bookings that day at all, it falls back to the instructor's most-frequently-used room, labeled "Usually …". This is recomputed live — not stored.

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

**2026-08-27 (3)** — Room Schedule: fixed Saturday/Sunday print scoping and added real dates to day tabs.
- Print no longer scopes to Richmond only or to `physical`-tagged rooms only — it now generates a page per day per branch (both Richmond and Mission), including any room actually booked that day (e.g. home studios, virtual studios).
- Day tabs and the print header now show the uploaded week's actual calendar date next to each day (e.g. "Sat Sep 26"), not just the weekday name — added `fmtDateShort()` / `rsDateForSiteDay()` reading the `event_date` already parsed from the Master Scheduler upload.

**2026-08-27 (4)** — Room Schedule: fixed the actual cause of Saturday/Sunday showing almost no data in-app — a Supabase/PostgREST default row cap, not a day-of-week bug.
- `fetchAllData()` was pulling every table with a bare `select('*')`, which PostgREST silently caps at 1000 rows by default, in whatever order Postgres returns without an `ORDER BY`. A week's Master Scheduler upload across two branches comfortably exceeds 1000 rows, so everything past the cap — which happened to include most of Saturday and nearly all of Sunday — was silently dropped on load, well before any Room Schedule rendering code ran. This is why (3) above didn't fix what the user was actually seeing.
- Added `fetchAllRows()`, which pages through a table via `.order('id').range(...)` until a page comes back short, and used it for every data table (`open_slots`, `master_schedule_events`, `instructor_availability`, `availability_overrides`, `rooms`) so no table's data silently truncates again as it grows past 1000 rows.
- Verified against a fake capped Supabase client (1720 synthetic rows, mirroring a real two-branch weekly upload) that all rows now load and every day Mon–Sun appears for both branches.

**2026-08-27 (5)** — A page refresh no longer drops the user back to Lesson Finder. The last-active view (Lesson Finder / Room Schedule / Upload / Admin) is saved to `localStorage` on every switch and restored on load, falling back to Lesson Finder if nothing's saved, the saved view no longer exists, or it's an admin-only view and the signed-in user isn't an admin.

**2026-08-27 (6)** — Room Schedule now also remembers the last-viewed branch and day (e.g. Mission / Saturday) across a refresh, not just that you were on the Room Schedule tab. Falls back to the usual default (Richmond, first day with data) if the saved site/day no longer applies to what's currently loaded.

**2026-08-27 (7)** — Reworked Room Schedule printing into two Richmond-only formats, replacing the old single "Print 11×17 (All Branches)" button:
- **17×11 (Fixed Rooms)**: every `physical`-tagged Richmond room as a column every time, whether booked or not. **11×8.5 (Booked Only)**: just the rooms actually booked that day. Each has its own day-picker ("All week" or a specific day) next to its print button.
- Row height and column width are now computed per page from that day's actual time range and room count (previously both were fixed constants) — a fixed 28px-per-15-minutes row height meant a long day (e.g. 9am–9pm) silently ran onto a second physical page, cutting off the tail of the schedule exactly like the Saturday bug from (3)/(4) above, just resurfacing in print layout instead of data loading. Caught this by rendering actual PDFs at the target paper size in a headless browser and inspecting them, not just checking the generated HTML.
- Also fixed two real bugs found the same way: `.rs-room-col-head`'s centered text was clipping symmetrically from both edges instead of ellipsizing from the end when a room label didn't fit a narrow column (now left-aligned for print); and the `@page` rules' `<explicit size> landscape` syntax wasn't reliably rotating in Chromium's PDF engine, so pages are now declared already-rotated (`17in 11in` / `11in 8.5in`) instead of relying on the `landscape` keyword.

**2026-08-27 (8)** — Both Room Schedule prints now use minimal ink: events render as plain white boxes with a thin gray outline instead of a filled color background (the color fill was the majority of the ink on a page with dozens of events). Lesson vs. class is still distinguishable at a glance via the existing thicker left border on class events, so no information was lost by dropping the color. The on-screen view is unaffected — it keeps its blue/tan color coding.

**2026-08-29** — Added the Daily Digest view (new top-level tab, `#dd-view`): a Richmond front-desk sheet answering "which teacher is in which room and for how long," built from Master Scheduler (actual bookings) joined with Instructor Availability (each teacher's full potential window that day) by first/last name, reusing the same name-matching and Availability Overrides logic as the Teachers tab. Teacher-first, one row per teacher with their sorted bookings (room, time, duration, item, student, a "Class" tag for `type: CLASS`) and their availability window(s) side by side; only teachers with a real booking that day are listed. Defaults to today's weekday rather than persisting the last-viewed day like Room Schedule does, since a stale digest is exactly the failure mode this feature exists to avoid. Ships with its own portrait-letter print format (`@page dd-page`, ink-light styling matching the two Room Schedule prints). Verified against the real (gitignored) sample Master Scheduler / Instructor Availability files in a headless-browser harness (Supabase client stubbed with data run through the app's own mapping functions) rather than just checking generated HTML — caught and confirmed correct one data quirk along the way: three real Master Scheduler rows this week carry `Instructor` = "Schedule Unavailable" (an ASAP placeholder for a lesson with no assigned teacher on record, distinct from Open Slots' identically-named but differently-meaning filter value) — left unfiltered and shown as-is, since these are real student bookings front desk needs to see, not blocked-out time to hide.

**2026-08-29 (2)** — Removed Instructor Availability entirely, app-wide: the user flagged that ASAP can't scope that report to the current term, so every export mixes previous- and current-term rows with no reliable way to tell them apart — the data was unusable, not just imperfect.
- Teachers tab: dropped the "Weekly availability" column; now just instruments + branches (still fully derived from live uploads).
- Daily Digest: dropped the "Available" column added earlier the same day; now just teacher + booked rooms/times, still Master-Scheduler-only.
- Admin: removed the "Availability Overrides" tab entirely (it existed solely to curate instructor_availability rows) — Admin now goes straight to Rooms, no tab bar.
- Upload screen: removed the Instructor Availability card; two report cards remain (Open Slots, Master Scheduler).
- Deleted `mapInstructorAvailabilityRows()`, `TEACHER_EMPLOYEE_TYPES`, both override functions, and every `state.data.availability` / `state.data.overrides` reference; `fetchAllData()` no longer queries either table.
- Added `supabase/migrations/0005_drop_instructor_availability.sql`, dropping the `instructor_availability` and `availability_overrides` tables (RLS policies and indexes go with them via `cascade`) and the `replace_instructor_availability` RPC. Not auto-applied — run it in the Supabase SQL editor like the others.
- Verified with the same headless-browser harness as the Daily Digest work: Teachers tab renders 106 rows with no availability column, Admin shows Rooms with no tab bar, Upload shows exactly two cards, and Daily Digest's booking list is unchanged apart from the dropped column.

**2026-08-30** — Reworked Daily Digest from a per-lesson booking list into a pure "where's the teacher" sheet, per front-desk feedback that individual students/lessons were more detail than needed:
- Rows now sort alphabetically by last name (reconstructed from the "First Last" display name the same way the Teachers tab already does — the part after the first space, since the last name itself can be multi-word) instead of by earliest booking time.
- Each teacher shows their room(s) as pill-style tags — deduped and in first-use order, so a teacher who moves rooms mid-day still reads clearly — instead of a line per individual lesson.
- Time shown is now one overall span per teacher (earliest student's start to latest student's end) instead of each lesson's own start/end.
- Dropped student names, lesson items, and the per-booking "Class" tag entirely — this view answers "which room is Ms. Grizzell in," not "who's on her schedule."
- Print format updated to match: three columns (Teacher / Room(s) / Schedule), room tags rendered outlined instead of filled to keep the existing ink-light print convention.
- Verified against the real sample Master Scheduler file across all six days with data: alphabetical ordering (including an edge case — the "Schedule Unavailable" placeholder instructor from the 2026-08-29 entry above sorts correctly by "Unavailable"), single- and multi-booking teachers collapsing to the right room tags and span, and the print layout across a full week.

**2026-08-30 (2)** — Made Daily Digest's three columns click-to-sort (Teacher, Room(s), Schedule); clicking the active column again reverses direction, shown via a ▲/▼ arrow. Room sorts by each teacher's first-used room; Schedule sorts by teaching-span start time. The chosen sort carries over when switching days within the session (not saved to `localStorage`, so a page refresh resets it to the alphabetical default like a fresh session), and print always uses that same alphabetical default regardless of what's selected on screen, so the printed sheet stays predictable. Verified interactively in a headless browser: clicked each header (including a second click to confirm direction reverses) and checked the resulting row order and arrow placement against the real Master Scheduler sample data.

**2026-08-30 (3)** — Tightened Daily Digest's column spacing: `.dd-table` no longer forces `width: 100%`, which had been stretching the whole table across the page width with nothing to absorb the slack but the Room(s) column — pushing Schedule far off to the right, away from the room tags it describes. The table now sizes to its own content instead, so all three columns sit close together regardless of screen width.

**2026-08-30 (4)** — Fixed three real problems with Daily Digest's print output, all caught by generating an actual paginated PDF in a headless browser and inspecting it (a plain print-media screenshot doesn't show real page breaks) rather than trusting the generated HTML:
- **A genuinely blank first page.** `#rs-print-section` and `#dd-print-section` were both unconditionally forced `display: block` during any print job — merely *emptying* the unused one's `innerHTML` wasn't enough to stop it, because Chromium inserts a phantom leading page wherever an empty `display:block` box precedes a sibling that switches to a named `@page` (Daily Digest's `page: dd-page`), since it has to break from the default page context to the named one. Fixed by making both sections `display: none` and toggling a `.print-active` class onto whichever one a given print action actually populates (`renderPrintPages()` for Room Schedule, `ddPrint()` for Daily Digest) — confirmed via PDF page count and per-page text extraction, and regression-tested printing Room Schedule → Daily Digest → Room Schedule back-to-back to rule out stale content bleeding from one print job into the next.
- **Real, unwanted ink.** `body`'s pale-blue `--paper` background had no white override for print, so the print-color-adjust rule already in place (needed so event colors and borders print faithfully) was also forcing that tint to print everywhere there wasn't an opaque white box on top of it — invisible under Room Schedule's dense grid, but a visible wash of color across Daily Digest's much emptier list. Added `body { background: #fff !important; }` to the print media block, fixing it for both prints.
- **Odd spacing.** The print grid used `fr`-unit columns that stretch to fill the full 7.5in printable width regardless of content length — the exact same "Schedule far from Room(s)" issue fixed on-screen in the (3) entry above, just unaddressed in print. Switched to fixed inch-based column widths sized to actual content, so the printed sheet reads as one compact block instead of three widely-spaced columns.

**2026-08-31** — Richmond's Recital Hall is now identifiable and sorts correctly by letter everywhere the app shows a bare room name (Daily Digest's room tags and its Room(s) column sort, Room Schedule's column header). Every other Richmond room keeps its letter visible after the app strips the raw label's leading `"(X) "` prefix, because the letter is also baked into the room name itself (`"(B) Room B -- RDB"` → `"Room B -- RDB"`); the Recital Hall had no such luck (`"(A) Recital Hall -- RDB"` → `"Recital Hall -- RDB"`, the "A" just gone). Added `supabase/migrations/0006_recital_hall_canonical_name.sql`, setting an explicit `canonical_name` of `"(A) Recital -- RDB"` for that one room — the mechanism the app already has for exactly this (`canonical_name` overrides the stripped-raw-label fallback everywhere `roomDisplayName()` is used), so no shared display or sort logic needed to change, and `raw_facility_label` stays untouched (it has to keep matching the ASAP export exactly, or a future Master Scheduler upload won't link back to this room). A leading `"(A)"` also sorts ahead of `"Room B"`, `"Room C"`, etc. for free, since `"("` precedes any letter. Not auto-applied — run it in the Supabase SQL editor like the others. Verified in a headless browser against the real Master Scheduler sample data: the room tag reads `"(A) Recital -- RDB"` and sorts first when the Daily Digest's Room(s) column is sorted.

**2026-09-01** — Added a second Daily Digest print format, **By Room**, alongside the existing By Teacher sheet (renamed on its button for clarity) — per front-desk feedback that "who's using Room B right now" is a different question than "where's Ms. Grizzell," and the by-teacher list doesn't answer it well. Its own day-picker + print button sits next to the existing one. Added `ddRoomsForDay()`, grouping that day's Richmond bookings by room (in the same curated display order Room Schedule uses) then by teacher within each room, reusing the existing "earliest booking start to latest booking end" span logic rather than per-lesson detail — consistent with the rest of Daily Digest's design. `ddPrint()` now takes the page-builder function as a parameter instead of being hardwired to the by-teacher layout, so both formats share the same print-section plumbing (`print-active` toggling, "all week" vs. single-day). Verified against the real sample Master Scheduler file in a headless-browser harness: rendered actual paginated PDFs (not just generated HTML) for both a light day (7 rooms) and a busy one (8 rooms/10 teachers, including a room with two sequential teachers), confirmed the Recital Hall's canonical name still renders correctly as a room heading, and confirmed a 6-day "all week" print produces exactly 6 pages.

**2026-09-01 (2)** — Simplified the two same-day Daily Digest print formats back down to one button, and unified their look:
- **One control, always two pages.** The By Room button/day-picker added earlier today is gone; the single remaining "Print Daily Digest" button now always produces two pages per day — By Teacher, then By Room — rather than picking one format. Chose fixed two-page output over trying to fit both on one page, since a busy day (8+ rooms, 10+ teachers) would force cramped text to make that fit; two full-size pages stays predictable regardless of how busy the day is.
- **One shared visual language.** By Teacher previously looked different from By Room — a 3-column table with outlined room-tag pills, vs. gray section-title bars with plain 2-column rows. By Teacher now uses the same bar-plus-rows layout as By Room: each teacher gets a gray title bar (their name) with one row underneath listing their room(s) as plain text and their overall span — no table, no pills, on either page. `.dd-print-room-block`/`.dd-print-room-name`/`.dd-print-row--room` were generalized to `.dd-print-block`/`.dd-print-block-title`/a single `.dd-print-row` (both pages now use the same 2-column grid), and `.dd-print-colheads` was removed as no longer needed.
- Verified in the same headless-browser PDF harness: the restyled By Teacher page against a busy day (10 teachers, one page, no overflow) visually matches By Room's bar/row style; a single day's "Print Daily Digest" click produces exactly 2 pages; a 6-day "all week" print produces exactly 12 pages (2 × 6).

**2026-09-01 (3)** — Made both Daily Digest print headers lead with the day of the week instead of the "Daily Digest" label, per feedback that a staffer grabbing a page off a stack mid-shift needs "what day is this" at a glance far more than the feature's name. The day name (`.dd-print-dayname`, e.g. "Tuesday") is now large serif type with the date beside it in smaller mono type; "Richmond" and the page format (By Teacher / By Room) — previously the large left-aligned title — moved into a small uppercase corner label (`.dd-print-pagelabel`) that exists only to tell two printed pages apart, not to announce itself. Verified in the same PDF harness that both pages render with the day name as the dominant header element and the site/format label legible but clearly secondary.

**2026-09-01 (4)** — Merged Daily Digest's two portrait print pages into one landscape page per day, By Room and By Instructor as side-by-side columns instead of separate pages — the user's own suggestion, since both views are short enough to fit together and a single sheet beats flipping pages at a front desk. `@page dd-page` flipped from `8.5in 11in` to `11in 8.5in` (margin tightened to `0.35in` to match the app's other landscape print), and `ddBuildPrintPage()`/`ddBuildPrintPageByRoom()` were split into `ddRoomBlocksHtml()`/`ddTeacherBlocksHtml()` (just the block markup) composed into one `.dd-print-columns` flex row under a shared day-name header, with a `.dd-print-col-title` ("By Room" / "By Instructor") at the top of each column doing the job the old per-page corner label did. `.dd-print-row`'s fixed `2.8in 1.7in` grid became `1fr 1.5in` since each column is now roughly half as wide. Renamed the instructor-side label from "By Teacher" to "By Instructor" per the user's wording (print-only — the on-screen "Teacher" column and internal naming are unchanged). Verified in the same headless-browser PDF harness against the real sample data's busiest day (Thursday: 11 instructors across 7 rooms, two rooms double-booked) — renders on exactly 1 page with room to spare, not just a technical fit — and that a 6-day "all week" print produces exactly 6 pages (one per day, not two).

**2026-09-01 (5)** — Made the single-page Daily Digest print reliably fit even on a busier day than the merge above was tested against, after the user reported a real Tuesday not fitting on one page:
- **Actual root cause: fixed sizing can't account for real-world print rendering.** The earlier verification measured a headless Chromium PDF render, but a live browser's actual font metrics, and its print dialog's own margin/scale settings, can differ enough to push content past one page even when the CSS math says it should fit.
- **Fix: measure, don't assume.** Added `ddScalePrintPages()`, called right before `window.print()`, which measures each page's actual rendered column height in the browser doing the printing (not a synthetic estimate) and shrinks fonts/padding via a `--dd-scale` CSS custom property just enough to fit the physical page — the same "scale to fit the day's real content" approach Room Schedule's grid print already uses (`rsBuildGrid`), just measured from the live DOM instead of computed from time-range math. A light day still prints at full scale, unchanged. Moved the `.dd-print-*` rules out of `@media print` (unconditional now) since this measurement has to happen while the browser is still in screen mode, before an actual print context exists — safe, since `#dd-print-section` stays `display:none` outside of that measurement pass and real printing either way.
- **Fix: the two-line-per-teacher block was the real ceiling.** By Instructor's "title bar + row" per teacher cost roughly 2x the vertical space of By Room's title bar for zero benefit — a teacher has nothing to group multiple entries under, unlike a room. By Instructor is now a single flat line per teacher (name, room(s), span all in one row via `dd-print-row--flat`, three columns), which by itself roughly doubles how many teachers fit before scaling is even needed. Also trimmed both columns' block/row padding and margins slightly for a bit more headroom on every day, not just busy ones.
- Verified against real sample data (all 6 days now render at full scale, `--dd-scale: 1`, with margin to spare — Thursday, the busiest, previously needed slight scaling and no longer does) and against synthetic stress scenarios well beyond anything seen in real data. A hypothetical all-14-rooms fully-booked day (~21 instructors) still overflows to a second page even at the scaling floor (`DD_MIN_SCALE: 0.7`, chosen to stay legible rather than shrink further) — a known, honest limit rather than a false "always" guarantee, and well past any real week's actual volume (busiest real day seen: 11 instructors/7 rooms).
