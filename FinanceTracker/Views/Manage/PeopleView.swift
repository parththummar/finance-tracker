import SwiftUI
import SwiftData

struct PeopleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @State private var editing: Person?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Person?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            tablePanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("BREAKDOWN")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("People").font(Typo.serifNum(32))
                    Text("— \(people.count)").font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
                .foregroundStyle(Color.lInk)
            }
            Spacer()
            PrimaryButton(action: { creatingNew = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Person")
                }
            }
        }
    }

    private var tablePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Household members", meta: "\(people.count) total")
                rowHeader
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(people.enumerated()), id: \.element.id) { idx, p in
                            row(p, idx: idx)
                            if idx < people.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var rowHeader: some View {
        HStack {
            Text("Color").frame(width: 60, alignment: .leading)
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Accounts").frame(width: 100, alignment: .trailing)
            Text("").frame(width: 160)
        }
        .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private func row(_ p: Person, idx: Int) -> some View {
        HStack {
            ColorSwatchButton(
                current: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                onPick: { c in
                    p.colorHex = c.toHex()
                    try? context.save()
                }
            )
            .frame(width: 60, alignment: .leading)

            Text(p.name)
                .font(Typo.sans(13, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(p.accounts.count)")
                .font(Typo.mono(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 100, alignment: .trailing)

            HStack(spacing: 6) {
                GhostButton(action: { editing = p }) { Text("Edit") }
                GhostButton(action: { confirmDelete = p }) {
                    Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                }
            }
            .frame(width: 160, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }
}
