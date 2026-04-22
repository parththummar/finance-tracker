import SwiftUI
import SwiftData

struct CountriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Country.code) private var countries: [Country]
    @State private var editing: Country?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Country?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Countries").font(.title2.bold())
                Spacer()
                Button { creatingNew = true } label: { Label("New Country", systemImage: "plus") }
            }

            Table(countries) {
                TableColumn("Color") { c in
                    Circle()
                        .fill(Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                }
                .width(50)
                TableColumn("Flag") { c in Text(c.flag) }
                TableColumn("Code") { c in Text(c.code) }
                TableColumn("Name") { c in Text(c.name) }
                TableColumn("Default Ccy") { c in Text(c.defaultCurrency.rawValue) }
                TableColumn("Accounts") { c in Text("\(c.accounts.count)") }
                TableColumn("") { c in
                    HStack(spacing: 6) {
                        Button("Edit") { editing = c }
                        Button("Delete…", role: .destructive) { confirmDelete = c }
                    }
                }
            }
        }
        .padding(16)
        .sheet(item: $editing) { CountryEditorSheet(existing: $0) }
        .sheet(isPresented: $creatingNew) { CountryEditorSheet(existing: nil) }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let c = confirmDelete { context.delete(c); try? context.save() }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Country, all \(confirmDelete?.accounts.count ?? 0) accounts in this country, and their historical values will be deleted. Cannot be undone.")
        }
    }
}
