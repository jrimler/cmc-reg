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
- `localStorage` for persisting sheet URLs and last-used view

---

## Data sources

Three Google Sheets tabs, each published as CSV:

| Source | Format | Used by |
|---|---|---|
| Lesson Finder | OpenSlotsReport — `Department, Subject, Instructor, Day, Time, Duration, Date` | Lesson Finder |
| Room Schedule | RadGridExport — `Date, Item, From, To, Day, Duration, Facility, Site, Instructor, PL Student, Type` | Room Schedule |
| Teacher Profiles | `Name, Branches, AgeMin, Notes` | Both views |

Room Schedule and Teacher Profiles URLs are optional — Lesson Finder works without them.

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
  appMode:   'lessonFinder' | 'roomSchedule',
  sheetUrls: { lessonUrl, roomUrl, teachersUrl },

  lf: {
    records,          // processed lesson slot rows
    teacherProfiles,  // merged from Teachers sheet + RS-derived branches
    filters,          // active chip filters (Sets: instrument, day, instructor, duration)
    filterBranches,   filterStudentAge,
    sortBy,           activeTab,
    chipShowAll,
  },

  rs: {
    events,      // all room schedule events
    sites,       // sorted unique site names
    activeSite,  activeDay,
  },
}
```

### Data flow

```
localStorage / defaults
    ↓
fetchCsvUrl() × 3  (parallel, cache-busted)
    ↓
parseCsv() × 3
    ↓
processLessonRows()  → state.lf.records
processRoomRows()    → state.rs.events + derivedBranches
processTeacherRows() + buildTeacherProfiles() → state.lf.teacherProfiles
    ↓
Lesson Finder:  buildChipSidebar / renderTable / renderTeachers
Room Schedule:  renderSiteTabs / renderDayTabs / rsBuildGrid
```

---

## Session progress (2026-04-07)

### Done

**URL persistence overhaul**
- Removed localStorage for sheet URLs entirely — stale saved values were silently overriding correct ones
- All four sheet URLs now hardcoded as constants (`DEFAULT_LESSON_URL`, `DEFAULT_ROOM_URL`, `DEFAULT_TEACHERS_URL`, `DEFAULT_AVAIL_URL`)
- On every load, any old localStorage URL keys are automatically cleared
- Migrated to new Google Spreadsheet with verified, working tab gids

**Setup screen**
- Removed verbose step-by-step instructions, cleaner layout
- Better error messages that distinguish network failures from HTTP errors

**Open slots expansion (Lesson Finder)**
- Each row in the Lessons sheet represents an availability window (e.g. 4:00 PM, 1 hr)
- Previously only generated one record per window (starting at window open)
- Now expands into one record per 15-min start increment within the window (4:00, 4:15, 4:30… up to window end − 30 min)
- Each expanded record recalculates eligible lesson lengths based on remaining window time
- Raw windows stored separately in `state.lf.availabilityWindows` for use by other views

**Teacher Schedules view — availability layer**
- Availability windows from the Lessons sheet now render as gold/amber background blocks on the week grid
- Sit behind booked lessons (blue); deduplicated by day/from/to to avoid multi-instrument stacking

**Room Schedule — manual availability windows**
- Added `processAvailRows()` parser for a new manually-maintained sheet tab
- Tab columns: `Instructor | Day | From | To | Room`
- `state.rs.availWindows` stores parsed windows; `state.rs.facilityToSite` lookup derived automatically from booked events (no Site column needed in the tab)
- Availability windows render as green blocks in the correct room column, behind booked lessons
- Room columns expand to include rooms that appear in availability data even if no lessons are booked there

---

### Still to do

1. **Create the manual availability tab** in Google Sheets with columns `Instructor | Day | From | To | Room`, publish as CSV, provide URL to hardcode as `DEFAULT_AVAIL_URL`
2. **Test availability windows in Room Schedule** once real data is in the tab — verify room names match exactly
3. **Test open slots expansion** with real Lessons sheet data — confirm 15-min increments are rendering correctly in Lesson Finder
4. **Verify Teacher Schedules gold blocks** are appearing correctly with live data
5. **Decide**: Teacher Schedules view currently shows windows from the Lessons sheet (open slots). Once the manual availability tab exists, consider whether TS view should use that instead (more accurate — includes room context)
6. **README update** — reflect new 4-URL data source architecture and removal of localStorage for URLs

---

## Known limitations

- **Google Sheets CSV cache**: Updates take 5–10 min to propagate after editing. Google CDN limitation — cannot be bypassed client-side.
- **No backend**: All data is read-only; nothing writes back to the sheet.
- **HTTPS / localhost required**: Google Sheets CORS blocks `file://` origin requests.
