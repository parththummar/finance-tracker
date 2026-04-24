import SwiftUI
import SwiftData

struct SnapshotEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var app: AppState
    @EnvironmentObject var undo: UndoStash
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
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    valuesPanel
                    notesPanel

                    if let err = saveError {
                        errorBanner(err)
                    }
                }
                .padding(24)
            }

            Divider().overlay(Color.lLine)
            footer
        }
        .background(Color.lBg)
        .frame(minWidth: 980, minHeight: 680)
        .overlay(alignment: .top) {
            if showSavedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.lGain)
                    Text("Draft saved")
                        .font(Typo.sans(12.5, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color.lPanel)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lLine, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSavedToast)
        .confirmationDialog("Lock \(snapshot.label)?",
                            isPresented: $confirmingLock,
                            titleVisibility: .visible) {
            Button("Lock Snapshot", role: .destructive) {
                guard snapshot.usdToInrRate > 0 else {
                    saveError = "Exchange rate must be positive before locking."
                    return
                }
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
                let cap = undo.capture(snapshot: snapshot)
                if app.activeSnapshotID == snapshot.id { app.activeSnapshotID = nil }
                context.delete(snapshot)
                try? context.save()
                undo.stash(.snapshot(cap))
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes this snapshot and all \(snapshot.values.count) account values.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SNAPSHOT · \(Fmt.date(snapshot.date).uppercased())")
                        .font(Typo.eyebrow).tracking(1.5)
                        .foregroundStyle(Color.lInk3)
                    HStack(spacing: 10) {
                        Text(snapshot.label)
                            .font(Typo.serifNum(26))
                            .foregroundStyle(Color.lInk)
                        Pill(text: snapshot.isLocked ? "🔒 locked" : "✎ draft",
                             emphasis: !snapshot.isLocked)
                    }
                    Text(snapshot.isLocked
                         ? "Locked \(snapshot.lockedAt.map { Fmt.date($0) } ?? "") · values frozen"
                         : "Draft · edit freely until locked")
                        .font(Typo.serifItalic(13))
                        .foregroundStyle(Color.lInk3)
                }
                Spacer()
                rateBlock
            }
            if let err = fetchError {
                Text(err)
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lLoss)
            }
        }
        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    private var rateBlock: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("USD → INR")
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            if snapshot.isLocked {
                Text(String(format: "₹%.4f", snapshot.usdToInrRate))
                    .font(Typo.mono(14, weight: .semibold))
                    .foregroundStyle(Color.lInk)
            } else {
                HStack(spacing: 6) {
                    TextField("", value: Binding(
                        get: { snapshot.usdToInrRate },
                        set: { snapshot.usdToInrRate = $0 }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(Typo.mono(13))
                    .frame(width: 90)
                    Button {
                        Task { await fetchLiveRate() }
                    } label: {
                        if isFetchingRate {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(Color.lInk2)
                        }
                    }
                    .disabled(isFetchingRate)
                    .buttonStyle(.plain)
                    .help("Fetch USD→INR for \(Fmt.date(snapshot.date)) from frankfurter.app")
                }
                if snapshot.usdToInrRate <= 0 {
                    Text("Rate must be > 0")
                        .font(Typo.mono(10, weight: .medium))
                        .foregroundStyle(Color.lLoss)
                }
            }
        }
    }

    // MARK: - Values panel

    private var valuesPanel: some View {
        Panel {
            VStack(spacing: 0) {
                PanelHead(title: "Account values", meta: "\(snapshot.values.count) rows")
                rowHeader
                ForEach(Array(snapshot.values.enumerated()), id: \.element.id) { idx, v in
                    row(v, idx: idx)
                    if idx < snapshot.values.count - 1 {
                        Divider().overlay(Color.lLine)
                    }
                }
                Divider().overlay(Color.lLine)
                totalsRow
            }
        }
    }

    private var rowHeader: some View {
        HStack {
            Text("Account").frame(maxWidth: .infinity, alignment: .leading)
            Text("Person").frame(width: 110, alignment: .leading)
            Text("CCY").frame(width: 50, alignment: .leading)
            Text("Prev").frame(width: 130, alignment: .trailing)
            Text("Δ").frame(width: 130, alignment: .trailing)
            Text("Native value").frame(width: 170, alignment: .trailing)
        }
        .font(Typo.eyebrow).tracking(1.2).foregroundStyle(Color.lInk3)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    @ViewBuilder
    private func row(_ v: AssetValue, idx: Int) -> some View {
        let ccy = v.account?.nativeCurrency ?? .USD
        let prev = previousValue(for: v.account)
        let diff = prev.map { v.nativeValue - $0 }
        HStack {
            Text(v.account?.name ?? "—")
                .font(Typo.sans(13, weight: .medium))
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(v.account?.person?.name ?? "—")
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 110, alignment: .leading)

            Text(ccy.rawValue)
                .font(Typo.mono(11))
                .foregroundStyle(Color.lInk3)
                .frame(width: 50, alignment: .leading)

            Group {
                if let prev {
                    Text(Fmt.currency(prev, ccy))
                        .foregroundStyle(Color.lInk3)
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12))
            .frame(width: 130, alignment: .trailing)

            Group {
                if let diff {
                    Text(Fmt.signedDelta(diff, ccy))
                        .foregroundStyle(diff == 0 ? Color.lInk3 : (diff > 0 ? Color.lGain : Color.lLoss))
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12, weight: .medium))
            .frame(width: 130, alignment: .trailing)

            if snapshot.isLocked {
                Text(Fmt.currency(v.nativeValue, ccy))
                    .font(Typo.mono(13, weight: .semibold))
                    .foregroundStyle(Color.lInk)
                    .frame(width: 170, alignment: .trailing)
            } else {
                TextField("", value: Binding(
                    get: { v.nativeValue },
                    set: { v.nativeValue = $0 }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .font(Typo.mono(13))
                .frame(width: 170)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(idx.isMultiple(of: 2) ? Color.clear : Color.lSunken.opacity(0.5))
    }

    private var totalsRow: some View {
        let prevTotal = previousTotalDisplay
        let total = liveTotalDisplay
        let diff = prevTotal.map { total - $0 }
        let ccy = app.displayCurrency
        return HStack {
            Text("TOTAL (\(ccy.rawValue))")
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let prevTotal {
                    Text(Fmt.currency(prevTotal, ccy))
                        .foregroundStyle(Color.lInk3)
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12))
            .frame(width: 130, alignment: .trailing)

            Group {
                if let diff {
                    Text(Fmt.signedDelta(diff, ccy))
                        .foregroundStyle(diff == 0 ? Color.lInk3 : (diff > 0 ? Color.lGain : Color.lLoss))
                } else {
                    Text("—").foregroundStyle(Color.lInk3)
                }
            }
            .font(Typo.mono(12, weight: .semibold))
            .frame(width: 130, alignment: .trailing)

            Text(Fmt.currency(total, ccy))
                .font(Typo.mono(14, weight: .bold))
                .foregroundStyle(Color.lInk)
                .frame(width: 170, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Color.lSunken)
    }

    // MARK: - Footer / misc

    private var footer: some View {
        HStack(spacing: 10) {
            GhostButton(action: { confirmingDelete = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "trash").font(.system(size: 10, weight: .bold))
                    Text("Delete")
                }
            }
            Spacer()
            GhostButton(action: { dismiss() }) { Text("Close") }
            if !snapshot.isLocked {
                GhostButton(action: { saveDraft(dismissAfter: false) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 10, weight: .bold))
                        Text("Save Draft")
                    }
                }
                GhostButton(action: { saveDraft(dismissAfter: true) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 10, weight: .bold))
                        Text("Save & Close")
                    }
                }
                PrimaryButton(action: { confirmingLock = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                        Text("Lock Snapshot")
                    }
                }
                .disabled(snapshot.usdToInrRate <= 0)
                .opacity(snapshot.usdToInrRate <= 0 ? 0.5 : 1)
                .help(snapshot.usdToInrRate <= 0 ? "Set a positive USD→INR rate first" : "Freeze this snapshot")
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    private var notesPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Notes", meta: snapshot.isLocked ? "read-only" : "editable")
                if snapshot.isLocked {
                    Group {
                        if snapshot.notes.isEmpty {
                            Text("No notes recorded.")
                                .font(Typo.serifItalic(12.5))
                                .foregroundStyle(Color.lInk3)
                        } else {
                            Text(snapshot.notes)
                                .font(Typo.serifItalic(13))
                                .foregroundStyle(Color.lInk2)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                } else {
                    TextField(
                        "Context, notable events, assumptions…",
                        text: Binding(
                            get: { snapshot.notes },
                            set: { snapshot.notes = $0 }
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .font(Typo.sans(12.5))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(3...10)
                    .padding(14)
                    .background(Color.lSunken.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lLine, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(16)
                }
            }
        }
    }

    private func errorBanner(_ err: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.lLoss)
            Text(err).font(Typo.sans(12)).foregroundStyle(Color.lLoss)
        }
        .padding(12)
        .background(Color.lLossSoft.opacity(0.4))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lLoss.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func saveDraft(dismissAfter: Bool = false) {
        guard snapshot.usdToInrRate > 0 else {
            saveError = "Exchange rate must be positive before saving."
            return
        }
        do {
            try context.save()
            saveError = nil
            withAnimation { showSavedToast = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    withAnimation { showSavedToast = false }
                    if dismissAfter { dismiss() }
                }
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
}
