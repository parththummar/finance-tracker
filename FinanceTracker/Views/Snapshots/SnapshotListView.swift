import SwiftUI
import SwiftData

struct SnapshotListView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @State private var editing: Snapshot?
    @State private var showingNew = false
    @State private var confirmDelete: Snapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Snapshots").font(.title2.bold())
                Spacer()
                Button {
                    showingNew = true
                } label: { Label("New Snapshot", systemImage: "plus") }
            }

            List(snapshots) { s in
                HStack {
                    VStack(alignment: .leading) {
                        Text(s.label).font(.headline)
                        Text(Fmt.date(s.date)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("1 USD = \(String(format: "%.2f", s.usdToInrRate)) INR")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if s.isLocked {
                        Label("Locked", systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("Draft", systemImage: "pencil").font(.caption).foregroundStyle(.orange)
                    }
                    Button("Open") { editing = s }
                    Menu {
                        if s.isLocked {
                            Button("Unlock") {
                                s.isLocked = false
                                s.lockedAt = nil
                                try? context.save()
                            }
                        }
                        Button("Delete…", role: .destructive) {
                            confirmDelete = s
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .padding(16)
        .sheet(item: $editing) { SnapshotEditorView(snapshot: $0) }
        .sheet(isPresented: $showingNew) {
            NewSnapshotSheet { created in
                editing = created
            }
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
}
