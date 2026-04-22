import Foundation
import SwiftData

@Model
final class Snapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var label: String
    var usdToInrRate: Double
    var isLocked: Bool
    var lockedAt: Date?
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AssetValue.snapshot)
    var values: [AssetValue] = []

    init(date: Date, label: String, usdToInrRate: Double, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.label = label
        self.usdToInrRate = usdToInrRate
        self.isLocked = false
        self.notes = notes
        self.createdAt = .now
    }
}

@Model
final class ExchangeRateHistory {
    @Attribute(.unique) var id: UUID
    var date: Date
    var usdToInr: Double
    var source: String

    init(date: Date, usdToInr: Double, source: String) {
        self.id = UUID()
        self.date = date
        self.usdToInr = usdToInr
        self.source = source
    }
}
