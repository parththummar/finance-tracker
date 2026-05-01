import SwiftUI
import AppKit
import Combine

enum Screen: Hashable {
    case dashboard, breakdown, trends, snapshots, diff, reports, accounts, people, countries, assetTypes, settings
}

final class AppState: ObservableObject {
    @AppStorage("displayCurrency") var displayCurrencyRaw: String = Currency.USD.rawValue
    @AppStorage("labelMode")       var labelModeRaw: String = LabelMode.dollar.rawValue
    @AppStorage("theme")           var themeRaw: String = AppTheme.system.rawValue
    @AppStorage("includeIlliquidInNetWorth") var includeIlliquidInNetWorth: Bool = true
    @AppStorage("netWorthGoal") var netWorthGoal: Double = 0  // 0 = disabled
    @AppStorage("netWorthGoalCurrencyRaw") var netWorthGoalCurrencyRaw: String = Currency.USD.rawValue
    @AppStorage("compactMode") var compactMode: Bool = false

    var netWorthGoalCurrency: Currency {
        get { Currency(rawValue: netWorthGoalCurrencyRaw) ?? .USD }
        set { netWorthGoalCurrencyRaw = newValue.rawValue; objectWillChange.send() }
    }

    @AppStorage("card.byPerson.style")   var byPersonStyleRaw: String = ChartStyle.donut.rawValue
    @AppStorage("card.byCountry.style")  var byCountryStyleRaw: String = ChartStyle.donut.rawValue
    @AppStorage("card.byCategory.style") var byCategoryStyleRaw: String = ChartStyle.donut.rawValue

    @Published var selectedScreen: Screen = .dashboard
    @Published var activeSnapshotID: UUID? = nil
    @Published var newSnapshotRequested: Bool = false
    @Published var pendingBreakdownFilter: PendingFilter? = nil
    @Published var globalSearchFocusTick: Int = 0

    var displayCurrency: Currency {
        get { Currency(rawValue: displayCurrencyRaw) ?? .USD }
        set { displayCurrencyRaw = newValue.rawValue; objectWillChange.send() }
    }
    var labelMode: LabelMode {
        get { LabelMode(rawValue: labelModeRaw) ?? .dollar }
        set { labelModeRaw = newValue.rawValue; objectWillChange.send() }
    }
    var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .system }
        set {
            themeRaw = newValue.rawValue
            objectWillChange.send()
            applyAppearance()
        }
    }

    init() {}

    func applyAppearance() {
        // Theme switching is handled via `.preferredColorScheme` on the WindowGroup.
        // Setting NSApp.appearance directly conflicts with that and causes the
        // first toggle back to .system to appear stuck.
    }
    var byPersonStyle: ChartStyle {
        get { ChartStyle(rawValue: byPersonStyleRaw) ?? .donut }
        set { byPersonStyleRaw = newValue.rawValue; objectWillChange.send() }
    }
    var byCountryStyle: ChartStyle {
        get { ChartStyle(rawValue: byCountryStyleRaw) ?? .donut }
        set { byCountryStyleRaw = newValue.rawValue; objectWillChange.send() }
    }
    var byCategoryStyle: ChartStyle {
        get { ChartStyle(rawValue: byCategoryStyleRaw) ?? .donut }
        set { byCategoryStyleRaw = newValue.rawValue; objectWillChange.send() }
    }

    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
