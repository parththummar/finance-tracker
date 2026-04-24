# FinanceTracker (Ledgerly)

Offline personal wealth tracker for macOS. SwiftUI + SwiftData. 100% local — no cloud, no account, no dev license required.

Multi-person, multi-country, multi-currency (USD / INR). Snapshot-based history. Charts-first UI.

---

## Features

### Data Model
- Entities: Person, Country, AssetType, Account, Snapshot, AssetValue, ExchangeRateHistory.
- 6 asset categories: Cash, Investment, Retirement, Crypto, Insurance, Debt.
- Cascade-aware deletes with count warnings.

### Snapshots
- Date-based point-in-time net worth records (no quarter logic).
- Future dates blocked; 7-day minimum gap between snapshots.
- **Per-snapshot USD↔INR rate** locked at creation; historical rates never overwritten.
- Copy-previous-values toggle on create; prefills all active accounts.
- Lock / Unlock states. Locked snapshots read-only.
- Delete with cascade confirmation.

### Snapshot Editor
- Inline edit native value per account.
- **PREV** + **Δ** columns (colored green/red) vs previous snapshot.
- **Live TOTAL footer** in display currency — updates as you type. Shows prev total, delta, current total.
- **Save Draft** with green ✓ toast confirmation.
- **Delete Snapshot** button.
- Zebra striping.

### Live FX Fetch
- One-click USD→INR fetch from frankfurter.app (no API key).
- Historical date support — past snapshots pull rate for their actual date.
- Never touches locked snapshots.

### Dashboard
- Headline card: current net worth, QoQ/YoY delta chips, sparkline.
- Three distribution cards (By Person, By Country, By Category) — each toggles donut ↔ bar independently. Preference persists.
- Net worth chart: line / stacked-area toggle across all snapshots.
- Movers card: top 5 gainers + decliners between last two snapshots.
- Display currency picker (USD/INR) — recalculates whole UI.
- Label mode: $ / % / Both.

### Breakdown + Treemap
- Squarified treemap grouped by Category / Person / Country / Type.
- Click parent tile → filter. Click account tile → opens Account History chart.
- Filter chips with clear-all.
- Accounts table below with percent-of-total column.

### Account History Chart
- Right-click, double-click, chart icon, or ⋯ menu on any account row.
- Line + area chart of that account's value over all snapshots.
- Native ↔ display currency toggle (hidden if same).
- Total change $ + % since first snapshot.
- Full snapshot table with per-row delta.

### Color Customization
- Per-person, per-country, per-category (via Settings).
- Applied everywhere: charts, treemap, manage-tables color swatches.
- Reset-to-defaults for categories.

### Management (CRUD)
- People, Countries, Asset Types, Accounts.
- Retire / Reactivate accounts (retired excluded from new snapshots; history preserved).
- Show-retired toggle in accounts list.
- Cascade-aware delete warnings.

### CSV Export
- **Full history** — flat (snapshot × account): person, country, type, category, native + USD + INR.
- **Accounts list**.
- **Snapshot totals** — one row per snapshot.
- RFC 4180 escaping.

### PDF Export
- Dashboard → PDF (ImageRenderer + CGContext) via save panel.

### Reminders
- Local macOS notification when latest snapshot is >90 days old.
- Scheduled at launch. Toggleable in Settings.

### Settings
- Display prefs: currency, theme (System/Light/Dark), label mode.
- Category colors with reset.
- CSV + PDF export.
- **Data**: show database path, Reveal in Finder, Backup database (copies .store + wal + shm), Reset all data (wipe + re-seed).
- Reminder toggle.

### Shell
- NavigationSplitView sidebar + detail.
- Top bar: currency, snapshot picker, New Snapshot, Export menu, label mode, theme toggle.
- Min window 1100×1000.
- First-launch seed: 2 people, 2 countries, 13 asset types, 15 accounts, 2 sample snapshots.

### Custom App Icon
- Generated via Swift script (`scripts/GenerateIcon.swift`). Squircle, warm-ink gradient, green sparkline, italic serif L, dot + glow. All sizes 16–1024px.

---

## Project Layout

All source lives in the Xcode project at `FinanceTracker/FinanceTracker/`:

