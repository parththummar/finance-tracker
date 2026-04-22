import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TopBar: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var showingNewSnapshot = false
    @State private var pendingExport: PendingExport?

    private struct PendingExport: Identifiable {
        let id = UUID()
        let document: CSVDocument
        let defaultFilename: String
    }

    var body: some View {
        HStack(spacing: 12) {
            Picker("", selection: Binding(
                get: { app.displayCurrency },
                set: { app.displayCurrency = $0 }
            )) {
                ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .frame(width: 80)

            Picker("", selection: Binding(
                get: { app.activeSnapshotID ?? snapshots.first?.id ?? UUID() },
                set: { app.activeSnapshotID = $0 }
            )) {
                ForEach(snapshots) { Text($0.label).tag($0.id) }
            }
            .labelsHidden()
            .frame(width: 140)

            Button {
                showingNewSnapshot = true
            } label: {
                Label("New Snapshot", systemImage: "plus")
            }

            Menu {
                Button("Full history CSV") {
                    pendingExport = PendingExport(
                        document: CSVDocument(text: CSVExporter.flatAssetValues(snapshots: snapshots)),
                        defaultFilename: "finance_history_\(datestamp()).csv"
                    )
                }
                Button("Accounts list CSV") {
                    pendingExport = PendingExport(
                        document: CSVDocument(text: CSVExporter.accounts(accounts)),
                        defaultFilename: "finance_accounts_\(datestamp()).csv"
                    )
                }
                Button("Snapshot totals CSV") {
                    pendingExport = PendingExport(
                        document: CSVDocument(text: CSVExporter.snapshotTotals(snapshots: snapshots)),
                        defaultFilename: "finance_totals_\(datestamp()).csv"
                    )
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            Spacer()

            HStack(spacing: 6) {
                Text("Labels:").foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { app.labelMode },
                    set: { app.labelMode = $0 }
                )) {
                    Text("$").tag(LabelMode.dollar)
                    Text("%").tag(LabelMode.percent)
                    Text("Both").tag(LabelMode.both)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
            }

            if let snap = activeSnapshot, snap.isLocked {
                Label("Locked", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: Binding(
                get: { app.theme },
                set: { app.theme = $0 }
            )) {
                Image(systemName: "circle.lefthalf.filled").tag(AppTheme.system)
                Image(systemName: "sun.max.fill").tag(AppTheme.light)
                Image(systemName: "moon.fill").tag(AppTheme.dark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 120)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingNewSnapshot) {
            NewSnapshotSheet { created in
                app.activeSnapshotID = created.id
            }
        }
        .fileExporter(
            isPresented: Binding(
                get: { pendingExport != nil },
                set: { if !$0 { pendingExport = nil } }
            ),
            document: pendingExport?.document,
            contentType: .commaSeparatedText,
            defaultFilename: pendingExport?.defaultFilename ?? "export.csv"
        ) { _ in
            pendingExport = nil
        }
    }

    private func datestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var activeSnapshot: Snapshot? {
        guard let id = app.activeSnapshotID else { return snapshots.first }
        return snapshots.first { $0.id == id }
    }
}
