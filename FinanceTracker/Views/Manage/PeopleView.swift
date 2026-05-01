import SwiftUI
import SwiftData

struct PeopleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @State private var editing: Person?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Person?
    @StateObject private var sizer = ColumnSizer(tableID: "people", specs: [
        ColumnSpec(id: "color",    title: "Color",    minWidth: 60,  defaultWidth: 80,  resizable: false),
        ColumnSpec(id: "name",     title: "Name",     minWidth: 140, defaultWidth: 300, flex: true),
        ColumnSpec(id: "accounts", title: "Accounts", minWidth: 80,  defaultWidth: 110, alignment: .trailing),
        ColumnSpec(id: "actions",  title: "",         minWidth: 160, defaultWidth: 160, alignment: .trailing, resizable: false),
    ])

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if people.isEmpty {
                EditorialEmpty(
                    eyebrow: "Breakdown · People",
                    title: "No household",
                    titleItalic: "members yet.",
                    body: "Wealth is usually held by someone. Add the people whose accounts you track — they become filters across every view.",
                    detail: "A person owns zero or more accounts. Colors are assigned automatically.",
                    ctaLabel: "New Person",
                    cta: { creatingNew = true }
                )
            } else {
                tablePanel
            }
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
                ResizableHeader(sizer: sizer)
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

    private func row(_ p: Person, idx: Int) -> some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "color") {
                HStack {
                    ColorSwatchButton(
                        current: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                        onPick: { c in
                            p.colorHex = c.toHex()
                            try? context.save()
                        }
                    )
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "name") {
                Text(p.name)
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "accounts") {
                Text("\(p.accounts.count)")
                    .font(Typo.mono(12))
                    .foregroundStyle(Color.lInk2)
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                HStack(spacing: 6) {
                    GhostButton(action: { editing = p }) { Text("Edit") }
                    GhostButton(action: { confirmDelete = p }) {
                        Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        .rowClickable { editing = p }
    }
}
