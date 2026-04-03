# SFCMC Reg Tool

Internal registrar tool for the San Francisco Community Music Center. Combines two workflows into a single offline-capable web app: finding open lesson slots for enrollment, and visualizing studio room usage by site and day.

**Staff use only — not public-facing.**

---

## What it does

### Lesson Finder
Helps registrars look up available lesson slots when enrolling students. Filters by instrument, day, lesson length, instructor, branch, and student age. Data comes from an OpenSlotsReport published as CSV from Google Sheets.

### Room Schedule
Visualizes how studio rooms are booked across the week for each branch location. Displays a time-grid organized by site and day, color-coded by instrument family, with hover tooltips and a print-all-days export. Data comes from a RadGrid export published as CSV.

---

## Tech stack

- Vanilla JavaScript — no framework, no build step
- Single file: `index.html` (~1,800 lines of HTML + CSS + JS)
- XLSX.js v0.18.5 (CDN) for CSV parsing
- Google Sheets published CSV as data source (three separate tabs/URLs)
- Google Fonts: DM Serif Display, DM Mono, DM Sans
- `localStorage` for persisting sheet URLs and last-used view

---

## Data sources

Three separate Google Sheets tabs, each published as CSV:

| Source | Format | Used by |
|---|---|---|
| Lesson Finder | OpenSlotsReport — `Department, Subject, Instructor, Day, Time, Duration, Date` | Lesson Finder view |
| Room Schedule | RadGridExport — `Date, Item, From, To, Day, Duration, Facility, Site, Instructor, PL Student, Type` | Room Schedule view |
| Teacher Profiles | `Name, Branches, AgeMin, Notes` | Both views (branch + age data) |

Room Schedule and Teacher Profiles URLs are optional — the Lesson Finder works without them.

---

## Running locally

```
npm start
```

Serves `index.html` at `http://localhost:3000` using `npx serve`. No install required.

Or just open `index.html` directly in a browser — no server needed unless you need to test fetch behavior (Google Sheets CORS requires HTTPS or localhost).

---

## First-time setup

1. In Google Sheets: **File → Share → Publish to web → select tab → CSV → Publish**
2. Copy the published CSV URL
3. Open the app — the setup screen will prompt for URLs
4. Paste the URLs and click **Connect & Load**
5. URLs are saved in `localStorage` and auto-loaded on return

---

## Architecture

### File layout (`index.html`)

| Section | Role |
|---|---|
| CSS variables & reset | Shared design tokens |
| Shared header styles | Nav bar, search box, view switcher |
| Lesson Finder styles | Sidebar, chip filters, table, teacher panel |
| Room Schedule styles | Site/day tabs, time grid, event blocks, tooltip |
| HTML shell | Header, setup screen, LF view, RS view, tooltip, print section |
| Shared JS utilities | `escHtml`, `parseMins`, `timeToSort`, `normalizeInstructorName` |
| Data pipeline | `fetchCsvUrl`, `parseCsv`, three parsers, `loadAllData` |
| Lesson Finder JS | Filtering, chip sidebar, search autocomplete, table render |
| Room Schedule JS | FAM_MAP/colors, grid builder, site/day tabs, tooltip, print |
| Event listeners | All UI interactions |
| Init | Restores saved URLs and last view, auto-loads on startup |

### State shape

```js
state = {
  appMode:   'lessonFinder' | 'roomSchedule',
  sheetUrls: { lessonUrl, roomUrl, teachersUrl },

  lf: {
    records,         // lesson slot records
    teacherProfiles, // merged from Teachers sheet + RS derivation
    filters,         // active chip filters (Sets)
    filterBranches,  filterStudentAge,
    sortBy,          activeTab,
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
processLessonRows() → state.lf.records
processRoomRows()   → state.rs.events + derivedBranches
processTeacherRows() + buildTeacherProfiles() → state.lf.teacherProfiles
    ↓
renderSiteTabs / renderDayTabs / renderGrid   (Room Schedule)
buildChipSidebar / renderTable / renderTeachers  (Lesson Finder)
```

---

## Known limitations

- **Google Sheets published CSV cache**: Updates can take 5–10 minutes to propagate after editing the sheet. This is a Google CDN limitation and cannot be bypassed client-side. Edit the sheet, wait ~10 minutes, then refresh.
- **No backend**: All data is read-only; nothing writes back to the sheet.
- **HTTPS / localhost required**: Google Sheets CORS blocks requests from `file://` origins. Use `npm start` or serve over HTTPS.
