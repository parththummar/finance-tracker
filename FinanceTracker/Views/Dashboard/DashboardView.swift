import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

    @State private var cachedPersonItems: [AllocItem] = []
    @State private var cachedCountryItems: [AllocItem] = []
    @State private var cachedTypeItems: [AllocItem] = []
    @State private var cachedCurTotal: Double = 0
    @State private var cachedPrevTotal: Double = 0
    @State private var cachedYaTotal: Double = 0
    @State private var cachedLiquid: Double = 0
    @State private var cachedInvested: Double = 0
    @State private var cachedRetirement: Double = 0
    @State private var cachedInsurance: Double = 0
    @State private var cachedDebt: Double = 0
    @State private var cachedPrevLiquid: Double = 0
    @State private var cachedPrevInvested: Double = 0
    @State private var cachedPrevRetirement: Double = 0
    @State private var cachedPrevInsurance: Double = 0
    @State private var cachedPrevDebt: Double = 0
    @State private var cachedMovers: [MoverRow] = []
    @State private var cachedTrajectory: [TrajectoryPoint] = []
    @State private var cachedTargets: [AssetCategory: Double] = [:]
    @State private var showingTargets: Bool = false
    @State private var cachedLiabilities: [LiabilityRow] = []

    private struct LiabilityRow: Identifiable {
        let id: UUID
        let name: String
        let currency: Currency
        let currentDisplay: Double
        let currentNative: Double
        let prevDisplay: Double?
        let peakDisplay: Double
        let color: Color
        var qoqDelta: Double? { prevDisplay.map { currentDisplay - $0 } }
        var paydownPct: Double {
            guard peakDisplay > 0 else { return 0 }
            return max(0, min(100, (peakDisplay - currentDisplay) / peakDisplay * 100))
        }
    }

    private struct TrajectoryPoint: Identifiable {
        let id = UUID()
        let date: Date
        let val: Double
    }

    var body: some View {
        Group {
            if snapshots.isEmpty {
                EditorialEmpty(
                    eyebrow: "Overview · Net Worth",
                    title: "A ledger",
                    titleItalic: "awaits its first entry.",
                    body: "No snapshots yet. Capture a quarterly snapshot to begin charting trajectory, allocation, and movers across the household.",
                    detail: "Snapshots are point-in-time totals. One per quarter keeps the trend honest.",
                    ctaLabel: "Create first snapshot",
                    cta: {
                        app.newSnapshotRequested = true
                        app.selectedScreen = .snapshots
                    },
                    secondaryLabel: "Set up accounts first",
                    secondary: { app.selectedScreen = .accounts }
                )
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    kpiGrid
                    composition
                    if !cachedLiabilities.isEmpty {
                        liabilities
                    }
                    movers
                }
            }
        }
        .onAppear { recompute() }
        .onChange(of: app.activeSnapshotID) { _, _ in recompute() }
        .onChange(of: app.displayCurrency) { _, _ in recompute() }
        .onChange(of: snapshots.count) { _, _ in recompute() }
        .onChange(of: snapshots.map { $0.isLocked }) { _, _ in recompute() }
        .onChange(of: snapshots.map { $0.usdToInrRate }) { _, _ in recompute() }
    }

    private func recompute() {
        let target = app.displayCurrency
        let cur = activeSnapshot
        let prev = prevSnapshot
        let ya = yearAgoSnapshot

        cachedCurTotal = total(cur, target: target)
        cachedPrevTotal = total(prev, target: target)
        cachedYaTotal = total(ya, target: target)

        cachedPersonItems = computePersonItems(cur, target: target)
        cachedCountryItems = computeCountryItems(cur, target: target)
        cachedTypeItems = computeTypeItems(cur, target: target)

        cachedLiquid = sumCats(cur, [.cash], target: target)
        cachedInvested = sumCats(cur, [.investment, .crypto], target: target)
        cachedRetirement = sumCats(cur, [.retirement], target: target)
        cachedInsurance = sumCats(cur, [.insurance], target: target)
        cachedDebt = sumCats(cur, [.debt], target: target)

        cachedPrevLiquid = sumCats(prev, [.cash], target: target)
        cachedPrevInvested = sumCats(prev, [.investment, .crypto], target: target)
        cachedPrevRetirement = sumCats(prev, [.retirement], target: target)
        cachedPrevInsurance = sumCats(prev, [.insurance], target: target)
        cachedPrevDebt = sumCats(prev, [.debt], target: target)

        cachedMovers = computeMovers(cur: cur, prev: prev, target: target)
        cachedTrajectory = sortedAsc.map { TrajectoryPoint(date: $0.date, val: total($0, target: target)) }
        cachedTargets = TargetAllocationStore.all()
        cachedLiabilities = computeLiabilities(cur: cur, prev: prev, target: target)
    }

    private func computeLiabilities(cur: Snapshot?, prev: Snapshot?, target: Currency) -> [LiabilityRow] {
        guard let cur else { return [] }
        let debts = cur.values.filter { $0.account?.assetType?.category == .debt }
        guard !debts.isEmpty else { return [] }

        var peak: [UUID: Double] = [:]
        for s in snapshots {
            for v in s.values where v.account?.assetType?.category == .debt {
                guard let id = v.account?.id else { continue }
                let mag = abs(CurrencyConverter.displayValue(for: v, in: target))
                peak[id] = max(peak[id] ?? 0, mag)
            }
        }
        var prevMap: [UUID: Double] = [:]
        if let prev {
            for v in prev.values where v.account?.assetType?.category == .debt {
                guard let id = v.account?.id else { continue }
                prevMap[id] = abs(CurrencyConverter.displayValue(for: v, in: target))
            }
        }

        return debts.compactMap { v -> LiabilityRow? in
            guard let acc = v.account else { return nil }
            let curDisp = abs(CurrencyConverter.displayValue(for: v, in: target))
            return LiabilityRow(
                id: acc.id,
                name: acc.name,
                currency: acc.nativeCurrency,
                currentDisplay: curDisp,
                currentNative: abs(v.nativeValue),
                prevDisplay: prevMap[acc.id],
                peakDisplay: peak[acc.id] ?? curDisp,
                color: Palette.color(for: .debt)
            )
        }
        .sorted { $0.currentDisplay > $1.currentDisplay }
    }

    private func total(_ s: Snapshot?, target: Currency) -> Double {
        guard let s else { return 0 }
        return s.values.reduce(0) { $0 + CurrencyConverter.netDisplayValue(for: $1, in: target) }
    }

    private func sumCats(_ s: Snapshot?, _ cats: [AssetCategory], target: Currency) -> Double {
        guard let s else { return 0 }
        return s.values
            .filter { v in cats.contains(where: { $0 == v.account?.assetType?.category }) }
            .reduce(0.0) { $0 + CurrencyConverter.displayValue(for: $1, in: target) }
    }

    private func computePersonItems(_ s: Snapshot?, target: Currency) -> [AllocItem] {
        guard let s else { return [] }
        var buckets: [String: (Double, Color)] = [:]
        for v in s.values {
            guard let acc = v.account, let p = acc.person else { continue }
            let amt = CurrencyConverter.netDisplayValue(for: v, in: target)
            let col = Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name)
            buckets[p.name, default: (0, col)].0 += amt
        }
        return buckets.map {
            AllocItem(label: $0.key, value: $0.value.0, color: $0.value.1,
                      groupKey: .person, matchValue: $0.key)
        }
        .sorted { $0.value > $1.value }
    }

    private func computeCountryItems(_ s: Snapshot?, target: Currency) -> [AllocItem] {
        guard let s else { return [] }
        var buckets: [String: (Double, Color, String)] = [:]
        for v in s.values {
            guard let acc = v.account, let c = acc.country else { continue }
            let amt = CurrencyConverter.netDisplayValue(for: v, in: target)
            let key = "\(c.flag) \(c.name)"
            let col = Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code)
            buckets[key, default: (0, col, c.name)].0 += amt
        }
        return buckets.map {
            AllocItem(label: $0.key, value: $0.value.0, color: $0.value.1,
                      groupKey: .country, matchValue: $0.value.2)
        }
        .sorted { $0.value > $1.value }
    }

    private func computeTypeItems(_ s: Snapshot?, target: Currency) -> [AllocItem] {
        guard let s else { return [] }
        var buckets: [AssetCategory: Double] = [:]
        for v in s.values {
            guard let acc = v.account, let t = acc.assetType else { continue }
            buckets[t.category, default: 0] += CurrencyConverter.netDisplayValue(for: v, in: target)
        }
        return buckets.map {
            AllocItem(label: $0.key.rawValue, value: $0.value, color: Palette.color(for: $0.key),
                      groupKey: .category, matchValue: $0.key.rawValue)
        }
    }

    private func computeMovers(cur: Snapshot?, prev: Snapshot?, target: Currency) -> [MoverRow] {
        guard let cur, let prev else { return [] }
        var prevMap: [UUID: Double] = [:]
        for v in prev.values where v.account != nil {
            prevMap[v.account!.id] = CurrencyConverter.netDisplayValue(for: v, in: target)
        }
        var list: [MoverRow] = []
        for v in cur.values {
            guard let acc = v.account else { continue }
            let now = CurrencyConverter.netDisplayValue(for: v, in: target)
            let before = prevMap[acc.id] ?? 0
            let diff = now - before
            let p = before == 0 ? 0 : diff / abs(before) * 100
            list.append(MoverRow(account: acc, value: now, pct: p, up: diff >= 0))
        }
        return list.sorted { abs($0.pct) > abs($1.pct) }.prefix(6).map { $0 }
    }

    private func openBreakdown(_ item: AllocItem) {
        app.pendingBreakdownFilter = PendingFilter(
            key: item.groupKey, matchValue: item.matchValue, label: item.label
        )
        app.selectedScreen = .breakdown
    }

    // MARK: computed

    private var sortedAsc: [Snapshot] { snapshots.sorted { $0.date < $1.date } }

    private var activeSnapshot: Snapshot? {
        if let id = app.activeSnapshotID, let s = snapshots.first(where: { $0.id == id }) { return s }
        return snapshots.first
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
        guard let active = activeSnapshot else { return nil }
        let oneYearAgo = Calendar.current.date(
            byAdding: .year, value: -1, to: active.date)!
        return sortedAsc
            .filter { $0.id != active.id && $0.date <= active.date }
            .min(by: { abs($0.date.timeIntervalSince(oneYearAgo))
                     < abs($1.date.timeIntervalSince(oneYearAgo)) })
            .flatMap { s -> Snapshot? in
                abs(s.date.timeIntervalSince(oneYearAgo)) < 90 * 86400 ? s : nil
            }
    }

    private var curTotal: Double  { cachedCurTotal }
    private var prevTotal: Double { cachedPrevTotal }
    private var yaTotal: Double   { cachedYaTotal }

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
            Chart(cachedTrajectory) { pt in
                AreaMark(
                    x: .value("Date", pt.date),
                    y: .value("Val", pt.val)
                )
                .foregroundStyle(
                    .linearGradient(colors: [Color.lInk.opacity(0.18), Color.lInk.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Date", pt.date),
                    y: .value("Val", pt.val)
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

    private func kpiDeltaText(cur: Double, prev: Double) -> String? {
        guard prevSnapshot != nil, prev != 0 else { return nil }
        let d = (cur - prev) / abs(prev) * 100
        return "\(d >= 0 ? "+" : "−")\(String(format: "%.1f", abs(d)))% QoQ"
    }

    private var kpiGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
            spacing: 14
        ) {
            KPICard(
                label: "Liquid",
                value: Fmt.compact(cachedLiquid, app.displayCurrency),
                sub: "Cash + deposits",
                deltaText: kpiDeltaText(cur: cachedLiquid, prev: cachedPrevLiquid),
                deltaUp: cachedLiquid >= cachedPrevLiquid
            )
            KPICard(
                label: "Invested",
                value: Fmt.compact(cachedInvested, app.displayCurrency),
                sub: "Equity + crypto",
                deltaText: kpiDeltaText(cur: cachedInvested, prev: cachedPrevInvested),
                deltaUp: cachedInvested >= cachedPrevInvested
            )
            KPICard(
                label: "Retirement",
                value: Fmt.compact(cachedRetirement + cachedInsurance, app.displayCurrency),
                sub: "401k · IRA · NPS · HSA",
                deltaText: kpiDeltaText(cur: cachedRetirement + cachedInsurance,
                                        prev: cachedPrevRetirement + cachedPrevInsurance),
                deltaUp: (cachedRetirement + cachedInsurance) >= (cachedPrevRetirement + cachedPrevInsurance)
            )
            KPICard(
                label: "Debt",
                value: Fmt.compact(abs(cachedDebt), app.displayCurrency),
                sub: "Loans · credit",
                valueColor: .lLoss,
                deltaText: kpiDeltaText(cur: cachedDebt, prev: cachedPrevDebt),
                deltaUp: cachedDebt >= cachedPrevDebt
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
            .fixedSize(horizontal: false, vertical: true)
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
                            Button {
                                openBreakdown(c)
                            } label: {
                                AllocRow(
                                    color: c.color, label: c.label,
                                    value: Fmt.compact(c.value, app.displayCurrency),
                                    pct: curTotal == 0 ? 0 : c.value / curTotal * 100
                                )
                            }
                            .buttonStyle(.plain)
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
                typePanelHead
                VStack(spacing: 0) {
                    ForEach(Array(typeItems.sorted { abs($0.value) > abs($1.value) }.enumerated()), id: \.offset) { _, t in
                        Button {
                            openBreakdown(t)
                        } label: {
                            AllocRow(
                                color: t.color, label: t.label,
                                value: Fmt.compact(abs(t.value), app.displayCurrency),
                                pct: curTotal == 0 ? 0 : abs(t.value) / curTotal * 100,
                                showBar: true,
                                valueColor: t.value < 0 ? .lLoss : .lInk,
                                targetPct: targetPct(for: t)
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.lLine)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showingTargets) {
            TargetsEditorSheet(onSave: { recompute() })
        }
    }

    private var typePanelHead: some View {
        HStack {
            Text("By asset type")
                .font(Typo.sans(14, weight: .semibold))
                .foregroundStyle(Color.lInk)
            Spacer()
            Text(targetSummary)
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk3)
            GhostButton(action: { showingTargets = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "target").font(.system(size: 10, weight: .semibold))
                    Text(cachedTargets.isEmpty ? "Set targets" : "Targets")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private var targetSummary: String {
        if cachedTargets.isEmpty { return "\(typeItems.count) categories" }
        let sum = cachedTargets.values.reduce(0, +)
        if abs(sum - 100) < 0.05 { return "\(cachedTargets.count) set · balanced" }
        if sum < 100 { return "\(cachedTargets.count) set · \(String(format: "%.0f", 100 - sum))% unassigned" }
        return "\(cachedTargets.count) set · \(String(format: "%.0f", sum - 100))% over"
    }

    private func targetPct(for item: AllocItem) -> Double? {
        guard let cat = AssetCategory(rawValue: item.matchValue) else { return nil }
        return cachedTargets[cat]
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
                    Button {
                        openBreakdown(i)
                    } label: {
                        AllocRow(
                            color: i.color, label: i.label,
                            value: Fmt.compact(i.value, app.displayCurrency),
                            pct: total == 0 ? 0 : i.value / total * 100
                        )
                    }
                    .buttonStyle(.plain)
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
        let groupKey: GroupKey
        let matchValue: String
    }

    private var personItems: [AllocItem] { cachedPersonItems }
    private var countryItems: [AllocItem] { cachedCountryItems }
    private var typeItems: [AllocItem] { cachedTypeItems }

    // MARK: Liabilities

    private var liabilities: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(title: "Liabilities", emphasis: "— what you owe",
                        rightLabel: Fmt.compact(totalLiabilities, app.displayCurrency))
            Panel {
                VStack(spacing: 0) {
                    PanelHead(title: "Debt accounts",
                              meta: "\(cachedLiabilities.count) \(cachedLiabilities.count == 1 ? "account" : "accounts") · total \(Fmt.compact(totalLiabilities, app.displayCurrency))")
                    VStack(spacing: 0) {
                        ForEach(Array(cachedLiabilities.enumerated()), id: \.element.id) { idx, row in
                            liabilityRow(row)
                                .padding(.horizontal, 18).padding(.vertical, 12)
                                .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
                            if idx < cachedLiabilities.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
    }

    private var totalLiabilities: Double {
        cachedLiabilities.reduce(0) { $0 + $1.currentDisplay }
    }

    private func liabilityRow(_ row: LiabilityRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(row.color).frame(width: 10, height: 10)
                Text(row.name)
                    .font(Typo.sans(13, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let d = row.qoqDelta {
                    let paidDown = d < 0
                    HStack(spacing: 4) {
                        Image(systemName: paidDown ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(Fmt.compact(abs(d), app.displayCurrency))
                            .font(Typo.mono(11, weight: .semibold))
                        Text("QoQ")
                            .font(Typo.mono(10))
                            .opacity(0.7)
                    }
                    .foregroundStyle(paidDown ? Color.lGain : Color.lLoss)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((paidDown ? Color.lGain : Color.lLoss).opacity(0.12))
                    .overlay(Capsule().stroke((paidDown ? Color.lGain : Color.lLoss).opacity(0.3), lineWidth: 1))
                    .clipShape(Capsule())
                }
                Text(Fmt.compact(row.currentDisplay, app.displayCurrency))
                    .font(Typo.sans(13, weight: .semibold))
                    .foregroundStyle(Color.lLoss)
                    .monospacedDigit()
            }
            HStack(spacing: 10) {
                Text("PAID \(String(format: "%.0f", row.paydownPct))%")
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                    .frame(width: 70, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.lSunken)
                        Rectangle().fill(Color.lGain.opacity(0.55))
                            .frame(width: max(0, geo.size.width * CGFloat(row.paydownPct / 100)))
                    }
                }
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                Text("peak \(Fmt.compact(row.peakDisplay, app.displayCurrency))")
                    .font(Typo.mono(10.5))
                    .foregroundStyle(Color.lInk3)
                    .frame(width: 120, alignment: .trailing)
            }
        }
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

    private var moversList: [MoverRow] { cachedMovers }

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
