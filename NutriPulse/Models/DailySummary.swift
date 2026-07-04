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
}
