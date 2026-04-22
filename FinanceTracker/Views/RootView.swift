import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            VStack(spacing: 0) {
                TopBar()
                Divider()
                content
            }
        }
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
        case .dashboard:  DashboardView()
        case .breakdown:  BreakdownView()
        case .snapshots:  SnapshotListView()
        case .accounts:   AccountsView()
        case .people:     PeopleView()
        case .countries:  CountriesView()
        case .assetTypes: AssetTypesView()
        case .settings:   SettingsView()
        }
    }
}
