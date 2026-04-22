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
                exportPanel
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
