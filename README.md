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

### Still to do

1. **Create the Teacher Availability tab** in Google Sheets (`Instructor | Day | From | To | Room`), publish as CSV, provide URL → hardcode as `DEFAULT_AVAIL_URL`
2. **Test Room Schedule green blocks** once availability data is live — verify room names match exactly
3. **Verify Teacher Schedules gold blocks** are rendering correctly with live Open Slots data
4. **Decide**: Teacher Schedules view shows open-slot windows from the Lessons sheet. Once the manual availability tab exists, consider whether TS should use that instead (more stable — not dependent on weekly report upload)

---

## Known limitations

- **Google Sheets CSV cache**: Updates take 5–10 min to propagate after editing. Google CDN limitation — cannot be bypassed client-side.
- **No backend**: All data is read-only; nothing writes back to the sheet.
- **HTTPS / localhost required**: Google Sheets CORS blocks `file://` origin requests.
