import Foundation

struct DailySummary: Identifiable {
    let date: Date
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double

    var unavailableMacros: Set<NutritionMacro> = []
    var nutritionSources: [NutritionMacro: String] = [:]

    var id: String { date.isoDateString }
    var hasProteinData: Bool {
        !unavailableMacros.contains(.protein) && (calories > 0 || nutritionSources[.protein] != nil)
    }
    var hasCalorieData: Bool {
        !unavailableMacros.contains(.calories) && (calories > 0 || nutritionSources[.calories] != nil)
    }
    // Progress's floor-day evidence requires readable protein, not a complete calorie diary.
    var hasData: Bool { hasProteinData }

    /// Food entries are a lower bound, never proof of a complete day's intake.
    /// Reaching a minimum confirms a win; a smaller total cannot confirm a miss.
    func proteinFloorHit(target: Double?) -> Bool? {
        guard !unavailableMacros.contains(.protein), hasData, let target, target > 0, proteinG >= target else { return nil }
        return true
    }
}
