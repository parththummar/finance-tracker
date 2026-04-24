import SwiftUI
import SwiftData

@main
struct FinanceTrackerApp: App {
    let container: ModelContainer
    @StateObject private var app = AppState()
    @StateObject private var undo = UndoStash()

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
        _ = BackupService.runIfDue()
        ReminderScheduler.check(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(undo)
                .preferredColorScheme(app.preferredColorScheme)
        }
        .modelContainer(container)
        .defaultSize(width: 1400, height: 1000)
        .windowResizability(.contentMinSize)
        .commands {
            NavCommands()
            SnapshotCommands()
            SearchCommands()
            UndoDeleteCommands()
        }
    }
}
