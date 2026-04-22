import SwiftUI
import SwiftData

struct SnapshotEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var allSnapshots: [Snapshot]
    let snapshot: Snapshot
    @State private var confirmingLock = false
    @State private var confirmingDelete = false
    @State private var isFetchingRate = false
    @State private var fetchError: String?
    @State private var showSavedToast = false
    @State private var saveError: String?

    private var previousSnapshot: Snapshot? {
        allSnapshots.first { $0.date < snapshot.date && $0.id != snapshot.id }
    }

    private func previousValue(for account: Account?) -> Double? {
        guard let account, let prev = previousSnapshot else { return nil }
        return prev.values.first { $0.account?.id == account.id }?.nativeValue
    }

    private var liveTotalDisplay: Double {
        snapshot.values.reduce(0.0) { sum, v in
            guard let acc = v.account else { return sum }
            return sum + CurrencyConverter.convert(
                nativeValue: v.nativeValue,
                from: acc.nativeCurrency,
                to: app.displayCurrency,
                usdToInrRate: snapshot.usdToInrRate
            )
        }
    }

    private var previousTotalDisplay: Double? {
        guard let prev = previousSnapshot else { return nil }
        return prev.values.reduce(0.0) { sum, v in
            guard let acc = v.account else { return sum }
            return sum + CurrencyConverter.convert(
                nativeValue: v.nativeValue,
                from: acc.nativeCurrency,
                to: app.displayCurrency,
                usdToInrRate: prev.usdToInrRate
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("ACCOUNT").frame(width: 180, alignment: .leading)
                            Text("PERSON").frame(width: 80, alignment: .leading)
                            Text("CCY").frame(width: 50, alignment: .leading)
                            Spacer()
                            Text("PREV").frame(width: 120, alignment: .trailing)
                            Text("Δ").frame(width: 120, alignment: .trailing)
                            Text("NATIVE VALUE").frame(width: 160, alignment: .trailing)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        Divider()

                        ForEach(Array(snapshot.values.enumerated()), id: \.element.id) { idx, v in
                            row(v)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(idx.isMultiple(of: 2)
                                            ? Color.clear
                                            : Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Divider()
                        totalsRow
                    }
                }

                HStack {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: { Label("Delete Snapshot", systemImage: "trash") }
                    if showSavedToast {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                    if let err = saveError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                    Spacer()
                    Button("Close") { dismiss() }
                    if !snapshot.isLocked {
                        Button { saveDraft() } label: {
                            Label("Save Draft", systemImage: "square.and.arrow.down")
                        }
                        Button(role: .destructive) {
                            confirmingLock = true
                        } label: { Label("Lock Snapshot", systemImage: "lock.fill") }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 900, minHeight: 700)
        .confirmationDialog("Lock \(snapshot.label)?",
                            isPresented: $confirmingLock,
                            titleVisibility: .visible) {
            Button("Lock Snapshot", role: .destructive) {
                snapshot.isLocked = true
                snapshot.lockedAt = .now
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Values become read-only. Exchange rate frozen at \(String(format: "%.2f", snapshot.usdToInrRate)).")
        }
        .confirmationDialog("Delete \(snapshot.label)?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete Snapshot", role: .destructive) {
                context.delete(snapshot)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes this snapshot and all \(snapshot.values.count) account values. Cannot be undone.")
        }
    }

    private var header: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(snapshot.label).font(.title2.bold())
                    Spacer()
                    if snapshot.isLocked {
                        Label("Locked", systemImage: "lock.fill").foregroundStyle(.secondary)
                    } else {
                        Label("Draft", systemImage: "pencil").foregroundStyle(.orange)
                    }
                }
                HStack {
                    Text("Date:")
                    Text(Fmt.date(snapshot.date))
                }
                HStack {
                    Text("USD → INR:")
                    if snapshot.isLocked {
                        Text(String(format: "%.4f", snapshot.usdToInrRate))
                    } else {
                        TextField("rate", value: Binding(
                            get: { snapshot.usdToInrRate },
                            set: { snapshot.usdToInrRate = $0 }
                        ), format: .number)
                        .frame(width: 100)
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
                        .help("Fetch USD→INR for \(Fmt.date(snapshot.date)) from frankfurter.app")
                    }
                }
                if let err = fetchError {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }
        }
    }

    private func saveDraft() {
        do {
            try context.save()
            saveError = nil
            withAnimation { showSavedToast = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                await MainActor.run { withAnimation { showSavedToast = false } }
            }
        } catch {
            saveError = "Save failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func fetchLiveRate() async {
        guard !snapshot.isLocked else { return }
        isFetchingRate = true
        defer { isFetchingRate = false }
        do {
            let r = try await FXService.fetchUSDtoINR(on: snapshot.date)
            snapshot.usdToInrRate = r
            try? context.save()
            fetchError = nil
        } catch {
            fetchError = "Fetch failed: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func row(_ v: AssetValue) -> some View {
        let ccy = v.account?.nativeCurrency ?? .USD
        let prev = previousValue(for: v.account)
        let diff = prev.map { v.nativeValue - $0 }
        HStack {
            Text(v.account?.name ?? "—").frame(width: 180, alignment: .leading)
            Text(v.account?.person?.name ?? "").frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
            Text(ccy.rawValue).frame(width: 50, alignment: .leading)
            Spacer()

            Group {
                if let prev {
                    Text(Fmt.currency(prev, ccy))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .font(.callout.monospacedDigit())
            .frame(width: 120, alignment: .trailing)

            Group {
                if let diff {
                    Text(Fmt.signedDelta(diff, ccy))
                        .foregroundStyle(Palette.deltaColor(diff))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .font(.callout.monospacedDigit())
            .frame(width: 120, alignment: .trailing)

            if snapshot.isLocked {
                Text(Fmt.currency(v.nativeValue, ccy))
                    .font(.body.monospacedDigit())
                    .frame(width: 160, alignment: .trailing)
            } else {
                TextField("value", value: Binding(
                    get: { v.nativeValue },
                    set: { v.nativeValue = $0 }
                ), format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 160)
            }
        }
        .font(.callout)
    }

    private var totalsRow: some View {
        let prevTotal = previousTotalDisplay
        let total = liveTotalDisplay
        let diff = prevTotal.map { total - $0 }
        let ccy = app.displayCurrency
        return HStack {
            Text("TOTAL (\(ccy.rawValue))")
                .font(.caption.bold())
                .frame(width: 180, alignment: .leading)
            Spacer()

            Group {
                if let prevTotal {
                    Text(Fmt.currency(prevTotal, ccy))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .font(.body.monospacedDigit())
            .frame(width: 120, alignment: .trailing)

            Group {
                if let diff {
                    Text(Fmt.signedDelta(diff, ccy))
                        .foregroundStyle(Palette.deltaColor(diff))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .font(.body.monospacedDigit())
            .frame(width: 120, alignment: .trailing)

            Text(Fmt.currency(total, ccy))
                .font(.body.bold().monospacedDigit())
                .frame(width: 160, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
    }
}
