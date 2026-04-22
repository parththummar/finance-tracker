import SwiftUI
import SwiftData

struct NewSnapshotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query private var accounts: [Account]

    @State private var date: Date = Calendar.current.startOfDay(for: Date())
    @State private var rate: Double = 83.0
    @State private var copyPrevious: Bool = true
    @State private var errorMessage: String?
    @State private var isFetchingRate: Bool = false
    @State private var rateFetchedAt: Date?
    var onCreated: (Snapshot) -> Void = { _ in }

    private let minGapDays = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Snapshot").font(.title2.bold())

            Form {
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)

                HStack {
                    Text("USD → INR rate")
                    Spacer()
                    Button {
                        Task { await fetchLiveRate() }
                    } label: {
                        if isFetchingRate {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Fetch live", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isFetchingRate)
                    .help("Fetch current USD→INR from frankfurter.app")
                    TextField("rate", value: $rate, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                .onAppear {
                    if let prev = snapshots.first {
                        rate = prev.usdToInrRate
                    }
                }

                if let fetched = rateFetchedAt {
                    Text("Live rate fetched \(Fmt.date(fetched)).")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Toggle("Copy values from previous snapshot", isOn: $copyPrevious)
                    .help("Pre-fill each active account with its prior value. Edit after creation.")
            }
            .formStyle(.grouped)

            if let err = errorMessage {
                Text(err).foregroundStyle(.red).font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button {
                    create()
                } label: {
                    Label("Create", systemImage: "plus")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 500)
    }

    @MainActor
    private func fetchLiveRate() async {
        isFetchingRate = true
        defer { isFetchingRate = false }
        do {
            let r = try await FXService.fetchUSDtoINR(on: date)
            rate = r
            rateFetchedAt = Date()
            errorMessage = nil
        } catch {
            errorMessage = "Fetch failed: \(error.localizedDescription). Enter rate manually."
        }
    }

    private func create() {
        let cal = Calendar.current
        let chosen = cal.startOfDay(for: date)

        if chosen > cal.startOfDay(for: Date()) {
            errorMessage = "Future snapshots not allowed."
            return
        }

        for s in snapshots {
            let existing = cal.startOfDay(for: s.date)
            let days = abs(cal.dateComponents([.day], from: existing, to: chosen).day ?? 0)
            if days < minGapDays {
                errorMessage = "Must be at least \(minGapDays) days from existing snapshot (\(Fmt.date(existing))). Choose a different date."
                return
            }
        }

        if rate <= 0 {
            errorMessage = "Exchange rate must be positive."
            return
        }

        let snap = Snapshot(date: chosen, label: Fmt.date(chosen), usdToInrRate: rate)
        context.insert(snap)

        let previous = snapshots.first
        let activeAccounts = accounts.filter { $0.isActive }
        for acc in activeAccounts {
            let prefill: Double
            if copyPrevious, let prev = previous,
               let prevValue = prev.values.first(where: { $0.account?.id == acc.id }) {
                prefill = prevValue.nativeValue
            } else {
                prefill = 0
            }
            let av = AssetValue(snapshot: snap, account: acc, nativeValue: prefill)
            context.insert(av)
        }

        do {
            try context.save()
            onCreated(snap)
            dismiss()
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
