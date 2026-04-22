import SwiftUI
import SwiftData

struct AssetTypeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let existing: AssetType?

    @State private var name: String = ""
    @State private var category: AssetCategory = .cash
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Asset Type" : "Edit Asset Type").font(Typo.serifNum(24))
            Form {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(AssetCategory.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .formStyle(.grouped)

            if let err = errorMessage {
                Text(err).foregroundStyle(.red).font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button { save() } label: { Label("Save", systemImage: "checkmark") }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 420)
        .onAppear { if let t = existing { name = t.name; category = t.category } }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name required."; return }
        if let t = existing {
            t.name = trimmed; t.category = category
        } else {
            context.insert(AssetType(name: trimmed, category: category))
        }
        do { try context.save(); dismiss() }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}
