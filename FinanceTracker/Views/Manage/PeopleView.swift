import SwiftUI
import SwiftData

struct PeopleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @State private var editing: Person?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Person?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("People").font(.title2.bold())
                Spacer()
                Button { creatingNew = true } label: { Label("New Person", systemImage: "plus") }
            }

            Table(people) {
                TableColumn("Color") { p in
                    Circle()
                        .fill(Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                }
                .width(50)
                TableColumn("Name") { p in Text(p.name) }
                TableColumn("Accounts") { p in Text("\(p.accounts.count)") }
                TableColumn("") { p in
                    HStack(spacing: 6) {
                        Button("Edit") { editing = p }
                        Button("Delete…", role: .destructive) { confirmDelete = p }
                    }
                }
            }
        }
        .padding(16)
        .sheet(item: $editing) { PersonEditorSheet(existing: $0) }
        .sheet(isPresented: $creatingNew) { PersonEditorSheet(existing: nil) }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let p = confirmDelete { context.delete(p); try? context.save() }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Person, all \(confirmDelete?.accounts.count ?? 0) accounts, and all historical snapshot values will be deleted. Cannot be undone.")
        }
    }
}
