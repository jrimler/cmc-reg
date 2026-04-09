# SFCMC Reg Tool

Internal registrar tool for the San Francisco Community Music Center. A single-page web app combining two workflows: finding open lesson slots for student enrollment, and visualizing studio room usage by site and day.

**Staff use only — not public-facing.**

---

## What it does

### Lesson Finder
Helps registrars look up available lesson slots when enrolling students. Filters by instrument, day, lesson length, instructor, branch, and student age. Results are shown in a sortable table with slot-length badges, branch pills, and age minimums. Includes a full-text search/autocomplete in the header.

### Room Schedule
Visualizes how studio rooms are booked across the week for each branch. Displays a pixel-accurate time grid organized by site and day, color-coded by instrument family (Piano, Strings, Guitar, Voice & Choir, Winds & Brass, Percussion, Ensemble & Jazz). Hover tooltips show instructor, student, and time details.

### Teachers
A roster panel (tab within Lesson Finder) listing all instructors with their instruments, branches, age minimums, and notes — built from the Teachers sheet merged with data derived from the Room Schedule.

---

## File structure

```
index.html     — the entire app (HTML + CSS + JS, ~2,600 lines)
package.json   — defines `npm start`
README.md      — this file
```

No build step. No framework. No dependencies beyond CDN-loaded XLSX.js.

---

## Tech stack

- Vanilla JavaScript
- XLSX.js v0.18.5 (CDN) for CSV parsing
- Google Sheets published CSV as live data source
- Google Fonts: DM Serif Display, DM Mono, DM Sans
- `localStorage` for persisting last-used view and teacher schedule blocks (URLs are now hardcoded)

---

## Data sources

Four Google Sheets tabs, each published as CSV and hardcoded as URL constants:

| Constant | Sheet | Format | Used by |
|---|---|---|---|
| `DEFAULT_LESSON_URL` | Open Slots Report | `Department, Subject, Instructor, Day, Time, Duration, Date` | Lesson Finder, Teacher Schedules |
| `DEFAULT_ROOM_URL` | Room Schedule | `Date, Item, From, To, Day, Duration, Facility, Site, Instructor, PL Student, Type` | Room Schedule, Teacher Schedules |
| `DEFAULT_TEACHERS_URL` | Instructor Notes | `Name, Branches, AgeMin, Notes` | Lesson Finder → Teachers tab |
| `DEFAULT_AVAIL_URL` | Teacher Availability | `Instructor, Day, From, To, Room` | Room Schedule (green availability blocks) |

Room Schedule, Instructor Notes, and Teacher Availability URLs are optional — Lesson Finder works without them. `DEFAULT_AVAIL_URL` is currently empty pending sheet creation.

---

## Running locally

```
npm start
```

Serves `index.html` at `http://localhost:3000` via `npx serve`. No install required.

Opening `index.html` directly also works, but Google Sheets CORS blocks fetches from `file://` — use `npm start` or serve over HTTPS for live data.

---

## First-time setup

1. In Google Sheets: **File → Share → Publish to web → select tab → CSV → Publish**
2. Copy the published CSV URL
3. Open the app — the setup screen prompts for URLs
4. Paste URLs and click **Connect & Load**
5. URLs are saved in `localStorage` and auto-loaded on return visits

The gear icon in the header reopens setup to update URLs at any time.

---

## Architecture

### `index.html` layout

| Section | Role |
|---|---|
| CSS variables & reset | Shared design tokens |
| Shared header styles | Nav bar, search box, view switcher, refresh/settings buttons |
| Lesson Finder styles | Sidebar chips, branch/age filters, results table, teacher panel |
| Room Schedule styles | Site/day tabs, time grid, event blocks, tooltip |
| HTML shell | Header, setup screen, LF view, RS view, tooltip, print section |
| Shared JS utilities | `escHtml`, `parseMins`, `timeToSort`, `normalizeInstructorName` |
| Data pipeline | `fetchCsvUrl`, `parseCsv`, three parsers, `loadAllData` |
| Lesson Finder JS | Filtering, chip sidebar, search autocomplete, table render, teacher render |
| Room Schedule JS | FAM_MAP/colors, grid builder, site/day tabs, tooltip, print-all export |
| Event listeners | All UI interactions |
| Init | Restores saved URLs and last view, auto-loads on startup |

