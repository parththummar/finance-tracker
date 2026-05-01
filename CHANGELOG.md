# Changelog

All notable changes to **FinanceTracker** (Ledgerly) are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Version headings match **semver** derived from **`git log`** (newest-first). Xcode **`MARKETING_VERSION`** reads the same numeric line (e.g. `2.4` ≡ `2.4.0`); **`CURRENT_PROJECT_VERSION`** is the **build**.

## [Unreleased]

### Planned

Nothing listed yet — add bullets while developing, then move them under a dated version when you ship.

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
