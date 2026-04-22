import SwiftUI

struct MoversCard: View {
    @EnvironmentObject var app: AppState
    let snapshots: [Snapshot]

    private struct Mover: Identifiable {
        let id = UUID()
        let name: String
        let delta: Double
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("TOP MOVERS").font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 24) {
                    column(title: "▲ Gainers", movers: Array(movers.prefix(5)), color: Palette.up)
                    Divider()
                    column(title: "▼ Decliners", movers: Array(movers.reversed().prefix(5)), color: Palette.down)
                }
            }
        }
    }

    private var movers: [Mover] {
        let sorted = snapshots.sorted { $0.date < $1.date }
        guard let curID = app.activeSnapshotID,
              let idx = sorted.firstIndex(where: { $0.id == curID }),
              idx > 0 else { return [] }
        let cur = sorted[idx], prev = sorted[idx - 1]

        var prevByAccount: [UUID: Double] = [:]
        for v in prev.values where v.account != nil {
            prevByAccount[v.account!.id] = CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
        }

        var list: [Mover] = []
        for v in cur.values {
            guard let acc = v.account else { continue }
            let now = CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
            let before = prevByAccount[acc.id] ?? 0
            list.append(Mover(name: acc.name, delta: now - before))
        }
        return list.sorted { $0.delta > $1.delta }
    }

    private func column(title: String, movers: [Mover], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(color)
            ForEach(movers) { m in
                HStack {
                    Text(m.name).font(.callout)
                    Spacer()
                    Text(Fmt.signedDelta(m.delta, app.displayCurrency))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(Palette.deltaColor(m.delta))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
