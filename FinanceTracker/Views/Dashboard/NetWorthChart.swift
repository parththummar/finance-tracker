import SwiftUI
import Charts

struct NetWorthChart: View {
    @EnvironmentObject var app: AppState
    let snapshots: [Snapshot]
    @State private var stacked: Bool = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("NET WORTH OVER TIME")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Stacked by category", isOn: $stacked)
                        .toggleStyle(.switch)
                        .font(.caption)
                }

                if stacked {
                    stackedChart
                } else {
                    lineChart
                }
            }
        }
    }

    private var chronological: [Snapshot] {
        snapshots.sorted { $0.date < $1.date }
    }

    private func totalFor(_ s: Snapshot) -> Double {
        s.values.reduce(0) { $0 + CurrencyConverter.displayValue(for: $1, in: app.displayCurrency) }
    }

    private var lineChart: some View {
        Chart(chronological, id: \.id) { s in
            LineMark(
                x: .value("Date", s.date),
                y: .value("Net Worth", totalFor(s))
            )
            .interpolationMethod(.monotone)
            PointMark(
                x: .value("Date", s.date),
                y: .value("Net Worth", totalFor(s))
            )
        }
        .frame(height: 260)
    }

    private var stackedChart: some View {
        Chart {
            ForEach(chronological, id: \.id) { s in
                ForEach(AssetCategory.allCases) { cat in
                    let v = s.values
                        .filter { $0.account?.assetType?.category == cat }
                        .reduce(0.0) { $0 + CurrencyConverter.displayValue(for: $1, in: app.displayCurrency) }
                    AreaMark(
                        x: .value("Date", s.date),
                        y: .value("Value", v)
                    )
                    .foregroundStyle(by: .value("Category", cat.rawValue))
                }
            }
        }
        .chartForegroundStyleScale(range: AssetCategory.allCases.map { Palette.color(for: $0) })
        .frame(height: 260)
    }
}
