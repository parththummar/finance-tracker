import Foundation

enum Fmt {
    static func currency(_ value: Double, _ ccy: Currency, fractionDigits: Int = 0) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = ccy.rawValue
        f.currencySymbol = ccy.symbol
        f.maximumFractionDigits = fractionDigits
        f.minimumFractionDigits = fractionDigits
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percent(_ fraction: Double, fractionDigits: Int = 1) -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = fractionDigits
        f.minimumFractionDigits = fractionDigits
        return f.string(from: NSNumber(value: fraction)) ?? "\(fraction)%"
    }

    static func label(value: Double, share: Double, ccy: Currency, mode: LabelMode) -> String {
        switch mode {
        case .dollar:  return currency(value, ccy)
        case .percent: return percent(share)
        case .both:    return "\(currency(value, ccy)) · \(percent(share))"
        }
    }

    static func date(_ d: Date, style: DateFormatter.Style = .medium) -> String {
        let f = DateFormatter()
        f.dateStyle = style
        return f.string(from: d)
    }

    static func signedDelta(_ value: Double, _ ccy: Currency) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(currency(abs(value), ccy))"
    }
}
