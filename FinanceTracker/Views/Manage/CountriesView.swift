import SwiftUI
import SwiftData

struct CountriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Country.code) private var countries: [Country]
    @State private var editing: Country?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Country?
    @StateObject private var sizer = ColumnSizer(tableID: "countries", specs: [
        ColumnSpec(id: "color",    title: "Color",    minWidth: 60,  defaultWidth: 80,  resizable: false),
        ColumnSpec(id: "flag",     title: "Flag",     minWidth: 50,  defaultWidth: 60,  resizable: false),
        ColumnSpec(id: "code",     title: "Code",     minWidth: 60,  defaultWidth: 80),
        ColumnSpec(id: "name",     title: "Name",     minWidth: 140, defaultWidth: 280, flex: true),
        ColumnSpec(id: "ccy",      title: "Ccy",      minWidth: 50,  defaultWidth: 70),
        ColumnSpec(id: "accounts", title: "Accounts", minWidth: 80,  defaultWidth: 100, alignment: .trailing),
        ColumnSpec(id: "actions",  title: "",         minWidth: 160, defaultWidth: 160, alignment: .trailing, resizable: false),
    ])

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if countries.isEmpty {
                EditorialEmpty(
                    eyebrow: "Breakdown · Countries",
                    title: "No jurisdictions",
                    titleItalic: "on file.",
                    body: "Countries carry a flag, a default currency, and pin each account to a tax home. Add at least one before creating accounts.",
                    detail: "Exchange rates translate native currencies to your display currency.",
                    ctaLabel: "New Country",
                    cta: { creatingNew = true }
                )
            } else {
                tablePanel
            }
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
                ResizableHeader(sizer: sizer)
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

    private func row(_ c: Country, idx: Int) -> some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "color") {
                HStack {
                    ColorSwatchButton(
                        current: Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code),
                        onPick: { col in
                            c.colorHex = col.toHex()
                            try? context.save()
                        }
                    )
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "flag") {
                Text(c.flag).font(.system(size: 16))
            }
            ResizableCell(sizer: sizer, colID: "code") {
                Text(c.code)
                    .font(Typo.mono(12, weight: .semibold))
                    .foregroundStyle(Color.lInk)
            }
            ResizableCell(sizer: sizer, colID: "name") {
                Text(c.name)
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "ccy") {
                Text(c.defaultCurrency.rawValue)
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk3)
            }
            ResizableCell(sizer: sizer, colID: "accounts") {
                Text("\(c.accounts.count)")
                    .font(Typo.mono(12))
                    .foregroundStyle(Color.lInk2)
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                HStack(spacing: 6) {
                    GhostButton(action: { editing = c }) { Text("Edit") }
                    GhostButton(action: { confirmDelete = c }) {
                        Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        .rowClickable { editing = c }
    }
}
