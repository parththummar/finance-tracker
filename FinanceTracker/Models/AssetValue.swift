import Foundation
import SwiftData

@Model
final class AssetValue {
    @Attribute(.unique) var id: UUID
    var snapshot: Snapshot?
    var account: Account?
    var nativeValue: Double
    var note: String

    init(snapshot: Snapshot, account: Account, nativeValue: Double, note: String = "") {
        self.id = UUID()
        self.snapshot = snapshot
        self.account = account
        self.nativeValue = nativeValue
        self.note = note
    }
}
