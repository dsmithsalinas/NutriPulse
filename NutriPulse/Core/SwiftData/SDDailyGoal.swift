import SwiftData
import Foundation

// Pull-only cache — never written locally, only populated by SyncEngine pulls.
@Model
final class SDDailyGoal {
    @Attribute(.unique) var id: UUID
    // Optional so SwiftData can migrate existing stores in place. Rows cached before
    // this field existed carry nil and are simply ignored by fetchGoal — they get
    // overwritten (with an owner) on the next pull. Without an owner, the next user
    // to sign in on this device inherited the previous user's calorie and macro targets.
    var userId: UUID?
    var effectiveDate: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var waterMlTarget: Double

    init(
        id: UUID,
        userId: UUID?,
        effectiveDate: String,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double,
        waterMlTarget: Double
    ) {
        self.id            = id
        self.userId        = userId
        self.effectiveDate = effectiveDate
        self.calories      = calories
        self.proteinG      = proteinG
        self.carbsG        = carbsG
        self.fatG          = fatG
        self.fiberG        = fiberG
        self.waterMlTarget = waterMlTarget
    }

    var asDailyGoal: DailyGoal? {
        guard let userId else { return nil }
        return DailyGoal(
            id: id,
            userId: userId,
            effectiveDate: effectiveDate,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            waterMlTarget: waterMlTarget
        )
    }
}
