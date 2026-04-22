import SwiftUI
import SwiftData

enum GroupKey: String, CaseIterable, Identifiable {
    case category = "Category"
    case person   = "Person"
    case country  = "Country"
    case assetType = "Type"
    var id: String { rawValue }
}

struct Filter: Hashable, Identifiable {
    let id = UUID()
    let key: GroupKey
    let label: String
    let matchValue: String
}

struct BreakdownView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @State private var groupBy: GroupKey = .category
    @State private var filters: [Filter] = []
    @State private var hovered: TreemapTile?
    @State private var historyAccount: Account?
    @Query private var accounts: [Account]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Card { treemapSection }
                Card { tableSection }
            }
            .padding(16)
        }
        .sheet(item: $historyAccount) { AccountHistoryView(account: $0) }
    }

    private var active: Snapshot? {
        guard let id = app.activeSnapshotID else { return snapshots.first }
        return snapshots.first { $0.id == id }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Breakdown").font(.title2.bold())
                Spacer()
                Picker("Group by", selection: $groupBy) {
                    ForEach(GroupKey.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(width: 220)
            }

            if !filters.isEmpty {
                HStack(spacing: 6) {
                    Text("Filters:").font(.caption).foregroundStyle(.secondary)
                    ForEach(filters) { f in
                        HStack(spacing: 4) {
                            Text("\(f.key.rawValue): \(f.label)").font(.caption)
                            Button {
                                filters.removeAll { $0.id == f.id }
                            } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.secondary.opacity(0.15), in: Capsule())
                    }
                    Button("Clear all") { filters.removeAll() }
                        .font(.caption)
                }
            }
        }
    }

    // MARK: treemap

    private var filteredRows: [Row] {
        guard let s = active else { return [] }
        return s.values.compactMap { v -> Row? in
            guard let acc = v.account else { return nil }
            let personName = acc.person?.name ?? "—"
            let countryName = acc.country?.name ?? ""
            let r = Row(
                id: v.id,
                accountID: acc.id,
                name: acc.name,
                person: personName,
                personColor: Color.fromHex(acc.person?.colorHex) ?? Palette.fallback(for: personName),
                country: "\(acc.country?.flag ?? "") \(acc.country?.code ?? "")",
                countryName: countryName,
                countryColor: Color.fromHex(acc.country?.colorHex) ?? Palette.fallback(for: acc.country?.code ?? countryName),
                category: acc.assetType?.category.rawValue ?? "",
                assetType: acc.assetType?.name ?? "—",
                currency: acc.nativeCurrency,
                nativeValue: v.nativeValue,
                display: CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
            )
            for f in filters {
                switch f.key {
                case .category where r.category != f.matchValue: return nil
                case .person where r.person != f.matchValue: return nil
                case .country where r.countryName != f.matchValue: return nil
                case .assetType where r.assetType != f.matchValue: return nil
                default: break
                }
            }
            return r
        }
    }

    private var tiles: [TreemapTile] {
        let rows = filteredRows
        let groups = Dictionary(grouping: rows) { row in
            switch groupBy {
            case .category:  return row.category
            case .person:    return row.person
            case .country:   return row.countryName
            case .assetType: return row.assetType
            }
        }
        return groups.map { (groupLabel, groupRows) in
            let total = groupRows.map(\.display).reduce(0, +)
            let color = colorFor(group: groupLabel, key: groupBy, sample: groupRows.first)
            let children = groupRows.sorted { $0.display > $1.display }
                .map { r in TreemapTile(label: r.name, value: max(r.display, 0.01), color: color, accountID: r.accountID) }
            return TreemapTile(label: groupLabel, value: max(total, 0.01), color: color, children: children)
        }
        .sorted { $0.value > $1.value }
    }

    private func colorFor(group: String, key: GroupKey, sample: Row?) -> Color {
        switch key {
        case .category:
            if let cat = AssetCategory(rawValue: group) { return Palette.color(for: cat) }
        case .person:
            if let sample { return sample.personColor }
        case .country:
            if let sample { return sample.countryColor }
        case .assetType:
            break
        }
        return Palette.fallback(for: group)
    }

    private var treemapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let total = filteredRows.map(\.display).reduce(0, +)
            HStack {
                Text("TREEMAP").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Fmt.currency(total, app.displayCurrency))
                    .font(.callout.monospacedDigit())
            }
            TreemapView(
                tiles: tiles,
                currency: app.displayCurrency,
                onTap: { tile in handleTap(tile) },
                onHover: { tile in hovered = tile }
            )
            .frame(height: 460)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            if let h = hovered {
                Text("\(h.label) — \(Fmt.currency(h.value, app.displayCurrency))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("Click parent tile to filter. Click account tile to open history chart.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func handleTap(_ tile: TreemapTile) {
        if let accountID = tile.accountID, let acc = accounts.first(where: { $0.id == accountID }) {
            historyAccount = acc
            return
        }
        let isParent = !tile.children.isEmpty
        if isParent {
            let newFilter = Filter(key: groupBy, label: tile.label, matchValue: matchFor(groupBy, label: tile.label))
            if !filters.contains(where: { $0.key == newFilter.key && $0.matchValue == newFilter.matchValue }) {
                filters.append(newFilter)
            }
        }
    }

    private func matchFor(_ key: GroupKey, label: String) -> String {
        label
    }

    // MARK: table

    private struct Row: Identifiable {
        let id: UUID
        let accountID: UUID
        let name: String
        let person: String
        let personColor: Color
        let country: String
        let countryName: String
        let countryColor: Color
        let category: String
        let assetType: String
        let currency: Currency
        let nativeValue: Double
        let display: Double
    }

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let rows = filteredRows.sorted { $0.display > $1.display }
            let total = rows.map(\.display).reduce(0, +)
            HStack {
                Text("ACCOUNTS — \(rows.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            Divider()
            Table(rows) {
                TableColumn("Account")  { Text($0.name) }
                TableColumn("Person")   { Text($0.person) }
                TableColumn("Country")  { Text($0.country) }
                TableColumn("Category") { Text($0.category) }
                TableColumn("Type")     { Text($0.assetType) }
                TableColumn("Native")   { r in
                    Text(Fmt.currency(r.nativeValue, r.currency))
                        .font(.body.monospacedDigit())
                }
                TableColumn(app.displayCurrency.rawValue) { r in
                    Text(Fmt.currency(r.display, app.displayCurrency))
                        .font(.body.monospacedDigit())
                }
                TableColumn("%") { r in
                    Text(total > 0 ? Fmt.percent(r.display / total) : "—")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 300)
        }
    }
}
