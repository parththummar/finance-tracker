import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeadlineCard(snapshots: snapshots)
                HStack(alignment: .top, spacing: 16) {
                    DistributionCard(
                        title: "By Person",
                        style: Binding(get: { app.byPersonStyle }, set: { app.byPersonStyle = $0 }),
                        slices: personSlices()
                    )
                    DistributionCard(
                        title: "By Country",
                        style: Binding(get: { app.byCountryStyle }, set: { app.byCountryStyle = $0 }),
                        slices: countrySlices()
                    )
                    DistributionCard(
                        title: "By Category",
                        style: Binding(get: { app.byCategoryStyle }, set: { app.byCategoryStyle = $0 }),
                        slices: categorySlices()
                    )
                }
                NetWorthChart(snapshots: snapshots)
                MoversCard(snapshots: snapshots)
            }
            .padding(16)
        }
    }

    private var active: Snapshot? {
        guard let id = app.activeSnapshotID else { return snapshots.first }
        return snapshots.first { $0.id == id }
    }

    private func personSlices() -> [DistributionSlice] {
        guard let s = active else { return [] }
        var buckets: [String: (total: Double, color: Color)] = [:]
        for v in s.values {
            guard let acc = v.account, let p = acc.person else { continue }
            let amount = CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
            let color = Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name)
            buckets[p.name, default: (0, color)].total += amount
        }
        return buckets.map { DistributionSlice(label: $0.key, value: $0.value.total, color: $0.value.color) }
            .sorted { $0.value > $1.value }
    }

    private func countrySlices() -> [DistributionSlice] {
        guard let s = active else { return [] }
        var buckets: [String: (total: Double, color: Color)] = [:]
        for v in s.values {
            guard let acc = v.account, let c = acc.country else { continue }
            let amount = CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
            let label = "\(c.flag) \(c.name)"
            let color = Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code)
            buckets[label, default: (0, color)].total += amount
        }
        return buckets.map { DistributionSlice(label: $0.key, value: $0.value.total, color: $0.value.color) }
            .sorted { $0.value > $1.value }
    }

    private func categorySlices() -> [DistributionSlice] {
        guard let s = active else { return [] }
        var buckets: [AssetCategory: Double] = [:]
        for v in s.values {
            guard let acc = v.account, let t = acc.assetType else { continue }
            let amount = CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
            buckets[t.category, default: 0] += amount
        }
        return buckets.map { DistributionSlice(label: $0.key.rawValue, value: $0.value, color: Palette.color(for: $0.key)) }
            .sorted { $0.value > $1.value }
    }
}
