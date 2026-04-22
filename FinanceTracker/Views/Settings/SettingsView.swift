import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

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

    private struct PendingExport: Identifiable {
        let id = UUID()
        let document: CSVDocument
        let defaultFilename: String
    }

    var body: some View {
        Form {
            Section("Display") {
                Picker("Default currency", selection: Binding(
                    get: { app.displayCurrency }, set: { app.displayCurrency = $0 }
                )) {
                    ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Theme", selection: Binding(
                    get: { app.theme }, set: { app.theme = $0 }
                )) {
                    Text("System").tag(AppTheme.system)
                    Text("Light").tag(AppTheme.light)
                    Text("Dark").tag(AppTheme.dark)
                }
                Picker("Label mode", selection: Binding(
                    get: { app.labelMode }, set: { app.labelMode = $0 }
                )) {
                    Text("Dollar").tag(LabelMode.dollar)
                    Text("Percent").tag(LabelMode.percent)
                    Text("Both").tag(LabelMode.both)
                }
            }

            Section("Category Colors") {
                ForEach(AssetCategory.allCases) { cat in
                    CategoryColorRow(category: cat)
                }
                .id(categoryColorRefresh)
                Button("Reset to defaults") {
                    for cat in AssetCategory.allCases {
                        CategoryColorStore.setHex(nil, for: cat)
                    }
                    categoryColorRefresh = UUID()
                }
                .help("Clear overrides and use built-in palette.")
            }

            Section("Export CSV") {
                Button {
                    let text = CSVExporter.flatAssetValues(snapshots: snapshots)
                    pendingExport = PendingExport(
                        document: CSVDocument(text: text),
                        defaultFilename: "finance_history_\(datestamp()).csv"
                    )
                } label: { Label("Full history (flat, all snapshots × accounts)", systemImage: "tablecells") }

                Button {
                    let text = CSVExporter.accounts(accounts)
                    pendingExport = PendingExport(
                        document: CSVDocument(text: text),
                        defaultFilename: "finance_accounts_\(datestamp()).csv"
                    )
                } label: { Label("Accounts list", systemImage: "creditcard") }

                Button {
                    let text = CSVExporter.snapshotTotals(snapshots: snapshots)
                    pendingExport = PendingExport(
                        document: CSVDocument(text: text),
                        defaultFilename: "finance_totals_\(datestamp()).csv"
                    )
                } label: { Label("Snapshot totals (one row per snapshot)", systemImage: "chart.line.uptrend.xyaxis") }
            }

            Section("Export PDF") {
                Button {
                    exportDashboardPDF()
                } label: { Label("Export dashboard as PDF", systemImage: "doc.richtext") }
                Text("Renders current dashboard (headline, distributions, net worth chart, movers).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Data") {
                if let url = storeURL() {
                    HStack {
                        Text("Database:")
                        Text(url.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: { Label("Reveal in Finder", systemImage: "folder") }
                }
                Button {
                    backupDatabase()
                } label: { Label("Backup database…", systemImage: "externaldrive.badge.plus") }
                Button(role: .destructive) {
                    confirmingReset = true
                } label: { Label("Reset all data…", systemImage: "trash") }

                if let msg = backupMessage {
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Reminders") {
                Toggle("Quarterly update reminder", isOn: Binding(
                    get: { reminderEnabled },
                    set: { newValue in
                        reminderEnabled = newValue
                        ReminderScheduler.applyPreference(enabled: newValue, context: context)
                    }
                ))
                Text("Fires when last snapshot is older than 90 days.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: 600)
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
        let view = DashboardView()
            .environmentObject(app)
            .modelContainer(context.container)
            .frame(width: 1000, height: 1600)
            .padding(16)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = .init(width: 1000, height: 1600)

        let panel = NSSavePanel()
        panel.title = "Export Dashboard PDF"
        panel.nameFieldStringValue = "FinanceTracker-dashboard-\(datestamp()).pdf"
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let dest = panel.url else { return }

        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: dest as CFURL),
                  let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else {
                backupMessage = "PDF setup failed."
                return
            }
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        backupMessage = "Exported \(dest.lastPathComponent)."
    }

    private func resetAllData() {
        let types: [any PersistentModel.Type] = [
            AssetValue.self, Snapshot.self, Account.self,
            AssetType.self, Country.self, Person.self, ExchangeRateHistory.self
        ]
        for t in types {
            try? context.delete(model: t)
        }
        try? context.save()
        SeedData.seedIfEmpty(context: context)
        try? context.save()
        backupMessage = "Reset complete. Sample data re-seeded."
    }
}

private struct CategoryColorRow: View {
    let category: AssetCategory
    @State private var color: Color = .gray

    var body: some View {
        ColorPicker(category.rawValue, selection: Binding(
            get: { color },
            set: { newColor in
                color = newColor
                CategoryColorStore.setHex(newColor.toHex(), for: category)
            }
        ), supportsOpacity: false)
        .onAppear {
            color = Palette.color(for: category)
        }
    }
}

