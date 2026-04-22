import SwiftUI
import Charts

struct HeadlineCard: View {
    @EnvironmentObject var app: AppState
    let snapshots: [Snapshot]

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NET WORTH")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Fmt.currency(total, app.displayCurrency))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    if let d = activeSnapshot {
                        Text("as of \(Fmt.date(d.date))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    deltaChip(label: "QoQ", delta: qoqDelta, pct: qoqPct)
                    deltaChip(label: "YoY", delta: yoyDelta, pct: yoyPct)
                }
                sparkline
                    .frame(width: 200, height: 60)
            }
        }
    }

    private var activeSnapshot: Snapshot? {
        guard let id = app.activeSnapshotID else { return snapshots.first }
        return snapshots.first { $0.id == id }
    }

    private var chronological: [Snapshot] {
        snapshots.sorted { $0.date < $1.date }
    }

    private func totalFor(_ s: Snapshot) -> Double {
        s.values.reduce(0) { $0 + CurrencyConverter.displayValue(for: $1, in: app.displayCurrency) }
    }

    private var total: Double { activeSnapshot.map(totalFor) ?? 0 }

    private var qoqDelta: Double {
        guard let cur = activeSnapshot else { return 0 }
        let sorted = chronological
        guard let idx = sorted.firstIndex(where: { $0.id == cur.id }), idx > 0 else { return 0 }
        return totalFor(cur) - totalFor(sorted[idx - 1])
    }

    private var qoqPct: Double {
        guard let cur = activeSnapshot else { return 0 }
        let sorted = chronological
        guard let idx = sorted.firstIndex(where: { $0.id == cur.id }), idx > 0 else { return 0 }
        let prev = totalFor(sorted[idx - 1])
        guard prev != 0 else { return 0 }
        return (totalFor(cur) - prev) / prev
    }

    private var yoyDelta: Double {
        guard let cur = activeSnapshot else { return 0 }
        let sorted = chronological
        guard let idx = sorted.firstIndex(where: { $0.id == cur.id }), idx >= 4 else { return 0 }
        return totalFor(cur) - totalFor(sorted[idx - 4])
    }

    private var yoyPct: Double {
        guard let cur = activeSnapshot else { return 0 }
        let sorted = chronological
        guard let idx = sorted.firstIndex(where: { $0.id == cur.id }), idx >= 4 else { return 0 }
        let prev = totalFor(sorted[idx - 4])
        guard prev != 0 else { return 0 }
        return (totalFor(cur) - prev) / prev
    }

    @ViewBuilder
    private func deltaChip(label: String, delta: Double, pct: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
            Text(Fmt.signedDelta(delta, app.displayCurrency))
            Text("(\(Fmt.percent(pct))) \(label)")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Palette.deltaColor(delta).opacity(0.15), in: Capsule())
        .foregroundStyle(Palette.deltaColor(delta))
    }

    private var sparkline: some View {
        Chart(chronological, id: \.id) { s in
            LineMark(
                x: .value("Date", s.date),
                y: .value("Value", totalFor(s))
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
