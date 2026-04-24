import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var undo: UndoStash
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var editing: Account?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Account?
    @State private var showInactive: Bool = true
    @State private var historyAccount: Account?
    @StateObject private var sizer = ColumnSizer(tableID: "accounts", specs: [
        ColumnSpec(id: "name",    title: "Name",    minWidth: 140, defaultWidth: 260, flex: true),
        ColumnSpec(id: "person",  title: "Person",  minWidth: 90,  defaultWidth: 130),
        ColumnSpec(id: "country", title: "Country", minWidth: 70,  defaultWidth: 100),
        ColumnSpec(id: "type",    title: "Type",    minWidth: 100, defaultWidth: 150),
        ColumnSpec(id: "ccy",     title: "Ccy",     minWidth: 44,  defaultWidth: 60),
        ColumnSpec(id: "status",  title: "Status",  minWidth: 70,  defaultWidth: 100),
        ColumnSpec(id: "actions", title: "",        minWidth: 160, defaultWidth: 160, alignment: .trailing, resizable: false),
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
            Button("Delete", role: .destructive) {
                if let a = confirmDelete {
                    let cap = undo.capture(account: a)
                    context.delete(a)
                    try? context.save()
                    undo.stash(.account(cap))
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Account and all \(confirmDelete?.values.count ?? 0) historical values across snapshots will be deleted.")
        }
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
                        Button(a.isActive ? "Retire" : "Reactivate") {
                            a.isActive.toggle()
                            try? context.save()
                        }
                        Button("Delete…", role: .destructive) {
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
