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

    /// Same as displayValue but flips the sign for `.debt` accounts so they
    /// subtract from net worth regardless of how the user entered the balance.
    static func netDisplayValue(for assetValue: AssetValue, in target: Currency) -> Double {
        let raw = displayValue(for: assetValue, in: target)
        let isDebt = assetValue.account?.assetType?.category == .debt
        let magnitude = abs(raw)
        return isDebt ? -magnitude : raw
    }
}
