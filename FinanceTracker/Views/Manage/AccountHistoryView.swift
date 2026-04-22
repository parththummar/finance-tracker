import SwiftUI
import Charts

struct AccountHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    let account: Account
    @State private var showInNative: Bool = true

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let native: Double
        let display: Double
        let currency: Currency
    }

    private var points: [Point] {
        let vals = account.values.compactMap { v -> Point? in
            guard let s = v.snapshot else { return nil }
            return Point(
                date: s.date,
                label: s.label,
                native: v.nativeValue,
                display: CurrencyConverter.displayValue(for: v, in: app.displayCurrency),
                currency: account.nativeCurrency
            )
        }
        return vals.sorted { $0.date < $1.date }
    }

    private var delta: (abs: Double, pct: Double)? {
        guard let first = points.first, let last = points.last, points.count >= 2 else { return nil }
        let a = showInNative ? first.native : first.display
        let b = showInNative ? last.native : last.display
        guard a != 0 else { return nil }
        return (b - a, (b - a) / a)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if points.count < 2 {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not enough history.")
                            .font(.headline)
                        Text("Account has \(points.count) snapshot value(s). Need at least 2 to chart.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Card { chart }
                Card { table }
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 800, minHeight: 600)
    }

    private var header: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(account.name).font(.title2.bold())
                    Spacer()
                    if account.nativeCurrency != app.displayCurrency {
                        Picker("", selection: $showInNative) {
                            Text(account.nativeCurrency.rawValue).tag(true)
                            Text(app.displayCurrency.rawValue).tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    } else {
                        Text(account.nativeCurrency.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.secondary.opacity(0.15), in: Capsule())
                    }
                }
                HStack(spacing: 16) {
                    if let p = account.person { Text("Person: \(p.name)").foregroundStyle(.secondary) }
                    if let c = account.country { Text("Country: \(c.flag) \(c.name)").foregroundStyle(.secondary) }
                    if let t = account.assetType { Text("Type: \(t.name)").foregroundStyle(.secondary) }
                }
                .font(.caption)

                if let d = delta {
                    let ccy: Currency = showInNative ? account.nativeCurrency : app.displayCurrency
                    HStack(spacing: 8) {
                        Text("Total change:")
                        Text(Fmt.signedDelta(d.abs, ccy))
                            .foregroundStyle(Palette.deltaColor(d.abs))
                        Text("(\(Fmt.percent(d.pct)))")
                            .foregroundStyle(Palette.deltaColor(d.abs))
                    }
                    .font(.callout.monospacedDigit())
                }
            }
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VALUE OVER TIME").font(.caption).foregroundStyle(.secondary)
            Chart(points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Value", showInNative ? p.native : p.display)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Palette.up)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("Value", showInNative ? p.native : p.display)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(
                    colors: [Palette.up.opacity(0.25), Palette.up.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                ))

                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Value", showInNative ? p.native : p.display)
                )
                .foregroundStyle(Palette.up)
                .symbolSize(40)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 320)
        }
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SNAPSHOTS — \(points.count)").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            Divider()
            let rows = points.reversed().map { $0 }
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, p in
                HStack {
                    Text(p.label).frame(width: 180, alignment: .leading)
                    Spacer()
                    Text(Fmt.currency(showInNative ? p.native : p.display,
                                      showInNative ? p.currency : app.displayCurrency))
                        .font(.body.monospacedDigit())
                        .frame(width: 160, alignment: .trailing)
                    if let prev = rows.dropFirst(idx + 1).first {
                        let prevVal = showInNative ? prev.native : prev.display
                        let curVal = showInNative ? p.native : p.display
                        let diff = curVal - prevVal
                        Text(Fmt.signedDelta(diff, showInNative ? p.currency : app.displayCurrency))
                            .foregroundStyle(Palette.deltaColor(diff))
                            .font(.caption.monospacedDigit())
                            .frame(width: 140, alignment: .trailing)
                    } else {
                        Text("—").foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(width: 140, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(idx.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
