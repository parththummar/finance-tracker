import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            hero
            kpiGrid
            composition
            movers
        }
    }

    // MARK: computed

    private var sortedAsc: [Snapshot] { snapshots.sorted { $0.date < $1.date } }

    private var activeSnapshot: Snapshot? {
        if let id = app.activeSnapshotID, let s = snapshots.first(where: { $0.id == id }) { return s }
        return snapshots.first
    }

    private func total(_ s: Snapshot?) -> Double {
        guard let s else { return 0 }
        return s.values.reduce(0) { $0 + CurrencyConverter.displayValue(for: $1, in: app.displayCurrency) }
    }

    private var activeIdx: Int? {
        guard let a = activeSnapshot else { return nil }
        return sortedAsc.firstIndex { $0.id == a.id }
    }

    private var prevSnapshot: Snapshot? {
        guard let i = activeIdx, i > 0 else { return nil }
        return sortedAsc[i - 1]
    }

    private var yearAgoSnapshot: Snapshot? {
        guard let i = activeIdx, i >= 4 else { return nil }
        return sortedAsc[i - 4]
    }

    private var curTotal: Double  { total(activeSnapshot) }
    private var prevTotal: Double { total(prevSnapshot) }
    private var yaTotal: Double   { total(yearAgoSnapshot) }

    private func pct(_ cur: Double, _ prev: Double) -> Double {
        guard prev != 0 else { return 0 }
        return (cur - prev) / abs(prev) * 100
    }

    // MARK: hero

    private var hero: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(Color.lInk).frame(width: 5, height: 5)
                    Text("NET WORTH · \(activeSnapshot?.label ?? "—")")
                        .font(Typo.eyebrow)
                        .tracking(1.5)
                        .foregroundStyle(Color.lInk3)
                }
                .padding(.bottom, 10)

                HStack(alignment: .top, spacing: 4) {
                    Text(app.displayCurrency.symbol)
                        .font(Typo.serifNum(56))
                        .foregroundStyle(Color.lInk3)
                        .padding(.top, 24)
                    Text(Fmt.groupedInt(curTotal, locale: app.displayCurrency == .INR ? .init(identifier: "en_IN") : .init(identifier: "en_US")))
                        .font(Typo.serifNum(96))
                        .foregroundStyle(Color.lInk)
                        .monospacedDigit()
                        .tracking(-1.5)
                }

                if prevSnapshot != nil || yearAgoSnapshot != nil {
                    HStack(spacing: 10) {
                        if prevSnapshot != nil {
                            HeroDelta(pct: pct(curTotal, prevTotal), suffix: "· \(Fmt.compact(curTotal - prevTotal, app.displayCurrency)) QoQ")
                        }
                        if yearAgoSnapshot != nil {
                            HeroDelta(pct: pct(curTotal, yaTotal), suffix: "YoY")
                        }
                    }
                    .padding(.top, 4)
                }

                if let s = activeSnapshot {
                    Text(footnote(for: s))
                        .font(Typo.serifItalic(13.5))
                        .foregroundStyle(Color.lInk2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 520, alignment: .leading)
                        .padding(.top, 22)
                }
            }

            Spacer(minLength: 0)

            sparklinePanel
                .frame(width: 320, height: 140)
        }
        .padding(28)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var sparklinePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Net worth trajectory")
                    .font(Typo.eyebrow)
                    .tracking(1.5)
                    .foregroundStyle(Color.lInk3)
                Spacer()
                if let first = sortedAsc.first, let last = sortedAsc.last {
                    HStack(spacing: 4) {
                        Text(first.label).font(Typo.mono(10))
                        Text("→").font(Typo.mono(10)).foregroundStyle(Color.lInk4)
                        Text(last.label).font(Typo.mono(10))
                    }
                    .foregroundStyle(Color.lInk3)
                }
            }
            Chart(sortedAsc, id: \.id) { s in
                AreaMark(
                    x: .value("Date", s.date),
                    y: .value("Val", total(s))
                )
                .foregroundStyle(
                    .linearGradient(colors: [Color.lInk.opacity(0.18), Color.lInk.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Date", s.date),
                    y: .value("Val", total(s))
                )
                .foregroundStyle(Color.lInk)
                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { $0.background(Color.lSunken.opacity(0.3)) }
        }
        .padding(14)
        .background(Color.lBg2)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func footnote(for s: Snapshot) -> String {
        let accCount = Set(s.values.compactMap { $0.account?.id }).count
        let countries = Set(s.values.compactMap { $0.account?.country?.name }).count
        let people = Set(s.values.compactMap { $0.account?.person?.name })
        let peopleStr = people.sorted().joined(separator: " & ")
        return "Across \(accCount) accounts in \(countries) \(countries == 1 ? "country" : "countries"), held by \(peopleStr). Last updated \(s.label) · exchange rate ₹\(String(format: "%.2f", s.usdToInrRate)) / $1."
    }

    // MARK: KPI grid

    private var kpiGrid: some View {
        let active = activeSnapshot
        let values = active?.values ?? []
        func sum(_ cats: [AssetCategory]) -> Double {
            values.filter { v in cats.contains(where: { $0 == v.account?.assetType?.category }) }
                .reduce(0.0) { $0 + CurrencyConverter.displayValue(for: $1, in: app.displayCurrency) }
        }
        let liquid = sum([.cash])
        let invested = sum([.investment, .crypto])
        let retirement = sum([.retirement])
        let insurance = sum([.insurance])
        let debt = sum([.debt])

        func kpiDelta(_ cats: [AssetCategory]) -> String? {
            guard let prev = prevSnapshot else { return nil }
            let p = prev.values.filter { v in cats.contains(where: { $0 == v.account?.assetType?.category }) }
                .reduce(0.0) { $0 + CurrencyConverter.displayValue(for: $1, in: app.displayCurrency) }
            guard p != 0 else { return nil }
            let c = sum(cats)
            let d = (c - p) / abs(p) * 100
            return "\(d >= 0 ? "+" : "−")\(String(format: "%.1f", abs(d)))% QoQ"
        }

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
            spacing: 14
        ) {
            KPICard(
                label: "Liquid",
                value: Fmt.compact(liquid, app.displayCurrency),
                sub: "Cash + deposits",
                deltaText: kpiDelta([.cash]),
                deltaUp: (sum([.cash]) - (prevSnapshot.map { s in s.values.filter { $0.account?.assetType?.category == .cash }.reduce(0.0) { $0 + CurrencyConverter.displayValue(for: $1, in: app.displayCurrency) } } ?? 0)) >= 0
            )
            KPICard(
                label: "Invested",
                value: Fmt.compact(invested, app.displayCurrency),
                sub: "Equity + crypto",
                deltaText: kpiDelta([.investment, .crypto]),
                deltaUp: true
            )
            KPICard(
                label: "Retirement",
                value: Fmt.compact(retirement + insurance, app.displayCurrency),
                sub: "401k · IRA · NPS · HSA",
                deltaText: kpiDelta([.retirement, .insurance]),
                deltaUp: true
            )
            KPICard(
                label: "Debt",
                value: Fmt.compact(abs(debt), app.displayCurrency),
                sub: "Loans · credit",
                valueColor: .lLoss,
                deltaText: kpiDelta([.debt]),
                deltaUp: false
            )
        }
    }

    // MARK: Composition

    private var composition: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Composition", emphasis: "— where it lives",
                        rightLabel: (activeSnapshot?.label ?? "—") + " · " + app.displayCurrency.rawValue)
            HStack(alignment: .top, spacing: 14) {
                personPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                countryPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                typePanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(height: 440)
        }
    }

    private var personPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "By person", meta: "\(personItems.count) people")
                donutPanel(items: personItems, total: curTotal)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var countryPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "By country", meta: "\(countryItems.count) \(countryItems.count == 1 ? "jurisdiction" : "jurisdictions")")
                VStack(alignment: .leading, spacing: 18) {
                    StackedHBar(items: countryItems.map {
                        StackedHBar.Item(label: $0.label, value: $0.value, color: $0.color)
                    })
                    VStack(spacing: 0) {
                        ForEach(Array(countryItems.enumerated()), id: \.offset) { _, c in
                            AllocRow(
                                color: c.color, label: c.label,
                                value: Fmt.compact(c.value, app.displayCurrency),
                                pct: curTotal == 0 ? 0 : c.value / curTotal * 100
                            )
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
                .padding(18)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var typePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "By asset type", meta: "\(typeItems.count) categories")
                VStack(spacing: 0) {
                    ForEach(Array(typeItems.sorted { abs($0.value) > abs($1.value) }.enumerated()), id: \.offset) { _, t in
                        AllocRow(
                            color: t.color, label: t.label,
                            value: Fmt.compact(abs(t.value), app.displayCurrency),
                            pct: curTotal == 0 ? 0 : abs(t.value) / curTotal * 100,
                            showBar: true,
                            valueColor: t.value < 0 ? .lLoss : .lInk
                        )
                        Divider().overlay(Color.lLine)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func donutPanel(items: [AllocItem], total: Double) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Chart(items) { i in
                    SectorMark(
                        angle: .value("v", abs(i.value)),
                        innerRadius: .ratio(0.66),
                        angularInset: 1.5
                    )
                    .foregroundStyle(i.color)
                    .cornerRadius(2)
                }
                .frame(width: 180, height: 180)
                VStack(spacing: 4) {
                    Text("TOTAL")
                        .font(Typo.sans(10, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(Color.lInk3)
                    Text(Fmt.compact(total, app.displayCurrency))
                        .font(Typo.serifNum(26))
                        .foregroundStyle(Color.lInk)
                        .monospacedDigit()
                }
            }
            .padding(.top, 14)
            VStack(spacing: 0) {
                ForEach(items) { i in
                    AllocRow(
                        color: i.color, label: i.label,
                        value: Fmt.compact(i.value, app.displayCurrency),
                        pct: total == 0 ? 0 : i.value / total * 100
                    )
                    Divider().overlay(Color.lLine)
                }
            }
        }
        .padding(18)
    }

    private struct AllocItem: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }

    private var personItems: [AllocItem] {
        guard let s = activeSnapshot else { return [] }
        var buckets: [String: (Double, Color)] = [:]
        for v in s.values {
            guard let acc = v.account, let p = acc.person else { continue }
            let amt = CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
            let col = Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name)
            buckets[p.name, default: (0, col)].0 += amt
        }
        return buckets.map { AllocItem(label: $0.key, value: $0.value.0, color: $0.value.1) }
            .sorted { $0.value > $1.value }
    }

    private var countryItems: [AllocItem] {
        guard let s = activeSnapshot else { return [] }
        var buckets: [String: (Double, Color)] = [:]
        for v in s.values {
            guard let acc = v.account, let c = acc.country else { continue }
            let amt = CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
            let key = "\(c.flag) \(c.name)"
            let col = Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code)
            buckets[key, default: (0, col)].0 += amt
        }
        return buckets.map { AllocItem(label: $0.key, value: $0.value.0, color: $0.value.1) }
            .sorted { $0.value > $1.value }
    }

    private var typeItems: [AllocItem] {
        guard let s = activeSnapshot else { return [] }
        var buckets: [AssetCategory: Double] = [:]
        for v in s.values {
            guard let acc = v.account, let t = acc.assetType else { continue }
            buckets[t.category, default: 0] += CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
        }
        return buckets.map { AllocItem(label: $0.key.rawValue, value: $0.value, color: Palette.color(for: $0.key)) }
    }

    // MARK: Movers

    private var movers: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Biggest movers", emphasis: "— this quarter",
                        rightLabel: prevSnapshot != nil ? "\(prevSnapshot!.label) → \(activeSnapshot?.label ?? "—")" : nil)
            Panel {
                VStack(spacing: 0) {
                    moversHeader
                    ForEach(Array(moversList.enumerated()), id: \.offset) { i, m in
                        moverRow(m)
                        if i < moversList.count - 1 {
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
            }
        }
    }

    private var moversHeader: some View {
        HStack {
            Text("Account").frame(maxWidth: .infinity, alignment: .leading)
            Text("Owner").frame(width: 140, alignment: .leading)
            Text("Country").frame(width: 100, alignment: .leading)
            Text("Type").frame(width: 120, alignment: .leading)
            Text("Value").frame(width: 120, alignment: .trailing)
            Text("QoQ").frame(width: 80, alignment: .trailing)
        }
        .font(Typo.eyebrow)
        .tracking(1.2)
        .foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private struct MoverRow: Identifiable {
        let id = UUID()
        let account: Account
        let value: Double
        let pct: Double
        let up: Bool
    }

    private var moversList: [MoverRow] {
        guard let cur = activeSnapshot, let prev = prevSnapshot else { return [] }
        var prevMap: [UUID: Double] = [:]
        for v in prev.values where v.account != nil {
            prevMap[v.account!.id] = CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
        }
        var list: [MoverRow] = []
        for v in cur.values {
            guard let acc = v.account else { continue }
            let now = CurrencyConverter.displayValue(for: v, in: app.displayCurrency)
            let before = prevMap[acc.id] ?? 0
            let diff = now - before
            let p = before == 0 ? 0 : diff / abs(before) * 100
            list.append(MoverRow(account: acc, value: now, pct: p, up: diff >= 0))
        }
        return list.sorted { abs($0.pct) > abs($1.pct) }.prefix(6).map { $0 }
    }

    private func moverRow(_ m: MoverRow) -> some View {
        let person = m.account.person
        let country = m.account.country
        let type = m.account.assetType
        return HStack {
            Text(m.account.name)
                .font(Typo.sans(12.5, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if let p = person {
                    Avatar(text: String(p.name.prefix(1)),
                           color: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                           size: 18)
                    Text(p.name).font(Typo.sans(12))
                }
            }
            .foregroundStyle(Color.lInk2)
            .frame(width: 140, alignment: .leading)
            Text(country?.flag ?? "")
                .font(.system(size: 14))
                .frame(width: 100, alignment: .leading)
            Text(type?.name ?? "")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 120, alignment: .leading)
            Text(Fmt.compact(m.value, app.displayCurrency))
                .font(Typo.mono(12, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(width: 120, alignment: .trailing)
            Text("\(m.up ? "+" : "−")\(String(format: "%.1f", abs(m.pct)))%")
                .font(Typo.mono(12, weight: .medium))
                .foregroundStyle(m.up ? Color.lGain : Color.lLoss)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }
}
