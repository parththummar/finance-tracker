import SwiftUI
import SwiftData

@main
struct FinanceTrackerApp: App {
    let container: ModelContainer

    init() {
        FontRegistrar.registerIfNeeded()
        do {
            container = try ModelContainer(
                for: Person.self, Country.self, AssetType.self,
                Account.self, Snapshot.self, AssetValue.self,
                ExchangeRateHistory.self
            )
            SeedData.seedIfEmpty(context: container.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AppState())
                .environmentObject(UndoStash())
                .frame(minWidth: 1100, minHeight: 1000)
        }
        .modelContainer(container)
        .commands {
            NavCommands()
            SnapshotCommands()
            SearchCommands()
            UndoDeleteCommands()
        }
    }
}
