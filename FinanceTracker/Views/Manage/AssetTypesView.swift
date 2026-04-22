import SwiftUI
import SwiftData

struct AssetTypesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AssetType.name) private var types: [AssetType]
    @State private var editing: AssetType?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: AssetType?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Asset Types").font(.title2.bold())
                Spacer()
                Button { creatingNew = true } label: { Label("New Type", systemImage: "plus") }
            }

            Table(types) {
                TableColumn("Color") { t in
                    Circle()
                        .fill(Palette.color(for: t.category))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                }
                .width(50)
                TableColumn("Name") { t in Text(t.name) }
                TableColumn("Category") { t in Text(t.category.rawValue) }
                TableColumn("Accounts") { t in Text("\(t.accounts.count)") }
                TableColumn("") { t in
                    HStack(spacing: 6) {
                        Button("Edit") { editing = t }
                        Button("Delete…", role: .destructive) { confirmDelete = t }
                    }
                }
            }
        }
        .padding(16)
        .sheet(item: $editing) { AssetTypeEditorSheet(existing: $0) }
        .sheet(isPresented: $creatingNew) { AssetTypeEditorSheet(existing: nil) }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let t = confirmDelete { context.delete(t); try? context.save() }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Asset type, all \(confirmDelete?.accounts.count ?? 0) accounts using it, and their historical values will be deleted. Cannot be undone.")
        }
    }
}
