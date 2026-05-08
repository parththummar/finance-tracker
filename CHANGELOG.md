# Changelog

All notable changes to **FinanceTracker** (Ledgerly) are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Version headings match **semver** derived from **`git log`** (newest-first). Xcode **`MARKETING_VERSION`** reads the same numeric line (e.g. `2.4` ≡ `2.4.0`); **`CURRENT_PROJECT_VERSION`** is the **build**.

## [Unreleased]

---

## [2.5.0] (1) - 2026-05-08

### Added

- **App lock on launch** — Touch ID, Apple Watch unlock, or system password before the UI appears. Defaults to on; toggle in Settings → Security.
- **Stealth mode** — blurs every amount across Dashboard, KPI cards, breakdowns, and snapshot list; hover to reveal individual values.
- **Menu bar item** — net worth + QoQ delta in the system menu bar, refreshes every minute, click to open or refresh.
- **Goal target date + progress** — set a date alongside the value, get a progress bar, trend ETA, and "on track / behind" pacing.
- **Net-worth forecasting** — linear and CAGR projection with ±1σ confidence band on Trends; toggle method.
- **Liquidity / runway panel** — cash on hand, average monthly net change, runway in months at current burn rate.
- **Cost basis per account** — optional starting basis; "Unrealized" column on accounts shows gain/loss vs current value.
- **QoQ heatmap** in Reports — quarters × categories grid coloured by quarter-over-quarter Δ%.
- **Snapshot completeness badge** — chip on snapshot list and editor showing filled vs missing rows; missing rows highlighted red in editor.
- **Stale-account flag** — accounts whose last 3 snapshot values are within 0.5% are tagged STALE.
- **Auto-backfill new accounts** into past unlocked snapshots when opened, so values can be added retroactively. Same for receivables (with start-date awareness).
- **⌘K command palette** — fuzzy jump to any screen, snapshot, account, person, country, or quick action; arrow keys + Enter to fire.
- **Pinned snapshot tabs** above the snapshot list for fast switching between recent / important snapshots.
- **Recently viewed list** in the sidebar (expanded mode) — last 6 accounts and snapshots clicked.
- **Customizable Dashboard widgets** — show / hide / reorder all panels via Settings, including drag-and-drop.
- **Per-person "Include in net worth"** toggle — track parents / partners alongside without inflating own totals; "OFF NW" badge surfaces excluded accounts. Toggle directly from the People grid.
- **Inline-editable People grid** — name, color, "In NW" toggle, "Active" toggle, and a quick-add row at the bottom are all edited directly in the table; no editor sheet.
- **Inline-editable Countries grid** — code, name, flag (click to open picker), color, default currency, and inline add row. Editor sheet retired.
- **Person isActive flag** — archived persons hide by default via "Show inactive" header toggle; rendered dim. Net-worth aggregation still uses the separate "In NW" flag.
- **Sidebar collapse + resize** — auto-collapse to icons below 140 pt with hover labels, draggable divider, manual toggle button, last expanded width remembered.
- **Compare bar on Dashboard** — segmented "vs Previous / vs Year ago" drives the hero delta chip and KPI deltas.
- **Hover tooltips** on Trends total chart and Account history chart — vertical rule + point + annotation card with date and value.
- **Three-level breadcrumb** — `Screen › Filter › Snapshot` in TopBar, with active snapshot context where it matters.
- **Pre-cached snapshot totals** on lock for fast Dashboard / list rendering.
- **Backup verify counters** for Receivables and Receivable Values.
- **Two new app icon options**: **Vault** and **Strata**, alongside Ledgerly default and Classic.
- **Money Flow** view in the snapshot diff screen — Sankey-style visual showing how each account's value moved between two snapshots, with new and dropped accounts highlighted.

### Changed

- **App display name** is now **Ledgerly** everywhere user-facing (was "Finanace Tracker"). Bundle name fixed so the Dock tooltip and About panel match.
- **New default app icon** — gold L monogram with ledger lines on a dark squircle. Old icon kept as "Classic" option.
- **Hero on Dashboard** — embedded full-width sparkline below the figure (previously a separate panel), inline delta chip beside the number, eyebrow + compare bar on a single row, footnote moved below.
- **Hand cursor** appears on every clickable element — buttons, chips, theme toggle, share icon, slice rows, search results, and more.
- **⌘S** saves any open editor sheet; **Esc** closes; if there are unsaved changes Esc / Cancel prompts to save / discard / cancel.
- **Enter** triggers the primary button on every confirmation dialog and popup (delete, restore, lock, unlock, reset, save, etc.).
- **Snapshot editor** rows sort alphabetically by account name.
- **Search dropdown** results now open the relevant editor / detail sheet directly instead of just landing on the screen.
- **Active snapshot chip** is always pinned in the TopBar across all screens; placeholder shown when no snapshots exist yet.
- **Color-coded chart series** — Account history, Account detail trajectory, and Reports drilldown chart now use the asset-type's category color instead of single ink.
- **Click on a Dashboard donut slice** navigates to Breakdown filtered to that slice (no hover-redirect side-effect).
- **App icon picker tiles** redesigned: smaller previews, tighter spacing.
- **Backup file naming** moved to `Ledgerly-*` prefixes; legacy `FinanceTracker-*` files still listed and restorable.
- **Verify backup summary** is now a wrapping multi-line readable line with full label names instead of a truncated single line.
- **Settings → Security** panel redesigned with grouped row icons, status meta, and dedicated disclaimer; placed at the top of the right column.
- **Sidebar** shows the chosen app icon (instead of a static "L"); resize is now smooth (no jitter from per-frame disk writes).
- **Account editor** removes the unused "Group" field. Adds optional cost-basis input.
- **Empty-state screens** replace the lone "—" with a contextual SF Symbol illustration in a subtle disc.
- **KPI deltas** automatically switch label and reference between QoQ and YoY based on the Dashboard compare bar.

