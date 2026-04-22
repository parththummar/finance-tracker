import Foundation

enum CurrencyConverter {
    /// Convert using the rate locked on the snapshot. Never use today's rate for historical values.
    static func convert(nativeValue: Double,
                        from source: Currency,
                        to target: Currency,
                        usdToInrRate: Double) -> Double {
        guard source != target else { return nativeValue }
        switch (source, target) {
        case (.USD, .INR): return nativeValue * usdToInrRate
        case (.INR, .USD): return nativeValue / usdToInrRate
        default:           return nativeValue
        }
    }

    static func displayValue(for assetValue: AssetValue, in target: Currency) -> Double {
        guard let acc = assetValue.account, let snap = assetValue.snapshot else { return 0 }
        return convert(nativeValue: assetValue.nativeValue,
                       from: acc.nativeCurrency,
                       to: target,
                       usdToInrRate: snap.usdToInrRate)
    }
}