### State

```js
state = {
  appMode:   'lessonFinder' | 'roomSchedule' | 'teacherSchedules',
  sheetUrls: { lessonUrl, roomUrl, teachersUrl, availUrl },

  lf: {
    records,              // processed open slot rows (one per CSV row)
    availabilityWindows,  // raw windows for Teacher Schedules view
    teacherProfiles,      // merged from Teachers sheet + RS-derived branches
    filters,              // active chip filters (Sets: instrument, day, instructor, duration)
    filterBranches,       filterStudentAge,
    sortBy,               activeTab,
    chipShowAll,          viewMode,
  },

  rs: {
    events,          // all booked room schedule events
    availWindows,    // manual teacher availability windows
    facilityToSite,  // { 'Studio A': 'Richmond', … } derived from events
    sites,           // sorted unique site names
    activeSite,      activeDay,
  },

  ts: {
    activeTeacher,
    blocks,  // manual blocks in localStorage { teacherName: [{ id, day, from, to, type, note }] }
  },
}
```

### Data flow

```
Hardcoded URL constants (DEFAULT_*_URL)
    ↓
fetchCsvUrl() × 4  (parallel, cache-busted)
    ↓
parseCsv() × 4
    ↓
processLessonRows()  → state.lf.records + state.lf.availabilityWindows
processRoomRows()    → state.rs.events + derivedBranches + state.rs.facilityToSite
processTeacherRows() + buildTeacherProfiles() → state.lf.teacherProfiles
processAvailRows()   → state.rs.availWindows
    ↓
Lesson Finder:      updateChipSidebar / renderTable / renderTeachers
Room Schedule:      renderSiteTabs / renderDayTabs / rsBuildGrid (events + availWindows)
Teacher Schedules:  renderTsSidebar / renderTsWeekGrid (events + availabilityWindows + manual blocks)
```

---

## Session progress (2026-04-07)

### Done

**URL persistence overhaul**
- Removed localStorage for sheet URLs — stale saved values were silently overriding correct ones
- All four sheet URLs now hardcoded as constants; old localStorage keys auto-cleared on every load
- Migrated to new verified Google Spreadsheet

**Setup screen**
- Simplified — removed verbose step-by-step instructions
- Better error messages distinguishing network failures from HTTP errors

**Lesson Finder — availability window display**
- Each row in the Open Slots Report is an availability window (e.g. Monday, 5:00 PM, 3 hrs 30 mins = available 5:00–8:30 PM)
- Time column now shows the full range ("5:00 PM – 8:30 PM") instead of just the start time
- Slot badges (30/45/60 min) correctly reflect what lesson lengths fit within the window
- `endTime` field added to each record; `state.lf.availabilityWindows` stores raw windows for Teacher Schedules view

**Teacher Schedules view — availability layer**
- Availability windows from the Open Slots Report render as gold/amber background blocks on the week grid
- Sit behind booked lessons (blue); deduplicated by day/from/to to avoid multi-instrument stacking

**Room Schedule — manual teacher availability**
- Added `processAvailRows()` parser for a manually-maintained sheet tab (`Instructor | Day | From | To | Room`)
- `state.rs.availWindows` and `state.rs.facilityToSite` (derived from booked events — no Site column needed)
- Availability windows render as green blocks in the correct room column, behind booked lessons
- Room columns expand to include rooms from availability data even if no lessons are booked there

---

## Session progress (2026-04-09)

### Done

**Room Schedule — removed green availability blocks from grid**
- Green availability blocks (`state.rs.availWindows`) no longer render in the Room Schedule grid
- Underlying data (`state.rs.availWindows`, `processAvailRows()`) preserved for future use in other views
- Surgical removal from `rsBuildGrid` only — no data or parser changes

**Room Schedule — print feature rebuilt from scratch**
- Replaced the old print implementation with a clean `@media print` CSS approach
- Print layout: portrait 8.5×11in, 0.4in top/bottom margins, 0.5in left/right margins
- All non-print content hidden via `body > *:not(#rs-print-pages)` — no DOM restructuring needed
- `#rs-print-pages` div populated just before `window.print()`, cleared in `afterprint` listener
- `body.printing-single` / `body.printing-week` class switching controls per-page breaks
- Print-specific grid rendering uses tighter dimensions (115px room width, 22px slot height vs 140px/28px on screen)
- Black and white output: white event blocks with black borders, gray room headers, simple grid lines — screen view unchanged

