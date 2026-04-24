import SwiftUI
import SwiftData

struct SnapshotListView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var undo: UndoStash
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @State private var editing: Snapshot?
    @State private var showingNew = false
    @State private var confirmDelete: Snapshot?
    @StateObject private var sizer = ColumnSizer(tableID: "snapshots", specs: [
        ColumnSpec(id: "snap",    title: "Snapshot", minWidth: 140, defaultWidth: 260, flex: true),
        ColumnSpec(id: "date",    title: "Date",     minWidth: 110, defaultWidth: 150),
        ColumnSpec(id: "fx",      title: "FX",       minWidth: 80,  defaultWidth: 120, alignment: .trailing),
        ColumnSpec(id: "total",   title: "Total",    minWidth: 100, defaultWidth: 150, alignment: .trailing),
        ColumnSpec(id: "status",  title: "Status",   minWidth: 70,  defaultWidth: 100),
        ColumnSpec(id: "actions", title: "",         minWidth: 90,  defaultWidth: 90,  alignment: .trailing, resizable: false),
    ])

    private func totalFor(_ s: Snapshot) -> Double {
        s.values.reduce(0) { $0 + CurrencyConverter.netDisplayValue(for: $1, in: app.displayCurrency) }
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

            if snapshots.isEmpty {
                EditorialEmpty(
                    eyebrow: "Overview · Historical",
                    title: "No quarters",
                    titleItalic: "on the record.",
                    body: "Each snapshot freezes balances and FX at one moment. Four per year is plenty — the series grows with you.",
                    detail: "Snapshots lock when complete; unlock any time to amend.",
                    ctaLabel: "New snapshot",
                    cta: { showingNew = true }
                )
            } else {
                Panel {
                    VStack(spacing: 0) {
                        ResizableHeader(sizer: sizer)
                        ForEach(Array(snapshots.enumerated()), id: \.element.id) { idx, s in
                            row(idx: idx, s: s)
                            if idx < snapshots.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editing) { SnapshotEditorView(snapshot: $0) }
        .sheet(isPresented: $showingNew) {
            NewSnapshotSheet { created in editing = created }
        }
        .onChange(of: app.newSnapshotRequested) { _, requested in
            if requested {
                app.newSnapshotRequested = false
                showingNew = true
            }
        }
        .onAppear {
            if app.newSnapshotRequested {
                app.newSnapshotRequested = false
                showingNew = true
            }
        }
        .confirmationDialog("Delete \(confirmDelete?.label ?? "")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete Snapshot", role: .destructive) {
                if let s = confirmDelete {
                    let cap = undo.capture(snapshot: s)
                    if app.activeSnapshotID == s.id { app.activeSnapshotID = nil }
                    context.delete(s)
                    try? context.save()
                    undo.stash(.snapshot(cap))
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("All \(confirmDelete?.values.count ?? 0) asset values recorded in this snapshot will also be deleted.")
        }
    }

    private func row(idx: Int, s: Snapshot) -> some View {
        HStack(spacing: 0) {
            ResizableCell(sizer: sizer, colID: "snap") {
                HStack(spacing: 10) {
                    if app.activeSnapshotID == s.id {
                        Circle().fill(Color.lInk).frame(width: 6, height: 6)
                    }
                    Text(s.label)
                        .font(Typo.sans(13, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "date") {
                Text(Fmt.date(s.date))
                    .font(Typo.mono(11))
                    .foregroundStyle(Color.lInk3)
            }
            ResizableCell(sizer: sizer, colID: "fx") {
                Text("₹\(String(format: "%.2f", s.usdToInrRate))")
                    .font(Typo.mono(12))
                    .foregroundStyle(Color.lInk2)
            }
            ResizableCell(sizer: sizer, colID: "total") {
                Text(Fmt.compact(totalFor(s), app.displayCurrency))
                    .font(Typo.mono(12.5, weight: .semibold))
                    .foregroundStyle(Color.lInk)
            }
            ResizableCell(sizer: sizer, colID: "status") {
                HStack {
                    Pill(text: s.isLocked ? "🔒 locked" : "✎ draft",
                         emphasis: !s.isLocked)
                    Spacer(minLength: 0)
                }
            }
            ResizableCell(sizer: sizer, colID: "actions") {
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
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }
}
