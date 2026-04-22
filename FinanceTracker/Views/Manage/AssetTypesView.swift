import SwiftUI
import SwiftData

struct AssetTypesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AssetType.name) private var types: [AssetType]
    @State private var editing: AssetType?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: AssetType?
    @State private var colorTick: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            tablePanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("BREAKDOWN")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("Asset Types").font(Typo.serifNum(32))
                    Text("— \(types.count)").font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
                .foregroundStyle(Color.lInk)
            }
            Spacer()
            PrimaryButton(action: { creatingNew = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Type")
                }
            }
        }
    }

    private var tablePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Asset taxonomy", meta: "\(types.count) total")
                rowHeader
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(types.enumerated()), id: \.element.id) { idx, t in
                            row(t, idx: idx)
                            if idx < types.count - 1 {
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
            Text("Category").frame(width: 150, alignment: .leading)
            Text("Accounts").frame(width: 100, alignment: .trailing)
            Text("").frame(width: 160)
        }
        .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private func row(_ t: AssetType, idx: Int) -> some View {
        HStack {
            ColorSwatchButton(
                current: Palette.color(for: t.category),
                onPick: { c in
                    CategoryColorStore.setHex(c.toHex(), for: t.category)
                    colorTick &+= 1
                }
            )
            .id("swatch-\(t.id)-\(colorTick)")
            .frame(width: 60, alignment: .leading)

            Text(t.name)
                .font(Typo.sans(13, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(t.category.rawValue)
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 150, alignment: .leading)

            Text("\(t.accounts.count)")
                .font(Typo.mono(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 100, alignment: .trailing)

            HStack(spacing: 6) {
                GhostButton(action: { editing = t }) { Text("Edit") }
                GhostButton(action: { confirmDelete = t }) {
                    Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                }
            }
            .frame(width: 160, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }
}