### Fixed

- Dock and Finder tooltip showing **FinanceTracker**; now reads **Ledgerly**.
- Sidebar resize jitter under live drag.
- Several confirmation dialogs missing default Enter shortcut.
- Snapshot editor: receivables and newly-added accounts not appearing in older snapshots — now auto-backfill on open (unlocked snapshots only).

---

## [2.4.0] - 2026-05-01

_Source: git `121f19c`_

### Added

- **`Receivable` / `ReceivableValue`** SwiftData models; **`Snapshot.receivableValues`** relationship.
- **Receivables** management UI: `ReceivablesView`, `ReceivableEditorSheet`.
- **CSV** and **PDF** export paths extended for receivable rows.
- **Dashboard** treatment for pending receivables (shown outside net worth).

### Changed

- **App** schema and navigation updated for receivables; **FinanceTrackerApp** SwiftData **`Schema`** includes new models.

---

## [2.3.0] - 2026-05-01

_Source: git `d593785`_

### Added

- **Quick Jump** (menu / command) wired through **SearchCommands** next to Find.
- **Quit-time backups**: **`QuitBackupDelegate`**, backup trigger on quit; **`BackupService`** extended; **FinanceTrackerApp** applies **pending restore** on launch when applicable.
- **`Account.groupName`** for grouping/organization.
- **`AccountAnalysis`** utility for snapshot-based account analytics.
- **`SnapshotPDFExporter`** for snapshot PDF export with revised layout.

### Changed

- **CurrencyConverter** extended for **illiquid** asset handling (alongside **`AppState`** / net-worth prefs).
- **Window appearance** tracked with theme changes (**`NSAppearance`**) alongside **`preferredColorScheme`**.
- **DashboardView**, **BreakdownView**, and related views refreshed for new behavior and UX.

---

## [2.2.0] - 2026-04-24

_Source: git `322a5e9`_

### Changed

- **Breakdown**: **`StackedBarsView`** replaces the previous treemap visualization; **`TreemapView` / `TreemapLayout`** removed.
- **BreakdownView**: cached data for performance, **search**, improved **empty** state.

### Removed

- Treemap implementation files (per refactor above).

---

## [2.1.0] - 2026-04-24

_Source: git `178ec15`_

### Added

- **`BackupService`**: automatic and **manual** database backups; listing and management surfaced in **Settings**.
- **Snapshot `notes`** field for free-form context on each snapshot.

### Changed

- **Dashboard**, **SnapshotEditor**, and related views updated for notes and backup-related flows; layout/responsiveness tweaks.

---

## [2.0.0] - 2026-04-23

_Source: git `5f5a44f`_

### Added

- **`AppCommands`**: menu commands for **Go** navigation, **New Snapshot**, **Find** / search focus, **Undo Delete** (via **`FocusedValues`**).
- **`UndoStash`** and restore pipeline for soft-delete recovery.
- **`DashboardPDFExporter`** for dashboard PDF export.
- **Caching** in **BreakdownView** and **DashboardView** for smoother updates.

### Changed

- **AppState**: **pending breakdown filter**, **global search** tick, and related navigation state.
- Main app file consolidated; older **FinanceTrackerApp** layout replaced in favor of command-driven structure.

### Removed

- **`DistributionCard`**, **`HeadlineCard`** (superseded by newer dashboard pieces).

---

## [1.1.0] - 2026-04-22

_Source: git `0f8b42c`_

### Added

- **Custom fonts**: Geist, Geist Mono, Instrument Serif (registration + asset bundle).
- **Formatters**: compact currency and grouped integer helpers.

### Changed

- **RootView**, **BreakdownView**, **DashboardView**, **AccountsView**, **AssetTypesView** — layout, headers/tables, and styling updates.

---

## [1.0.0] - 2026-04-21

_Sources: git `adcd0e7`, `2c18486`, `b5d29a5`_

### Added

- **Initial codebase** — Finance Tracker macOS app (SwiftUI/SwiftData).
- **Marketing / docs**: **`V 1.0.0`** first-release marker; **README** updated for **FinanceTracker (Ledgerly)** positioning and feature overview (multi-person, multi-currency, snapshots, exports, etc.).

---

## Repository note

These sections were **backfilled from `git log`** (no **`git tags`** in-repo at authoring time). **2.0.0–2.4.0** are **sequential semver slices** of that history so **2.4.0** matches the current Xcode **2.4** product line; only **1.0.0** was named in a commit message. If you retroactively tag releases, use e.g. **`v2.4.0`** consistent with the headings above.

## Versioning cheat sheet

When you ship:

1. Update **`MARKETING_VERSION`** / **`CURRENT_PROJECT_VERSION`** in Xcode.
2. Append a **`## [x.y.z] - YYYY-MM-DD`** section below **`[Unreleased]`** (Include **`_Source: git <sha>_`** if helpful).
3. Optionally **`git tag vX.Y.Z`**.
