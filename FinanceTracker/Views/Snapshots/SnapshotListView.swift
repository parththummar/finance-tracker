import SwiftUI
import SwiftData

struct SnapshotListView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @State private var editing: Snapshot?
    @State private var showingNew = false
    @State private var confirmDelete: Snapshot?

    private func totalFor(_ s: Snapshot) -> Double {
        s.values.reduce(0) { $0 + CurrencyConverter.displayValue(for: $1, in: app.displayCurrency) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OVERVIEW · HISTORICAL")
                        .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                    HStack(spacing: 8) {
                        Text("Snapshots").font(Typo.serifNum(32))
                        Text("— \(snapshots.count) quarters").font(Typo.serifItalic(28))
                            .foregroundStyle(Color.lInk3)
                    }
                    .foregroundStyle(Color.lInk)
                }
                Spacer()
                PrimaryButton(action: { showingNew = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("New Snapshot")
                    }
                }
            }

            Panel {
                VStack(spacing: 0) {
                    header
                    ForEach(Array(snapshots.enumerated()), id: \.element.id) { idx, s in
                        row(idx: idx, s: s)
                        if idx < snapshots.count - 1 {
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
            }
        }
        .sheet(item: $editing) { SnapshotEditorView(snapshot: $0) }
        .sheet(isPresented: $showingNew) {
            NewSnapshotSheet { created in editing = created }
        }
        .confirmationDialog("Delete \(confirmDelete?.label ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete Snapshot", role: .destructive) {
                if let s = confirmDelete {
                    if app.activeSnapshotID == s.id { app.activeSnapshotID = nil }
                    context.delete(s)
                    try? context.save()
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("All \(confirmDelete?.values.count ?? 0) asset values recorded in this snapshot will also be deleted. Cannot be undone.")
        }
    }

    private var header: some View {
        HStack {
            Text("Snapshot").frame(maxWidth: .infinity, alignment: .leading)
            Text("Date").frame(width: 140, alignment: .leading)
            Text("FX").frame(width: 110, alignment: .trailing)
            Text("Total").frame(width: 140, alignment: .trailing)
            Text("Status").frame(width: 90, alignment: .leading)
            Text("").frame(width: 90)
        }
        .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private func row(idx: Int, s: Snapshot) -> some View {
        HStack {
            HStack(spacing: 10) {
                if app.activeSnapshotID == s.id {
                    Circle().fill(Color.lInk).frame(width: 6, height: 6)
                }
                Text(s.label)
                    .font(Typo.sans(13, weight: .semibold))
                    .foregroundStyle(Color.lInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(Fmt.date(s.date))
                .font(Typo.mono(11))
                .foregroundStyle(Color.lInk3)
                .frame(width: 140, alignment: .leading)

            Text("₹\(String(format: "%.2f", s.usdToInrRate))")
                .font(Typo.mono(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 110, alignment: .trailing)

            Text(Fmt.compact(totalFor(s), app.displayCurrency))
                .font(Typo.mono(12.5, weight: .semibold))
                .foregroundStyle(Color.lInk)
                .frame(width: 140, alignment: .trailing)

            HStack {
                Pill(text: s.isLocked ? "🔒 locked" : "✎ draft",
                     emphasis: !s.isLocked)
            }
            .frame(width: 90, alignment: .leading)

            HStack(spacing: 6) {
                GhostButton(action: { editing = s }) { Text("Open") }
                Menu {
                    if s.isLocked {
                        Button("Unlock") {
                            s.isLocked = false
                            s.lockedAt = nil
                            try? context.save()
                        }
                    }
                    Button("Set active") { app.activeSnapshotID = s.id }
                    Button("Delete…", role: .destructive) { confirmDelete = s }
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
            .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }
}
