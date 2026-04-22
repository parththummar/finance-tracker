import SwiftUI
import Charts

struct AccountHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    let account: Account
    @State private var showInNative: Bool = true
    @State private var points: [Point] = []
    @State private var loaded: Bool = false

    fileprivate struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let native: Double
        let display: Double
        let currency: Currency
    }

    private func computePoints() -> [Point] {
        let target = app.displayCurrency
        let native = account.nativeCurrency
        return account.values.compactMap { v -> Point? in
            guard let s = v.snapshot else { return nil }
            let display = CurrencyConverter.convert(
                nativeValue: v.nativeValue,
                from: native,
                to: target,
                usdToInrRate: s.usdToInrRate
            )
            return Point(
                date: s.date,
                label: s.label,
                native: v.nativeValue,
                display: display,
                currency: native
            )
        }.sorted { $0.date < $1.date }
    }

    private var delta: (abs: Double, pct: Double)? {
        guard let first = points.first, let last = points.last, points.count >= 2 else { return nil }
        let a = showInNative ? first.native : first.display
        let b = showInNative ? last.native : last.display
        guard a != 0 else { return nil }
        return (b - a, (b - a) / abs(a))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if !loaded {
                Panel {
                    ProgressView()
                        .padding(40)
                        .frame(maxWidth: .infinity)
                }
            } else if points.count < 2 {
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not enough history.")
                            .font(Typo.sans(15, weight: .semibold))
                        Text("Account has \(points.count) snapshot value(s). Need 2+ to chart.")
                            .font(Typo.serifItalic(13))
                            .foregroundStyle(Color.lInk3)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Panel { chartSection }
                Panel { tableSection }
            }

            HStack {
                Spacer()
                GhostButton(action: { dismiss() }) { Text("Close") }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 820, minHeight: 620)
        .background(Color.lBg)
        .onAppear {
            guard !loaded else { return }
            points = computePoints()
            loaded = true
        }
    }

    private var header: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ACCOUNT HISTORY")
                            .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                        Text(account.name)
                            .font(Typo.serifNum(26))
                            .foregroundStyle(Color.lInk)
                    }
                    Spacer()
                    if account.nativeCurrency != app.displayCurrency {
                        SegControl<Bool>(
                            options: [
                                (account.nativeCurrency.rawValue, true),
                                (app.displayCurrency.rawValue, false),
                            ],
                            selection: $showInNative
                        )
                    } else {
                        Pill(text: account.nativeCurrency.rawValue)
                    }
                }
                HStack(spacing: 14) {
                    if let p = account.person {
                        HStack(spacing: 5) {
                            Avatar(text: String(p.name.prefix(1)),
                                   color: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                                   size: 18)
                            Text(p.name).font(Typo.sans(12))
                        }
                        .foregroundStyle(Color.lInk2)
                    }
                    if let c = account.country {
                        Text("\(c.flag) \(c.name)")
                            .font(Typo.sans(12))
                            .foregroundStyle(Color.lInk2)
                    }
                    if let t = account.assetType {
                        Text(t.name)
                            .font(Typo.sans(12))
                            .foregroundStyle(Color.lInk2)
                    }
                }

                if let d = delta {
                    let ccy: Currency = showInNative ? account.nativeCurrency : app.displayCurrency
                    HStack(spacing: 8) {
                        Text("Total change")
                            .font(Typo.eyebrow).tracking(1.2)
                            .foregroundStyle(Color.lInk3)
                        Text(Fmt.signedDelta(d.abs, ccy))
                            .font(Typo.mono(13, weight: .semibold))
                            .foregroundStyle(Palette.deltaColor(d.abs))
                        Text("(\(String(format: "%+.1f%%", d.pct * 100)))")
                            .font(Typo.mono(12))
                            .foregroundStyle(Palette.deltaColor(d.abs))
                    }
                }
            }
            .padding(20)
        }
    }

    private var chartSection: some View {
        VStack(spacing: 0) {
            PanelHead(title: "Value over time", meta: "\(points.count) snapshots")
            Chart(points) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("Value", showInNative ? p.native : p.display)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.linearGradient(
                    colors: [Color.lInk.opacity(0.14), Color.lInk.opacity(0.01)],
                    startPoint: .top, endPoint: .bottom
                ))
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Value", showInNative ? p.native : p.display)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.lInk)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Value", showInNative ? p.native : p.display)
                )
                .foregroundStyle(Color.lInk)
                .symbolSize(24)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.lLine)
                    AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(Typo.mono(10)).foregroundStyle(Color.lInk3)
                }
            }
            .frame(height: 300)
            .padding(18)
        }
    }

    private var tableSection: some View {
        VStack(spacing: 0) {
            PanelHead(title: "Snapshots", meta: "\(points.count)")
            VStack(spacing: 0) {
                HStack {
                    Text("Snapshot").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Value").frame(width: 160, alignment: .trailing)
                    Text("Δ").frame(width: 140, alignment: .trailing)
                }
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Color.lSunken)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

                let rows = points.reversed().map { $0 }
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, p in
                    HStack {
                        Text(p.label)
                            .font(Typo.sans(12.5, weight: .medium))
                            .foregroundStyle(Color.lInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Fmt.currency(showInNative ? p.native : p.display,
                                          showInNative ? p.currency : app.displayCurrency))
                            .font(Typo.mono(12.5, weight: .medium))
                            .frame(width: 160, alignment: .trailing)
                        if let prev = rows.dropFirst(idx + 1).first {
                            let prevVal = showInNative ? prev.native : prev.display
                            let curVal = showInNative ? p.native : p.display
                            let diff = curVal - prevVal
                            Text(Fmt.signedDelta(diff, showInNative ? p.currency : app.displayCurrency))
                                .font(Typo.mono(11, weight: .medium))
                                .foregroundStyle(Palette.deltaColor(diff))
                                .frame(width: 140, alignment: .trailing)
                        } else {
                            Text("—").foregroundStyle(Color.lInk4)
                                .font(Typo.mono(11))
                                .frame(width: 140, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
                }
            }
        }
    }
}
