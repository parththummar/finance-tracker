import SwiftUI
import SwiftData

struct PersonEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var allPeople: [Person]
    let existing: Person?
    @State private var name: String = ""
    @State private var color: Color = .blue
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Person" : "Edit Person").font(Typo.serifNum(24))
            Form {
                TextField("Name", text: $name)
                ColorPicker("Chart color", selection: $color, supportsOpacity: false)
            }
            .formStyle(.grouped)

            if let err = errorMessage {
                Text(err).foregroundStyle(Color.lLoss).font(Typo.sans(12))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button { save() } label: { Label("Save", systemImage: "checkmark") }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 400)
        .onAppear {
            name = existing?.name ?? ""
            if let hex = existing?.colorHex, let c = Color.fromHex(hex) {
                color = c
            } else {
                let taken = allPeople.filter { $0.id != existing?.id }.compactMap { $0.colorHex }
                color = Palette.unusedFallback(taken: taken)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name required."; return }
        let hex = color.toHex()
        if let p = existing {
            p.name = trimmed
            p.colorHex = hex
        } else {
            let p = Person(name: trimmed)
            p.colorHex = hex
            context.insert(p)
        }
        do { try context.save(); dismiss() }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}
