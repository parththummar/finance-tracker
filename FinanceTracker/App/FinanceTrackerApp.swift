import SwiftUI
import SwiftData

@main
struct FinanceTrackerApp: App {
    let container: ModelContainer
    @StateObject private var app = AppState()
    @StateObject private var undo = UndoStash()
    @NSApplicationDelegateAdaptor(QuitBackupDelegate.self) private var quitDelegate

    init() {
        FontRegistrar.registerIfNeeded()
        BackupService.applyPendingRestoreIfAny()
        do {
            let schema = Schema([
                Person.self, Country.self, AssetType.self,
                Account.self, Snapshot.self, AssetValue.self,
                Receivable.self, ReceivableValue.self,
                ExchangeRateHistory.self
            ])
            guard let storeURL = BackupService.storeURL() else {
                fatalError("Could not resolve store URL")
            }
            let config = ModelConfiguration(schema: schema, url: storeURL)
            container = try ModelContainer(for: schema, configurations: [config])
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
                .onChange(of: app.theme) { _, newTheme in
                    applyWindowAppearance(newTheme)
                }
                .onAppear { applyWindowAppearance(app.theme) }
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

    private func applyWindowAppearance(_ theme: AppTheme) {
        let appearance: NSAppearance? = {
            switch theme {
            case .system: return nil
            case .light:  return NSAppearance(named: .aqua)
            case .dark:   return NSAppearance(named: .darkAqua)
            }
        }()
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.appearance = appearance
            }
        }
    }
}
