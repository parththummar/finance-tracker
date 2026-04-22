import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var app: AppState

    struct Item: Identifiable {
        let id = UUID()
        let screen: Screen
        let title: String
        let icon: String
    }

    private let primary: [Item] = [
        .init(screen: .dashboard, title: "Dashboard", icon: "chart.pie.fill"),
        .init(screen: .breakdown, title: "Breakdown", icon: "square.grid.2x2.fill"),
        .init(screen: .snapshots, title: "Snapshots", icon: "calendar")
    ]
    private let manage: [Item] = [
        .init(screen: .accounts,   title: "Accounts",    icon: "creditcard.fill"),
        .init(screen: .people,     title: "People",      icon: "person.2.fill"),
        .init(screen: .countries,  title: "Countries",   icon: "globe"),
        .init(screen: .assetTypes, title: "Asset Types", icon: "tag.fill")
    ]

    var body: some View {
        List(selection: Binding(
            get: { app.selectedScreen },
            set: { app.selectedScreen = $0 ?? .dashboard }
        )) {
            Section("Overview") { ForEach(primary) { row($0) } }
            Section("Manage")   { ForEach(manage)  { row($0) } }
            Section {
                row(.init(screen: .settings, title: "Settings", icon: "gear"))
            }
        }
        .navigationTitle("💰 Finance")
        .frame(minWidth: 200)
    }

    private func row(_ item: Item) -> some View {
        Label(item.title, systemImage: item.icon).tag(item.screen)
    }
}
