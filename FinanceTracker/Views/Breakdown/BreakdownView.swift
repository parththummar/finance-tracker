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
        VStack(alignment: .leading, spacing: 20) {
            header
            Panel { treemapSection }
            Panel { tableSection }
        }
        .sheet(item: $historyAccount) { AccountHistoryView(account: $0) }
    }

    private var active: Snapshot? {
        guard let id = app.activeSnapshotID else { return snapshots.first }
        return snapshots.first { $0.id == id }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BREAKDOWN")
                        .font(Typo.eyebrow).tracking(1.5)
                        .foregroundStyle(Color.lInk3)
                    HStack(spacing: 8) {
                        Text("Allocation").font(Typo.serifNum(32))
                        Text("— grouped by \(groupBy.rawValue.lowercased())")
                            .font(Typo.serifItalic(28))
                            .foregroundStyle(Color.lInk3)
                    }
                    .foregroundStyle(Color.lInk)
                }
                Spacer()
                SegControl<GroupKey>(
                    options: GroupKey.allCases.map { (label: $0.rawValue, value: $0) },
                    selection: $groupBy
                )
            }

            if !filters.isEmpty {
                HStack(spacing: 6) {
                    Text("FILTERS")
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                    ForEach(filters) { f in
                        HStack(spacing: 4) {
                            Text("\(f.key.rawValue) · \(f.label)")
                                .font(Typo.mono(10.5, weight: .medium))
                            Button {
                                filters.removeAll { $0.id == f.id }
                            } label: { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)) }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .foregroundStyle(Color.lInk2)
                        .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
                    }
                    GhostButton(action: { filters.removeAll() }) { Text("Clear") }
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
        VStack(alignment: .leading, spacing: 0) {
            PanelHead(title: "Treemap", meta: Fmt.compact(filteredRows.map(\.display).reduce(0, +), app.displayCurrency))
            VStack(alignment: .leading, spacing: 10) {
                TreemapView(
                    tiles: tiles,
                    currency: app.displayCurrency,
                    onTap: { tile in handleTap(tile) },
                    onHover: { tile in hovered = tile }
                )
                .frame(height: 460)
                .background(Color.lSunken)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lLine, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let h = hovered {
                    HStack {
                        Text(h.label).font(Typo.sans(12, weight: .semibold))
                        Text("·").foregroundStyle(Color.lInk4)
                        Text(Fmt.currency(h.value, app.displayCurrency))
                            .font(Typo.mono(12, weight: .medium))
                    }
                    .foregroundStyle(Color.lInk2)
                } else {
                    Text("Click group to filter · click account for history")
                        .font(Typo.serifItalic(13))
                        .foregroundStyle(Color.lInk3)
                }
            }
            .padding(18)
        }
    }

    private func handleTap(_ tile: TreemapTile) {
        if let accountID = tile.accountID, let acc = accounts.first(where: { $0.id == accountID }) {
            historyAccount = acc
            return
        }
        let isParent = !tile.children.isEmpty
        if isParent {
            let newFilter = Filter(key: groupBy, label: tile.label, matchValue: tile.label)
            if !filters.contains(where: { $0.key == newFilter.key && $0.matchValue == newFilter.matchValue }) {
                filters.append(newFilter)
            }
        }
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
        let rows = filteredRows.sorted { $0.display > $1.display }
        let total = rows.map(\.display).reduce(0, +)
        return VStack(spacing: 0) {
            PanelHead(title: "Accounts", meta: "\(rows.count) total")
            VStack(spacing: 0) {
                HStack {
                    Text("Account").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Owner").frame(width: 130, alignment: .leading)
                    Text("Country").frame(width: 70, alignment: .leading)
                    Text("Type").frame(width: 140, alignment: .leading)
                    Text("Native").frame(width: 120, alignment: .trailing)
                    Text(app.displayCurrency.rawValue).frame(width: 120, alignment: .trailing)
                    Text("%").frame(width: 60, alignment: .trailing)
                }
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Color.lSunken)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    HStack {
                        Text(r.name).font(Typo.sans(12.5, weight: .medium))
                            .foregroundStyle(Color.lInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(r.personColor).frame(width: 6, height: 12)
                            Text(r.person).font(Typo.sans(12))
                        }
                        .foregroundStyle(Color.lInk2)
                        .frame(width: 130, alignment: .leading)
                        Text(r.country).font(.system(size: 13))
                            .frame(width: 70, alignment: .leading)
                        Text(r.assetType).font(Typo.sans(12)).foregroundStyle(Color.lInk2)
                            .frame(width: 140, alignment: .leading)
                        Text(Fmt.currency(r.nativeValue, r.currency))
                            .font(Typo.mono(12)).foregroundStyle(Color.lInk2)
                            .frame(width: 120, alignment: .trailing)
                        Text(Fmt.compact(r.display, app.displayCurrency))
                            .font(Typo.mono(12, weight: .semibold))
                            .frame(width: 120, alignment: .trailing)
                        Text(total > 0 ? String(format: "%.1f%%", r.display / total * 100) : "—")
                            .font(Typo.mono(11))
                            .foregroundStyle(Color.lInk3)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(i.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))

                    if i < rows.count - 1 {
                        Divider().overlay(Color.lLine)
                    }
                }
            }
        }
    }
}
