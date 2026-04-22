import SwiftUI
import Charts

struct DistributionSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct DistributionCard: View {
    @EnvironmentObject var app: AppState
    let title: String
    @Binding var style: ChartStyle
    let slices: [DistributionSlice]

    private var total: Double { slices.map(\.value).reduce(0, +) }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title.uppercased())
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $style) {
                        Image(systemName: "circle.dashed").tag(ChartStyle.donut)
                        Image(systemName: "chart.bar.fill").tag(ChartStyle.bar)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 70)
                }

                if style == .donut { donut } else { bars }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var donut: some View {
        HStack(spacing: 16) {
            Chart(slices) { s in
                SectorMark(
                    angle: .value("Value", s.value),
                    innerRadius: .ratio(0.6),
                    angularInset: 1
                )
                .foregroundStyle(s.color)
            }
            .frame(width: 140, height: 140)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(slices) { s in
                    HStack(spacing: 6) {
                        Circle().fill(s.color).frame(width: 8, height: 8)
                        Text(s.label).font(.caption)
                        Spacer()
                        Text(Fmt.label(
                            value: s.value,
                            share: total > 0 ? s.value / total : 0,
                            ccy: app.displayCurrency,
                            mode: app.labelMode
                        ))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var bars: some View {
        Chart(slices) { s in
            BarMark(
                x: .value("Value", s.value),
                y: .value("Label", s.label)
            )
            .foregroundStyle(s.color)
            .annotation(position: .trailing) {
                Text(Fmt.label(
                    value: s.value,
                    share: total > 0 ? s.value / total : 0,
                    ccy: app.displayCurrency,
                    mode: app.labelMode
                ))
                .font(.caption2.monospacedDigit())
            }
        }
        .frame(height: CGFloat(slices.count) * 28 + 20)
    }
}
