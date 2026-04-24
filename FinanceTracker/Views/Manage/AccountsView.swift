import SwiftUI
import SwiftData

struct AccountsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var undo: UndoStash
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Snapshot.date) private var snapshots: [Snapshot]
    @State private var editing: Account?
    @State private var creatingNew: Bool = false
    @State private var showInactive: Bool = true
    @State private var historyAccount: Account?
    @State private var confirmDelete: Account?
    @State private var cachedTrends: [UUID: [Double]] = [:]
    @StateObject private var sizer = ColumnSizer(tableID: "accounts", specs: [
        ColumnSpec(id: "name",    title: "Name",    minWidth: 140, defaultWidth: 240, flex: true),
        ColumnSpec(id: "person",  title: "Person",  minWidth: 90,  defaultWidth: 130),
        ColumnSpec(id: "country", title: "Country", minWidth: 70,  defaultWidth: 100),
        ColumnSpec(id: "type",    title: "Type",    minWidth: 100, defaultWidth: 140),
        ColumnSpec(id: "ccy",     title: "Ccy",     minWidth: 44,  defaultWidth: 60),
        ColumnSpec(id: "trend",   title: "12mo",    minWidth: 70,  defaultWidth: 90),
        ColumnSpec(id: "status",  title: "Status",  minWidth: 70,  defaultWidth: 100),
        ColumnSpec(id: "actions", title: "",        minWidth: 140, defaultWidth: 140, alignment: .trailing, resizable: false),
    ])

    private var visible: [Account] {
        showInactive ? accounts : accounts.filter(\.isActive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if accounts.isEmpty {
                EditorialEmpty(
                    eyebrow: "Data · Accounts",
                    title: "No accounts",
                    titleItalic: "tracked yet.",
                    body: "An account is any vessel that holds value — a checking account, a brokerage, a property, a loan. Add one to begin.",
                    detail: "Accounts carry owner, country, and asset type. Values live on snapshots.",
                    ctaLabel: "New Account",
                    cta: { creatingNew = true }
                )
            } else {
                tablePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { AccountEditorSheet(existing: $0) }
        .sheet(isPresented: $creatingNew) { AccountEditorSheet(existing: nil) }
        .sheet(item: $historyAccount) { AccountHistoryView(account: $0) }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                if let a = confirmDelete {
                    let cap = undo.capture(account: a)
                    context.delete(a)
                    do {
                        try context.save()
                        undo.stash(.account(cap))
                    } catch {
                        context.rollback()
                    }
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Account and all \(confirmDelete?.values.count ?? 0) historical values across snapshots will be deleted. You have 10 seconds to undo.")
        }
        .onAppear { recomputeTrends() }
        .onChange(of: snapshots.count) { _, _ in recomputeTrends() }
        .onChange(of: accounts.count) { _, _ in recomputeTrends() }
        .onChange(of: app.displayCurrency) { _, _ in recomputeTrends() }
    }

    private func recomputeTrends() {
        let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: .now) ?? .distantPast
        let recent = snapshots.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        var out: [UUID: [Double]] = [:]
        for a in accounts {
            let series = recent.compactMap { s -> Double? in
                guard let v = s.values.first(where: { $0.account?.id == a.id }) else { return nil }
                return CurrencyConverter.netDisplayValue(for: v, in: app.displayCurrency)
            }
            out[a.id] = series
        }
        cachedTrends = out
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DATA · ALL ACCOUNTS")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 8) {
                    Text("Accounts").font(Typo.serifNum(32))
                    Text("— \(visible.count)").font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
                .foregroundStyle(Color.lInk)
            }
            Spacer()
            Toggle("", isOn: $showInactive)
                .toggleStyle(.switch)
                .labelsHidden()
            Text("Show retired")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
            PrimaryButton(action: { creatingNew = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("New Account")
                }
            }
        }
    }

    private var tablePanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "All accounts", meta: "\(visible.count) visible")
                ResizableHeader(sizer: sizer)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { idx, a in
                            row(a, idx: idx)
                            if idx < visible.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ a: Account, idx: Int) -> some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "name") {
                Text(a.name)
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "person") {
                HStack(spacing: 6) {
                    if let p = a.person {
                        Avatar(text: String(p.name.prefix(1)),
                               color: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                               size: 18)
                        Text(p.name)
                            .font(Typo.sans(12))
                            .foregroundStyle(Color.lInk2)
                            .lineLimit(1)
                    } else {
                        Text("—").foregroundStyle(Color.lInk3)
                    }
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "country") {
                HStack(spacing: 4) {
                    Text(a.country?.flag ?? "")
                        .font(.system(size: 14))
                    Text(a.country?.code ?? "—")
                        .font(Typo.mono(11))
                        .foregroundStyle(Color.lInk2)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "type") {
                Text(a.assetType?.name ?? "Unknown type")
                    .font(Typo.sans(12))
                    .foregroundStyle(a.assetType == nil ? Color.lLoss : Color.lInk2)
                    .lineLimit(1)
            }
            ResizableCell(sizer: sizer, colID: "ccy") {
                Text(a.nativeCurrency.rawValue)
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk3)
            }
            ResizableCell(sizer: sizer, colID: "trend") {
                let series = cachedTrends[a.id] ?? []
                let up = series.count >= 2 ? (series.last! >= series.first!) : true
                Sparkline(values: series,
                          stroke: series.count < 2 ? Color.lInk3 : (up ? Color.lGain : Color.lLoss),
                          fill: (up ? Color.lGain : Color.lLoss).opacity(0.08))
                    .frame(height: 18)
            }
            ResizableCell(sizer: sizer, colID: "status") {
                HStack {
                    Pill(text: a.isActive ? "active" : "retired", emphasis: a.isActive)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "actions") {
                HStack(spacing: 6) {
                    GhostButton(action: { historyAccount = a }) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10, weight: .bold))
                    }
                    GhostButton(action: { editing = a }) { Text("Edit") }
                    Menu {
                        Button("Show History") { historyAccount = a }
                        Button(a.isActive ? "Archive (Retire)" : "Reactivate") {
                            a.isActive.toggle()
                            try? context.save()
                        }
                        Divider()
                        Button("Delete permanently…", role: .destructive) {
                            confirmDelete = a
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.lInk2)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.lLine, lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { historyAccount = a }
    }
}
