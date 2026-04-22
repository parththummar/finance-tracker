import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var editing: Account?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Account?
    @State private var showInactive: Bool = true
    @State private var historyAccount: Account?
    @State private var selection: Account.ID?

    private var visible: [Account] {
        showInactive ? accounts : accounts.filter(\.isActive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accounts").font(.title2.bold())
                Spacer()
                Toggle("Show retired", isOn: $showInactive)
                Button {
                    creatingNew = true
                } label: { Label("New Account", systemImage: "plus") }
            }

            Table(visible, selection: $selection) {
                TableColumn("Name") { a in Text(a.name) }
                TableColumn("Person") { a in Text(a.person?.name ?? "—") }
                TableColumn("Country") { a in Text("\(a.country?.flag ?? "") \(a.country?.code ?? "")") }
                TableColumn("Type") { a in Text(a.assetType?.name ?? "—") }
                TableColumn("Ccy") { a in Text(a.nativeCurrency.rawValue) }
                TableColumn("Status") { a in Text(a.isActive ? "Active" : "Retired") }
                TableColumn("") { a in
                    HStack(spacing: 6) {
                        Button { historyAccount = a } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                        }
                        .help("Show history chart")
                        Button("Edit") { editing = a }
                        Menu {
                            Button("Show History") { historyAccount = a }
                            Button(a.isActive ? "Retire" : "Reactivate") {
                                a.isActive.toggle()
                                try? context.save()
                            }
                            Button("Delete…", role: .destructive) {
                                confirmDelete = a
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
            .contextMenu(forSelectionType: Account.ID.self) { ids in
                if let id = ids.first, let a = accounts.first(where: { $0.id == id }) {
                    Button("Show History") { historyAccount = a }
                    Button("Edit") { editing = a }
                }
            } primaryAction: { ids in
                if let id = ids.first, let a = accounts.first(where: { $0.id == id }) {
                    historyAccount = a
                }
            }
        }
        .padding(16)
        .sheet(item: $editing) { AccountEditorSheet(existing: $0) }
        .sheet(isPresented: $creatingNew) { AccountEditorSheet(existing: nil) }
        .sheet(item: $historyAccount) { AccountHistoryView(account: $0) }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let a = confirmDelete { context.delete(a); try? context.save() }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Account and all \(confirmDelete?.values.count ?? 0) historical values across snapshots will be deleted. Cannot be undone.")
        }
    }
}
