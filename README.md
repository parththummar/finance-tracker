# Finance Tracker — macOS

Offline personal wealth tracker. SwiftUI + SwiftData. Mac-only, no dev account, no cloud.

## First-Time Setup (15 min)

### 1. Install Xcode
- Mac App Store → search "Xcode" → install (free, ~15 GB).
- Open once, accept license.

### 2. Create Xcode Project
1. Xcode → **File → New → Project…**
2. Choose **macOS** tab → **App** → Next.
3. Fill in:
   - Product Name: `FinanceTracker`
   - Team: **None** (leave blank — no dev account needed)
   - Organization Identifier: `com.yourname`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData**
   - Include Tests: uncheck (optional)
4. Click Next → save project into this folder:
   `/Users/parth/Projects/Apps/Finance App`
5. Xcode creates `FinanceTracker/` subfolder with `FinanceTracker.xcodeproj`.

### 3. Drop in Scaffold Files
Files in `scaffold/` folder here map 1:1 into Xcode project folders.

```
scaffold/
  App/
    FinanceTrackerApp.swift       → replaces Xcode-generated App file
  Models/
    Person.swift
    Country.swift
    AssetType.swift
    Account.swift
    Snapshot.swift
    AssetValue.swift
    Enums.swift
    SeedData.swift
  ViewModels/
    AppState.swift
  Views/
    RootView.swift
    Dashboard/
      DashboardView.swift
      HeadlineCard.swift
      DistributionCard.swift
      NetWorthChart.swift
      MoversCard.swift
    Breakdown/
      BreakdownView.swift
    Snapshots/
      SnapshotListView.swift
      SnapshotEditorView.swift
    Manage/
      AccountsView.swift
      PeopleView.swift
      CountriesView.swift
      AssetTypesView.swift
    Settings/
      SettingsView.swift
    Shared/
      TopBar.swift
      Sidebar.swift
  Utils/
    CurrencyConverter.swift
    Formatters.swift
    Theme.swift
```

**Drop-in steps:**
1. In Finder, open `scaffold/` folder.
2. In Xcode, right-click `FinanceTracker` group → **Add Files to "FinanceTracker"…**
3. Select all folders inside `scaffold/` → uncheck "Copy items if needed" (files already in place), check **Create groups** → Add.
4. Delete Xcode's default `ContentView.swift` (our `RootView.swift` replaces it).
5. Replace Xcode's generated `FinanceTrackerApp.swift` contents with the one from `scaffold/App/`.

### 4. Run
- Xcode top bar → target = **My Mac** → press **⌘R**.
- App launches. Seed data (2 people, 2 countries, ~15 accounts, 2 sample snapshots) auto-loads first time.

### 5. Build Distributable .app
- Xcode → **Product → Archive**.
- Archives window opens → click **Distribute App** → **Copy App** → save to Desktop.
- Drag `.app` into `/Applications`.
- Right-click → **Open** (Gatekeeper bypass for unsigned app). One-time.

---

## Data Location

`~/Library/Containers/com.yourname.FinanceTracker/Data/Library/Application Support/default.store`

SQLite file. Back up this file = back up all data.

## Build Order Status

- [x] Scaffold — this commit
- [ ] Dashboard charts wired to real queries
- [ ] Snapshot editor grid with locking
- [ ] Breakdown treemap
- [ ] PDF export
- [ ] CSV export
- [ ] Reminder notifications
- [ ] Live exchange rate fetch (optional)

Scaffold = runnable skeleton. Screens render with seeded data but some widgets are placeholders. Fill in iteratively.
