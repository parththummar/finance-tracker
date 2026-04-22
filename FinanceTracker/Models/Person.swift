import Foundation
import SwiftData

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Account.person)
    var accounts: [Account] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}
