import SwiftData
import Foundation

// Pull-only cache — never written locally, only populated by SyncEngine pulls.
@Model
final class SDDailyGoal {
    @Attribute(.unique) var id: UUID
    var effectiveDate: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var waterMlTarget: Double

    init(
        id: UUID,
        effectiveDate: String,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double,
        waterMlTarget: Double
    ) {
        self.id            = id
        self.effectiveDate = effectiveDate
        self.calories      = calories
        self.proteinG      = proteinG
        self.carbsG        = carbsG
        self.fatG          = fatG
        self.fiberG        = fiberG
        self.waterMlTarget = waterMlTarget
    }

    var asDailyGoal: DailyGoal {
        DailyGoal(
            id: id,
            userId: UUID(),  // placeholder — userId not needed for display
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
