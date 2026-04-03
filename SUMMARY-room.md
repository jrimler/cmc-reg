# CMC Room Schedule — Project Summary

## Purpose

A client-side web app for the Community Music Center (CMC) that lets instructors and administrators visualize studio room availability and lesson schedules across multiple branch locations. Users upload a RadGrid export (`.xls`/`.html`) and browse an interactive calendar-style grid organized by site and day of the week, with full print support.

---

## Tech Stack

- **Language:** Vanilla JavaScript (no frameworks or build tools)
- **Styling:** CSS with custom properties
- **Data Source:** HTML table format from RadGrid `.xls` exports
- **Fonts:** Google Fonts — Syne, Syne Mono, DM Sans
- **Deployment:** Single self-contained `index.html` file; works offline

---

## Architecture

Single-file SPA (`index.html`, ~1,322 lines) with clear internal sections:

| Section | Lines | Role |
|---|---|---|
| CSS Styles | 7–616 | Layout, theming, print media queries |
| HTML Structure | 618–665 | Upload screen, app container, tooltip, print section |
| JavaScript Core | 667–1148 | Parsing, state, grid rendering, UI interactions |
| Print Handler | 1151–1299 | Builds landscape multi-page printout |
| Sample Data | 1317–1322 | Hard-coded demo schedule (Feb 22, 2026) |

### Data Flow

```
File Upload → Parse HTML/XLS → Extract Events → 
Render Site Tabs → Render Day Tabs → Render Grid → Print (optional)
```

### Event Data Shape

```js
{
  date: "02/22/2026",
  item: "Piano",
  from: "9:00 AM",
  to: "09:30 AM",
  day: "Su",
  duration: "30",
  facility: "(09) Studio 9",
  site: "Mission Branch",
  instructor: "Garcia Plaza, Rosi",
  student: "Sebastian Muzzatti",
  type: "LESSON" // or "CLASS"
}
```

---

## Key Features

- **File Upload** — Drag-and-drop or click; parses `.xls`, `.xlsx`, `.html`, `.htm`
- **Site & Day Tabs** — Navigate across locations and days (Sun–Sat) with event counts
- **Color-Coded Events** — Instrument family determines color (Piano=blue, Strings=orange, Guitar=green, Voice=yellow, Winds=purple, Percussion=pink, Ensemble=gold)
- **Class vs. Lesson** — Class events rendered with a thicker border for visual distinction
- **Hover Tooltips** — Full event details on hover (time, instructor, student, room, site)
- **Adaptive Text Density** — Instrument shown always; instructor, student, and time range appear progressively based on block height
- **Print All Days** — Generates one landscape page per site/day combination via `window.print()`
- **Sample Data** — Built-in demo dataset for testing without a file upload
- **Sticky Layout** — Time column and headers stay fixed while scrolling the grid
- **No Backend** — Fully client-side; works offline after initial load

---

## Grid Rendering

- **Time Slots:** 15-minute intervals
- **Time Range:** Auto-calculated from earliest start to latest end (rounded to 30-min boundaries)
- **Layout:** Flexbox with absolute event positioning within room columns
- **Columns:** Dynamically generated based on number of rooms in the data

---

## Running the App

Open `index.html` directly in a browser — no server, build step, or dependencies required.

To test, click **"Use sample data"** on the upload screen.