**Room Schedule — "Print this day" button**
- Prints the currently active site/day as a single portrait page
- Time range cropped to actual events ±15 minutes (rounded to 30-min intervals)
- Auto-zoom: measured from actual DOM `scrollHeight`/`scrollWidth` via `body.rs-measuring` simulation class; `min(scaleW, scaleH)` ensures nothing clips on either axis
- `forPrint` flag passed to `rsBuildGrid` to use compact dimensions

**Room Schedule — "Print full week" button**
- Iterates over all days with events for the active site and generates one page per day
- Each page independently measured and zoomed to fit one portrait page
- Each page has its own time-range crop, so a light Monday doesn't waste vertical space

**Room Schedule — print page header**
- Each print page shows: site name + day (left), date from CSV data (right)
- Header styled with DM Serif Display (title) and DM Mono (date), matching app typography

**Room Schedule — print room filtering**
- Only the 7 Richmond studio rooms print: Room A, B, C, D, Grand Piano, Multi-Purpose, Sun Porch
- Filtered via `RS_PRINT_ROOMS` set in `rsBuildPrintPage` — off-site and virtual rooms excluded

**Bug fix — time axis alignment in print**
- `.rs-time-tick` was 28px on screen but the print grid uses 22px slots — labels drifted from blocks
- Fixed by adding `height: 22px !important` override in `@media print`

**Room Schedule — student name on event blocks**
- Student name now appears on event blocks when the block is tall enough (≥36px height)
- Rendered as a third line below instructor name, using the same `.rs-event-info` sizing
- Reads from `ev.student` field (mapped from "PL Student" / "student" column in the Room Schedule sheet)

**Room Schedule — per-day dates on day tabs**
- Each day tab now shows the actual calendar date pulled from the CSV's `date` column (e.g. "4/7")
- Rendered as a small `.rs-day-tab-date` span inside the tab button
- Handles both M/D/YYYY and YYYY-MM-DD formats via regex (avoids `new Date()` timezone issues)
- "Data as of" label removed from the action bar entirely

**Bug fix — XLSX date serial number handling**
- XLSX library was converting date strings to Excel serial numbers (e.g. `46481`) even with `raw: false`
- Root fix: added `cellDates: false` to `XLSX.read()` options; `raw: false` in `sheet_to_json` returns formatted strings
- Added `getDate()` helper in `processRoomRows` as a fallback: detects numeric values and converts from Excel serial to M/D/YYYY using UTC math (`new Date(Math.round((serial - 25569) * 86400000))`)
- This fixed "1/1" appearing on all day tabs

**Bug fix — print buttons always visible**
- Print buttons were conditionally hidden via `class="rs-hidden"` + `renderPrintBtns()` logic
- Removed the conditional entirely — buttons are always present in the RS view HTML, no JS toggling needed

**Bug fix — print functions used hardcoded 'Richmond' site name**
- Both `rsPrintDay` and `rsPrintWeek` filtered events with `rsForSiteDay('Richmond', day)`, causing "No data to print" errors when the actual site string in the CSV didn't match exactly
- Fixed by switching to `state.rs.activeSite` — prints whatever site is currently selected

---

### Still to do

1. **Create the Teacher Availability tab** in Google Sheets (`Instructor | Day | From | To | Room`), publish as CSV, provide URL → hardcode as `DEFAULT_AVAIL_URL`
2. **Verify Teacher Schedules gold blocks** are rendering correctly with live Open Slots data
3. **Investigate Tuesday missing from full-week print** — console logging added to `rsPrintWeek`; check whether Tuesday events exist and whether their facility names match `RS_PRINT_ROOMS`

---

## Known limitations

- **Google Sheets CSV cache**: Updates take 5–10 min to propagate after editing. Google CDN limitation — cannot be bypassed client-side.
- **No backend**: All data is read-only; nothing writes back to the sheet.
- **HTTPS / localhost required**: Google Sheets CORS blocks `file://` origin requests.
