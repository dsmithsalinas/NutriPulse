import Foundation

struct DailySummary: Identifiable {
    let date: Date
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double

    var id: String { date.isoDateString }
    var hasData: Bool { calories > 0 }

    /// Food entries are a lower bound, never proof of a complete day's intake.
    /// Reaching a minimum confirms a win; a smaller total cannot confirm a miss.
    func proteinFloorHit(target: Double?) -> Bool? {
        guard hasData, let target, target > 0, proteinG >= target else { return nil }
        return true
    }
}
