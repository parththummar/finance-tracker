import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var editing: Account?
    @State private var creatingNew: Bool = false
    @State private var confirmDelete: Account?
    @State private var showInactive: Bool = true
    @State private var historyAccount: Account?

    private var visible: [Account] {
        showInactive ? accounts : accounts.filter(\.isActive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            tablePanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { AccountEditorSheet(existing: $0) }
        .sheet(isPresented: $creatingNew) { AccountEditorSheet(existing: nil) }
        .sheet(item: $historyAccount) { AccountHistoryView(account: $0) }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let a = confirmDelete { context.delete(a); try? context.save() }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Account and all \(confirmDelete?.values.count ?? 0) historical values across snapshots will be deleted. Cannot be undone.")
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
                rowHeader
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

    private var rowHeader: some View {
        HStack {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Person").frame(width: 120, alignment: .leading)
            Text("Country").frame(width: 90, alignment: .leading)
            Text("Type").frame(width: 140, alignment: .leading)
            Text("Ccy").frame(width: 50, alignment: .leading)
            Text("Status").frame(width: 90, alignment: .leading)
            Text("").frame(width: 160)
        }
        .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private func row(_ a: Account, idx: Int) -> some View {
        HStack {
            Text(a.name)
                .font(Typo.sans(13, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if let p = a.person {
                    Avatar(text: String(p.name.prefix(1)),
                           color: Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name),
                           size: 18)
                    Text(p.name)
                        .font(Typo.sans(12))
                        .foregroundStyle(Color.lInk2)
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .frame(width: 120, alignment: .leading)

            HStack(spacing: 4) {
                Text(a.country?.flag ?? "")
                    .font(.system(size: 14))
                Text(a.country?.code ?? "—")
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk2)
            }
            .frame(width: 90, alignment: .leading)

            Text(a.assetType?.name ?? "—")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 140, alignment: .leading)

            Text(a.nativeCurrency.rawValue)
                .font(Typo.mono(11))
                .foregroundStyle(Color.lInk3)
                .frame(width: 50, alignment: .leading)

            Pill(text: a.isActive ? "active" : "retired", emphasis: a.isActive)
                .frame(width: 90, alignment: .leading)

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
            .frame(width: 160, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { historyAccount = a }
    }
}
