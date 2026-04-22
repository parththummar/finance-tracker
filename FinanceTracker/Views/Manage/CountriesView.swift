import SwiftUI
import SwiftData

struct CountriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Country.code) private var countries: [Country]
    @State private var editing: Country?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Country?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            tablePanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("BREAKDOWN")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("Countries").font(Typo.serifNum(32))
                    Text("— \(countries.count)").font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
                .foregroundStyle(Color.lInk)
            }
            Spacer()
            PrimaryButton(action: { creatingNew = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Country")
                }
            }
        }
    }

    private var tablePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Jurisdictions", meta: "\(countries.count) total")
                rowHeader
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(countries.enumerated()), id: \.element.id) { idx, c in
                            row(c, idx: idx)
                            if idx < countries.count - 1 {
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
            Text("Flag").frame(width: 50, alignment: .leading)
            Text("Code").frame(width: 70, alignment: .leading)
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Ccy").frame(width: 70, alignment: .leading)
            Text("Accounts").frame(width: 90, alignment: .trailing)
            Text("").frame(width: 160)
        }
        .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private func row(_ c: Country, idx: Int) -> some View {
        HStack {
            ColorSwatchButton(
                current: Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code),
                onPick: { col in
                    c.colorHex = col.toHex()
                    try? context.save()
                }
            )
            .frame(width: 60, alignment: .leading)

            Text(c.flag)
                .font(.system(size: 16))
                .frame(width: 50, alignment: .leading)

            Text(c.code)
                .font(Typo.mono(12, weight: .semibold))
                .foregroundStyle(Color.lInk)
                .frame(width: 70, alignment: .leading)

            Text(c.name)
                .font(Typo.sans(13, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(c.defaultCurrency.rawValue)
                .font(Typo.mono(11))
                .foregroundStyle(Color.lInk3)
                .frame(width: 70, alignment: .leading)

            Text("\(c.accounts.count)")
                .font(Typo.mono(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 90, alignment: .trailing)

            HStack(spacing: 6) {
                GhostButton(action: { editing = c }) { Text("Edit") }
                GhostButton(action: { confirmDelete = c }) {
                    Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                }
            }
            .frame(width: 160, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }
}