```
FinanceTracker/FinanceTracker/
  FinanceTrackerApp.swift
  App/                FinanceTrackerApp (entry, ModelContainer, reminder check)
  Models/             Person, Country, AssetType, Account, Snapshot, AssetValue,
                      Enums, SeedData
  ViewModels/         AppState
  Views/
    RootView
    Dashboard/        DashboardView, HeadlineCard, DistributionCard,
                      NetWorthChart, MoversCard
    Breakdown/        BreakdownView, StackedBarsView
    Snapshots/        SnapshotListView, SnapshotEditorView, NewSnapshotSheet
    Manage/           AccountsView, AccountEditorSheet, AccountHistoryView,
                      PeopleView, PersonEditorSheet,
                      CountriesView, CountryEditorSheet,
                      AssetTypesView, AssetTypeEditorSheet
    Settings/         SettingsView
    Shared/           TopBar, Sidebar
  Utils/              CurrencyConverter, CSVExporter, FXService, Formatters,
                      ReminderScheduler, Theme
  Assets.xcassets/    AppIcon + colors
scripts/
  GenerateIcon.swift  Programmatic app-icon generator
```

---

## Run From Source

### 1. Install Xcode
Mac App Store → search "Xcode" → install (free, ~15 GB). Open once, accept license.

### 2. Open Project
Open `FinanceTracker/FinanceTracker.xcodeproj` in Xcode.

### 3. Required Capabilities (Signing & Capabilities tab)
1. **Signing** → Team: **None** (no dev account needed — runs locally unsigned).
2. **App Sandbox** → **File Access** → **User Selected File** → **Read/Write** (CSV / PDF export + backup).
3. **App Sandbox** → **Network** → check **Outgoing Connections (Client)** (live FX fetch).
4. No notification entitlement needed — local notifications work unsigned.

### 4. Generate App Icon (one-time, or after icon tweaks)
```bash
swift "scripts/GenerateIcon.swift" "FinanceTracker/FinanceTracker/Assets.xcassets/AppIcon.appiconset"
```
Xcode → Assets.xcassets → AppIcon → verify 10 slots filled.

### 5. Run
- Scheme target → **My Mac** → **⌘R**.
- Seed data (2 people, 2 countries, 13 asset types, 15 accounts, 2 snapshots) loads on first launch if DB empty.

---

## Data Location

```
~/Library/Containers/com.yourname.FinanceTracker/Data/Library/Application Support/default.store
```

SQLite file. Backup that file (or use Settings → **Backup database**) = full backup.

---

## Distribution (share with friends, no dev account)

### Build Release .app
1. Edit Scheme → Run → **Build Configuration: Release**.
2. Target → Build Settings → **Architectures** → `Standard (arm64, x86_64)` for universal build.
3. **Product → Archive** → Organizer → **Distribute App** → **Copy App** → save to Desktop.

### Wrap as DMG

**Quick (built-in hdiutil):**
```bash
cd ~/Desktop
mkdir FinanceTracker-dmg
cp -R FinanceTracker.app FinanceTracker-dmg/
ln -s /Applications FinanceTracker-dmg/Applications
hdiutil create -volname "FinanceTracker" -srcfolder FinanceTracker-dmg -ov -format UDZO FinanceTracker.dmg
rm -rf FinanceTracker-dmg
```

**Pretty (create-dmg):**
```bash
brew install create-dmg
create-dmg --volname "FinanceTracker" --window-size 500 300 \
  --icon "FinanceTracker.app" 120 120 \
  --app-drop-link 380 120 \
  FinanceTracker.dmg FinanceTracker.app
```

### Friend's First Launch (unsigned = Gatekeeper warning)
1. Open DMG → drag app to Applications.
2. **Right-click app → Open** → confirm dialog.
3. If still blocked (Sequoia+): **System Settings → Privacy & Security** → scroll to "was blocked" → **Open Anyway**.
4. CLI fallback: `xattr -cr /Applications/FinanceTracker.app`.

Unsigned path is free but shows "unidentified developer" warning. Clean distribution requires $99/yr Apple Developer account + notarization.

---

## Stack Notes

- **SwiftData** on SQLite. Adding optional attributes auto-migrates; schema versioning not wired.
- **@AppStorage** for UI prefs; **UserDefaults** for category color overrides + reminder toggle.
- **Swift Charts** for donut (SectorMark), line, area, bar.
- **Squarified treemap** (Bruls/Huijsen/van Wijk 2000).
- **frankfurter.app** for free FX (no key, historical endpoint `/YYYY-MM-DD`).
- **UNUserNotificationCenter** for local reminders.
- **ImageRenderer + CGContext** for PDF export.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Can't display save panel" crash | Sandbox entitlement must be **User Selected File Read/Write**, not Read-Only |
| FX fetch fails silently | Enable **Outgoing Connections (Client)** in Sandbox |
| Notification never appears | System Settings → Notifications → FinanceTracker → allow |
| App icon blank | Rerun `swift scripts/GenerateIcon.swift <path>` and verify Assets.xcassets populated |
| `escape` main-actor isolation error | Mark `CSVExporter.escape` / `encode` `nonisolated` (already done) |
