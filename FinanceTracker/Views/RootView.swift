import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var undo: UndoStash
    @Environment(\.modelContext) private var context
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Query private var people: [Person]
    @Query private var countries: [Country]
    @Query private var types: [AssetType]
    @Query private var accounts: [Account]
    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            VStack(spacing: 0) {
                TopBar()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.lBg)
            }
        }
        .background(Color.lBg)
        .overlay(alignment: .bottom) { UndoToast() }
        .focusedSceneValue(\.appState, app)
        .focusedSceneValue(\.undoStash, undo)
        .focusedSceneValue(\.sceneModelContext, context)
        .focusedSceneValue(\.restoreDelete) {
            undo.restore(
                context: context,
                people: people,
                countries: countries,
                types: types,
                accounts: accounts,
                snapshots: snapshots
            )
        }
        .onAppear {
            if app.activeSnapshotID == nil, let latest = snapshots.first {
                app.activeSnapshotID = latest.id
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.selectedScreen {
        case .dashboard:  scrollable { DashboardView() }
        case .breakdown:  scrollable { BreakdownView() }
        case .trends:     scrollable { TrendsView() }
        case .snapshots:  scrollable { SnapshotListView() }
        case .diff:       scrollable { SnapshotDiffView() }
        case .settings:   scrollable { SettingsView() }
        case .accounts:   paged { AccountsView() }
        case .people:     paged { PeopleView() }
        case .countries:  paged { CountriesView() }
        case .assetTypes: paged { AssetTypesView() }
        }
    }

    @ViewBuilder
    private func scrollable<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        ScrollView(.vertical) {
            v()
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: 1400, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func paged<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        v()
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: 1400, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
