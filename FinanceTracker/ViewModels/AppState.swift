import SwiftUI
import Combine

enum Screen: Hashable {
    case dashboard, breakdown, snapshots, accounts, people, countries, assetTypes, settings
}

final class AppState: ObservableObject {
    @AppStorage("displayCurrency") var displayCurrencyRaw: String = Currency.USD.rawValue
    @AppStorage("labelMode")       var labelModeRaw: String = LabelMode.dollar.rawValue
    @AppStorage("theme")           var themeRaw: String = AppTheme.system.rawValue

    @AppStorage("card.byPerson.style")   var byPersonStyleRaw: String = ChartStyle.donut.rawValue
    @AppStorage("card.byCountry.style")  var byCountryStyleRaw: String = ChartStyle.donut.rawValue
    @AppStorage("card.byCategory.style") var byCategoryStyleRaw: String = ChartStyle.donut.rawValue

    @Published var selectedScreen: Screen = .dashboard
    @Published var activeSnapshotID: UUID? = nil

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
        set { themeRaw = newValue.rawValue; objectWillChange.send() }
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
