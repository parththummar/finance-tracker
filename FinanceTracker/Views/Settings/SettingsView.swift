import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import Charts

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query(sort: \Account.name) private var accounts: [Account]
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = true

    @State private var pendingExport: PendingExport?
    @State private var confirmingReset = false
    @State private var backupMessage: String?
    @State private var categoryColorRefresh = UUID()
    @State private var backupsTick: Int = 0
    @State private var pendingRestore: URL?
    @State private var showingRestorePicker = false
    @State private var showingRelaunchAlert = false
    @State private var showingImportPicker = false
    @State private var importResult: String?
    @State private var importIsError: Bool = false
    @AppStorage("autoBackupEnabled")   private var autoBackupEnabled: Bool = true
    @AppStorage("autoBackupInterval")  private var autoBackupIntervalRaw: String = BackupInterval.weekly.rawValue
    @AppStorage("autoBackupKeep")      private var autoBackupKeep: Int = 10

    private struct PendingExport: Identifiable {
        let id = UUID()
        let document: CSVDocument
        let defaultFilename: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHero(eyebrow: "SYSTEM · PREFERENCES",
                     title: "Settings",
                     titleItalic: "— configuration")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)],
                alignment: .leading,
                spacing: 18
            ) {
                displayPanel
                remindersPanel
                categoryColorsPanel
                fxRatePanel
                autoBackupPanel
                exportPanel
                importPanel
                dataPanel
            }
        }
        .frame(maxWidth: 980, alignment: .leading)
        .confirmationDialog("Reset all data?",
                            isPresented: $confirmingReset,
                            titleVisibility: .visible) {
            Button("Delete all and re-seed", role: .destructive) {
                resetAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes every person, country, account, snapshot, and value. Re-seeds with sample data. Cannot be undone.")
        }
        .confirmationDialog(
            pendingRestore.map { "Restore from \($0.lastPathComponent)?" } ?? "",
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Restore & Relaunch", role: .destructive) {
                if let url = pendingRestore { performRestore(url) }
                pendingRestore = nil
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("Current data will be replaced. A safety copy of the current store is saved to the backups folder before restore. App will quit after restore — relaunch to load the restored data.")
        }
        .alert("Restore complete", isPresented: $showingRelaunchAlert) {
            Button("Quit Now") { NSApp.terminate(nil) }
        } message: {
            Text("The backup has been restored. Relaunch FinanceTracker to load the restored data.")
        }
        .fileImporter(
            isPresented: $showingRestorePicker,
            allowedContentTypes: [UTType(filenameExtension: "store") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                pendingRestore = url
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                performImport(url)
            }
        }
        .alert(importIsError ? "Import failed" : "Import complete",
               isPresented: Binding(
                get: { importResult != nil },
                set: { if !$0 { importResult = nil } })) {
            Button("OK") { importResult = nil }
        } message: {
            Text(importResult ?? "")
        }
        .fileExporter(
            isPresented: Binding(
                get: { pendingExport != nil },
                set: { if !$0 { pendingExport = nil } }
            ),
            document: pendingExport?.document,
            contentType: .commaSeparatedText,
            defaultFilename: pendingExport?.defaultFilename ?? "export.csv"
        ) { result in
            pendingExport = nil
            if case .failure(let err) = result {
                print("Export failed: \(err)")
            }
        }
    }

    // MARK: - Panels

    private var displayPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Display")
                VStack(spacing: 0) {
                    settingRow(label: "Default currency") {
                        SegControl(
                            options: Currency.allCases.map { ($0.rawValue, $0) },
                            selection: Binding(
                                get: { app.displayCurrency },
                                set: { app.displayCurrency = $0 }
                            )
                        )
                    }
                    Divider().overlay(Color.lLine)
                    settingRow(label: "Theme") {
                        SegControl(
                            options: [("● System", AppTheme.system),
                                      ("☼ Light", AppTheme.light),
                                      ("☾ Dark", AppTheme.dark)],
                            selection: Binding(
                                get: { app.theme },
                                set: { app.theme = $0 }
                            )
                        )
                    }
                    Divider().overlay(Color.lLine)
                    settingRow(label: "Label mode") {
                        SegControl(
                            options: [("$", LabelMode.dollar),
                                      ("%", LabelMode.percent),
                                      ("Both", LabelMode.both)],
                            selection: Binding(
                                get: { app.labelMode },
                                set: { app.labelMode = $0 }
                            )
                        )
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 4)
            }
        }
    }

    private var categoryColorsPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Category colors",
                          meta: "\(AssetCategory.allCases.count) categories")
                VStack(spacing: 0) {
                    ForEach(Array(AssetCategory.allCases.enumerated()), id: \.element) { idx, cat in
                        CategoryColorRow(category: cat)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
                        if idx < AssetCategory.allCases.count - 1 {
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
                .id(categoryColorRefresh)
                Divider().overlay(Color.lLine)
                HStack {
                    Text("Clear overrides, use built-in palette.")
                        .font(Typo.serifItalic(12))
                        .foregroundStyle(Color.lInk3)
                    Spacer()
                    GhostButton(action: {
                        for cat in AssetCategory.allCases {
                            CategoryColorStore.setHex(nil, for: cat)
                        }
                        categoryColorRefresh = UUID()
                    }) { Text("Reset defaults") }
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
            }
        }
    }

    private var autoBackupPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Auto backup", meta: autoBackupMeta)
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $autoBackupEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic backups")
                                .font(Typo.sans(12, weight: .medium))
                                .foregroundStyle(Color.lInk)
                            Text("Copies the database on launch if the interval has elapsed.")
                                .font(Typo.sans(11))
                                .foregroundStyle(Color.lInk3)
                        }
                    }
                    .toggleStyle(.switch)

                    HStack {
                        Text("Interval")
                            .font(Typo.sans(12, weight: .medium))
                            .foregroundStyle(Color.lInk)
                        Spacer()
                        SegControl<BackupInterval>(
                            options: BackupInterval.allCases.map { ($0.label, $0) },
                            selection: Binding(
                                get: { BackupInterval(rawValue: autoBackupIntervalRaw) ?? .weekly },
                                set: { autoBackupIntervalRaw = $0.rawValue }
                            )
                        )
                    }
                    .disabled(!autoBackupEnabled)
                    .opacity(autoBackupEnabled ? 1 : 0.5)

                    HStack {
                        Text("Keep last")
                            .font(Typo.sans(12, weight: .medium))
                            .foregroundStyle(Color.lInk)
                        Spacer()
                        Stepper(value: $autoBackupKeep, in: 1...50) {
                            Text("\(autoBackupKeep)")
                                .font(Typo.mono(12, weight: .semibold))
                                .foregroundStyle(Color.lInk)
                                .monospacedDigit()
                        }
                        .fixedSize()
                    }

                    Divider().overlay(Color.lLine)

                    HStack(spacing: 8) {
                        GhostButton(action: backupNow) {
                            HStack(spacing: 5) {
                                Image(systemName: "externaldrive.badge.plus").font(.system(size: 10, weight: .bold))
                                Text("Backup now")
                            }
                        }
                        GhostButton(action: { showingRestorePicker = true }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.counterclockwise").font(.system(size: 10, weight: .bold))
                                Text("Restore from file…")
                            }
                        }
                        Spacer()
                        if let dir = BackupService.backupsDir() {
                            GhostButton(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([dir])
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "folder").font(.system(size: 10, weight: .bold))
                                    Text("Reveal folder")
                                }
                            }
                        }
                    }

                    backupList
                }
                .padding(18)
            }
        }
    }

    private var autoBackupMeta: String {
        if let last = BackupService.lastAutoBackupDate() {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            return "last auto: \(f.localizedString(for: last, relativeTo: Date()))"
        }
        return autoBackupEnabled ? "no auto backup yet" : "disabled"
    }

    @ViewBuilder
    private var backupList: some View {
        let items = BackupService.list()
        if items.isEmpty {
            Text("No backups yet. Automatic backups will appear here after the app launches past the interval.")
                .font(Typo.serifItalic(11))
                .foregroundStyle(Color.lInk3)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("RECENT BACKUPS")
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                    Spacer()
                    Text("\(items.count) total")
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                }
                .padding(.bottom, 6)
                ForEach(items.prefix(6)) { b in
                    backupRow(b)
                    Divider().overlay(Color.lLine)
                }
            }
            .id(backupsTick)
        }
    }

    private func backupRow(_ b: BackupService.BackupFile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: b.kind == .auto ? "clock.arrow.circlepath" : "externaldrive")
                .font(.system(size: 11))
                .foregroundStyle(Color.lInk3)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(b.name)
                    .font(Typo.mono(11, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(b.date, format: .dateTime.year().month().day().hour().minute())
                        .font(Typo.sans(10.5))
                        .foregroundStyle(Color.lInk3)
                    Text("·").foregroundStyle(Color.lInk4)
                    Text(byteString(b.size))
                        .font(Typo.mono(10))
                        .foregroundStyle(Color.lInk3)
                    Text(b.kind == .auto ? "AUTO" : b.kind == .manual ? "MANUAL" : "")
                        .font(Typo.eyebrow).tracking(1.0)
                        .foregroundStyle(Color.lInk3)
                }
            }
            Spacer(minLength: 8)
            GhostButton(action: { pendingRestore = b.url }) { Text("Restore") }
        }
        .padding(.vertical, 6)
    }

    private func backupNow() {
        if let url = BackupService.backupNow() {
            backupMessage = "Backup saved: \(url.lastPathComponent)"
            backupsTick &+= 1
        } else {
            backupMessage = "Backup failed."
        }
    }

    private func performRestore(_ url: URL) {
        do {
            try context.save()
            try BackupService.restore(from: url)
            backupMessage = "Restored from \(url.lastPathComponent)."
            backupsTick &+= 1
            showingRelaunchAlert = true
        } catch {
            backupMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }

    private var exportPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Export")
                VStack(alignment: .leading, spacing: 10) {
                    exportRow(
                        icon: "tablecells",
                        title: "Full history",
                        subtitle: "Flat · all snapshots × accounts"
                    ) {
                        let text = CSVExporter.flatAssetValues(snapshots: snapshots)
                        pendingExport = PendingExport(
                            document: CSVDocument(text: text),
                            defaultFilename: "finance_history_\(datestamp()).csv"
                        )
                    }
                    exportRow(
                        icon: "creditcard",
                        title: "Accounts list",
                        subtitle: "One row per account"
                    ) {
                        let text = CSVExporter.accounts(accounts)
                        pendingExport = PendingExport(
                            document: CSVDocument(text: text),
                            defaultFilename: "finance_accounts_\(datestamp()).csv"
                        )
                    }
                    exportRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Snapshot totals",
                        subtitle: "One row per snapshot"
                    ) {
                        let text = CSVExporter.snapshotTotals(snapshots: snapshots)
                        pendingExport = PendingExport(
                            document: CSVDocument(text: text),
                            defaultFilename: "finance_totals_\(datestamp()).csv"
                        )
                    }
                    Divider().overlay(Color.lLine)
                    exportRow(
                        icon: "doc.richtext",
                        title: "Dashboard PDF",
                        subtitle: "Headline, distributions, chart, movers"
                    ) { exportDashboardPDF() }
                }
                .padding(18)
            }
        }
    }

    private var dataPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Data")
                VStack(alignment: .leading, spacing: 12) {
                    if let url = storeURL() {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("DATABASE")
                                .font(Typo.eyebrow).tracking(1.2)
                                .foregroundStyle(Color.lInk3)
                            Text(url.path)
                                .font(Typo.mono(10.5))
                                .foregroundStyle(Color.lInk2)
                                .textSelection(.enabled)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        HStack(spacing: 8) {
                            GhostButton(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "folder").font(.system(size: 10, weight: .bold))
                                    Text("Reveal")
                                }
                            }
                            GhostButton(action: backupDatabase) {
                                HStack(spacing: 5) {
                                    Image(systemName: "externaldrive.badge.plus").font(.system(size: 10, weight: .bold))
                                    Text("Backup")
                                }
                            }
                            Spacer()
                            GhostButton(action: { confirmingReset = true }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                                    Text("Reset…")
                                }
                            }
                        }
                    }
                    if let msg = backupMessage {
                        Text(msg)
                            .font(Typo.serifItalic(12))
                            .foregroundStyle(Color.lInk3)
                    }
                }
                .padding(18)
            }
        }
    }

    private var fxRatePanel: some View {
        FXRateHistoryPanel(snapshots: snapshots)
    }

    private var remindersPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Reminders")
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: Binding(
                        get: { reminderEnabled },
                        set: { newValue in
                            reminderEnabled = newValue
                            ReminderScheduler.applyPreference(enabled: newValue, context: context)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quarterly update reminder")
                                .font(Typo.sans(12, weight: .medium))
                                .foregroundStyle(Color.lInk)
                            Text("Fires when last snapshot is older than 90 days.")
                                .font(Typo.sans(11))
                                .foregroundStyle(Color.lInk3)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func settingRow<Control: View>(label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(label)
                .font(Typo.sans(12, weight: .medium))
                .foregroundStyle(Color.lInk)
            Spacer()
            control()
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var importPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Import", meta: "CSV · full history")
                VStack(alignment: .leading, spacing: 10) {
                    Text("Merges the Full history CSV export back into the local store. Existing snapshots, accounts, people, countries, and types are matched by name/date and not duplicated.")
                        .font(Typo.sans(11.5))
                        .foregroundStyle(Color.lInk3)
                        .lineSpacing(2)
                    exportRow(
                        icon: "square.and.arrow.down",
                        title: "Import full history CSV…",
                        subtitle: "Reverse of the Full history export"
                    ) { showingImportPicker = true }
                }
                .padding(18)
            }
        }
    }

    @MainActor
    private func performImport(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let report = try CSVImporter.importFlatHistory(csv: text, context: context)
            importIsError = false
            importResult = report.summary
        } catch {
            importIsError = true
            importResult = error.localizedDescription
        }
    }

    private func exportRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.lInk2)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.sans(12.5, weight: .medium))
                    .foregroundStyle(Color.lInk)
                Text(subtitle)
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lInk3)
            }
            Spacer()
            GhostButton(action: action) { Text("Export") }
        }
    }

    // MARK: - Helpers

    private func datestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func storeURL() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return nil }
        return appSupport.appendingPathComponent("default.store")
    }

    private func backupDatabase() {
        try? context.save()
        guard let src = storeURL(), FileManager.default.fileExists(atPath: src.path) else {
            backupMessage = "Database file not found."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Backup Database"
        panel.nameFieldStringValue = "FinanceTracker-backup-\(datestamp()).store"
        panel.allowedContentTypes = [UTType(filenameExtension: "store") ?? .data]
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: src, to: dest)
            let wal = src.appendingPathExtension("wal")
            let shm = src.appendingPathExtension("shm")
            if FileManager.default.fileExists(atPath: wal.path) {
                try? FileManager.default.copyItem(at: wal, to: dest.appendingPathExtension("wal"))
            }
            if FileManager.default.fileExists(atPath: shm.path) {
                try? FileManager.default.copyItem(at: shm, to: dest.appendingPathExtension("shm"))
            }
            backupMessage = "Backed up to \(dest.lastPathComponent)."
        } catch {
            backupMessage = "Backup failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func exportDashboardPDF() {
        let result = DashboardPDFExporter.export(
            snapshots: Array(snapshots),
            displayCurrency: app.displayCurrency,
            activeSnapshotID: app.activeSnapshotID,
            theme: app.theme
        )
        switch result {
        case .exported(let msg): backupMessage = msg
        case .failed(let msg):   backupMessage = msg
        case .cancelled:         break
        }
    }

    private func resetAllData() {
        deleteAll(AssetValue.self)
        deleteAll(Snapshot.self)
        deleteAll(Account.self)
        deleteAll(AssetType.self)
        deleteAll(Country.self)
        deleteAll(Person.self)
        deleteAll(ExchangeRateHistory.self)
        try? context.save()
        SeedData.seedIfEmpty(context: context)
        try? context.save()
        backupMessage = "Reset complete. Sample data re-seeded."
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let fd = FetchDescriptor<T>()
        if let items = try? context.fetch(fd) {
            for item in items { context.delete(item) }
        }
    }
}

private struct CategoryColorRow: View {
    let category: AssetCategory
    @State private var color: Color = .gray

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.lLine, lineWidth: 0.5))
            Text(category.rawValue)
                .font(Typo.sans(12.5, weight: .medium))
                .foregroundStyle(Color.lInk)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { color },
                set: { newColor in
                    color = newColor
                    CategoryColorStore.setHex(newColor.toHex(), for: category)
                }
            ), supportsOpacity: false)
            .labelsHidden()
        }
        .onAppear { color = Palette.color(for: category) }
    }
}
