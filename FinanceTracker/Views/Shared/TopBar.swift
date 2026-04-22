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
        HStack(spacing: 10) {
            crumbs

            Spacer(minLength: 12)

            if !snapshots.isEmpty {
                snapshotChip
            }

            SegControl<Currency>(
                options: Currency.allCases.map { (label: $0.rawValue, value: $0) },
                selection: Binding(
                    get: { app.displayCurrency },
                    set: { app.displayCurrency = $0 }
                )
            )

            SegControl<AppTheme>(
                options: [("●", .system), ("☼", .light), ("☾", .dark)],
                selection: Binding(
                    get: { app.theme },
                    set: { app.theme = $0 }
                )
            )

            Menu {
                Button("Full history CSV") { exportHistory() }
                Button("Accounts list CSV") { exportAccounts() }
                Button("Snapshot totals CSV") { exportTotals() }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lInk2)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Color.lLine, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            PrimaryButton(action: { showingNewSnapshot = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Snapshot")
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color.lBg)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
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

    private var crumbs: some View {
        HStack(spacing: 6) {
            Text("Ledgerly")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk3)
            Text("/")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk4)
            Text(screenTitle)
                .font(Typo.sans(12, weight: .semibold))
                .foregroundStyle(Color.lInk)
        }
    }

    private var snapshotChip: some View {
        HStack(spacing: 6) {
            Text("As of")
                .font(Typo.mono(10.5))
                .foregroundStyle(Color.lInk3)
            Menu {
                ForEach(snapshots) { s in
                    Button(s.label) { app.activeSnapshotID = s.id }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(activeLabel)
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.lInk3)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
    }

    private var activeLabel: String {
        if let id = app.activeSnapshotID, let s = snapshots.first(where: { $0.id == id }) {
            return s.label
        }
        return snapshots.first?.label ?? "—"
    }

    private var screenTitle: String {
        switch app.selectedScreen {
        case .dashboard:  return "Net Worth"
        case .breakdown:  return "Allocation"
        case .snapshots:  return "Historical"
        case .accounts:   return "All Assets"
        case .people:     return "By Person"
        case .countries:  return "By Country"
        case .assetTypes: return "By Asset Type"
        case .settings:   return "Settings"
        }
    }

    private func datestamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    private func exportHistory() {
        pendingExport = PendingExport(
            document: CSVDocument(text: CSVExporter.flatAssetValues(snapshots: snapshots)),
            defaultFilename: "finance_history_\(datestamp()).csv"
        )
    }
    private func exportAccounts() {
        pendingExport = PendingExport(
            document: CSVDocument(text: CSVExporter.accounts(accounts)),
            defaultFilename: "finance_accounts_\(datestamp()).csv"
        )
    }
    private func exportTotals() {
        pendingExport = PendingExport(
            document: CSVDocument(text: CSVExporter.snapshotTotals(snapshots: snapshots)),
            defaultFilename: "finance_totals_\(datestamp()).csv"
        )
    }
}
