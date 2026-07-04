import SwiftData
import Foundation

@Model
final class SDWaterLog {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var logDate: String
    var amountMl: Double
    var loggedAt: Date
    var syncState: String  // "pendingCreate" | "synced"

    init(
        id: UUID = UUID(),
        userId: UUID,
        logDate: String,
        amountMl: Double,
        loggedAt: Date = .now,
        syncState: String = "pendingCreate"
    ) {
        self.id        = id
        self.userId    = userId
        self.logDate   = logDate
        self.amountMl  = amountMl
        self.loggedAt  = loggedAt
        self.syncState = syncState
    }
}
