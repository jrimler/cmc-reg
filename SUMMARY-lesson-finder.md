# SFCMC Lesson Finder — Project Summary

## Purpose
A lesson availability finder for the San Francisco Community Music Center (SFCMC). **Internal tool used by registrars only — not public-facing.** Registrars use it to look up available lesson slots by instrument, day, time, location, teacher, and student age when helping students enroll.

Replaces a manual/spreadsheet workflow with a filterable UI backed by a Google Sheet. Feature decisions should be framed around registrar workflows, not end-user (student/parent) UX.

---

## Tech Stack
- **Single-file SPA** — all HTML, CSS (~1,400 lines), and JS (~700 lines) live in `index.html`
- **Vanilla JS** — no framework; no build step required
- **XLSX.js v0.18.5** (CDN) — CSV parsing
- **Google Fonts** — DM Serif Display, DM Mono, DM Sans
- **Google Sheets (published CSV)** — primary data source, two tabs (Schedule + Teachers)
- **localStorage** — persists user-provided sheet URLs (`sfcmcSheetUrl`)

---

## Key Features
1. **Multi-dimension filtering** — instrument (chip), day, duration (30/45/60 min), instructor, branch (Richmond/Mission/Online/Home Studio), student age (numeric)
2. **Live search with autocomplete** — groups by Subject, Day, Instructor; keyboard nav; shows slot counts
3. **Group-by sorting** — by Instrument (default), Day, or Instructor
4. **Teacher Profiles tab** — shows branches, age minimum, notes per instructor
5. **Setup screen** — paste Google Sheet CSV URLs if defaults fail; stored in localStorage
6. **Refresh Data button** — re-fetches from Google Sheets on demand

---

## Architecture

### File
`index.html` — the entire application

### UI Sections
- `#header` — title, last-refresh status, search box, Refresh button
- `#tab-bar` — "Availability" / "Teachers" tabs
- `#panel-availability` — sidebar filters + results table
- `#panel-teachers` — instructor profile table
- `#setup-screen` — initial URL configuration
- `#loading-overlay` — spinner shown during fetch

### Global State (JS)
```
allRecords[]         // all loaded lesson records
teacherProfiles{}    // keyed by instructor name
filters{}            // Sets: instrument, day, instructor, duration
filterBranches       // Set of active branch filters
filterStudentAge     // string (numeric input)
sortBy               // 'instrument' | 'day' | 'instructor'
activeTab            // current tab
```

### Key Functions
| Function | Purpose |
|---|---|
| `loadFromSheet(urls)` | Orchestrates full data fetch & render |
| `fetchCsvUrl(url)` | Fetches published Google Sheet CSV |
| `parseCsv(csvText)` | Parses CSV via XLSX |
| `processRows(rows)` | Converts schedule rows → record objects |
| `getFiltered()` | Applies all filters + sort |
| `renderTable()` | Writes results rows to DOM |
| `buildChipSidebar()` | Creates filter chip UI |
| `buildSearchDropdown(query)` | Autocomplete results |

---

## Data Model

### Schedule Tab Columns
`Department, Subject, Instructor, Day, Time, Duration, Date`
- Subject: semicolon-separated (one record can cover multiple instruments)
- Duration: "30 min", "1 hr", "1 hr 15 min", etc.

### Teachers Tab Columns
`Name, Branches, Age Min, Notes`

### Filtering / Skip Rules
- Skip instructors: "Reserved Room", "SCHEDULE UNAVAILABLE"
- Skip subjects: Group Class(es), Room Reservation, Hold, Accompanist, Feldenkrais, Ear Training, Sight Singing, Music Therapy for Special Needs, etc.
- Only include lessons ≥ 30 min

---

## Entry Point & Execution Flow
1. Browser opens `index.html`
2. IIFE runs → calls `loadFromSheet(DEFAULT_SCHEDULE_URL, DEFAULT_TEACHERS_URL)`
3. On success → parse, build sidebar, render table, show Availability tab
4. On failure → show Setup screen with error

---

## Constraints
- No backend — entirely client-side
- No build process — deploy by serving the single HTML file
- HTTPS required (Google Sheets CORS)
- Data is read-only (no writes to sheet)
- Default sheet URLs are hardcoded in the JS
