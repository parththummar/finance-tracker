import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

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
        .preferredColorScheme(app.preferredColorScheme)
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
        case .snapshots:  scrollable { SnapshotListView() }
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
