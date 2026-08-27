import Foundation

struct LowAppetitePreparation: Equatable {
    enum Confidence: String { case emerging = "Emerging", likely = "Likely" }

    let targetCycleDay: Int
    let averageAppetite: Double
    let sampleCount: Int
    let confidence: Confidence

    var headline: String { "A lower-appetite day may be next" }
    var detail: String {
        "Your appetite averaged \(averageAppetite.formatted(.number.precision(.fractionLength(1))))/5 on cycle day \(targetCycleDay) across \(sampleCount) prior check-ins."
    }
}

enum LowAppetitePreparationStore {
    static let completedKey = "lowAppetitePreparationCompleted"

    static func signature(for preparation: LowAppetitePreparation, date: Date = .now) -> String {
        "\(date.isoDateString):cycle-\(preparation.targetCycleDay)"
    }

    static func isCompleted(
        _ preparation: LowAppetitePreparation,
        date: Date = .now,
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.string(forKey: completedKey) == signature(for: preparation, date: date)
    }

    static func markCompleted(
        _ preparation: LowAppetitePreparation,
        date: Date = .now,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(signature(for: preparation, date: date), forKey: completedKey)
    }
}

enum LowAppetitePreparationEngine {
    static func predict(currentCycleDay: Int, history: [ShotCycleCheckIn]) -> LowAppetitePreparation? {
        let target = currentCycleDay + 1
        let comparable = history.filter { $0.cycleDay == target }
        guard comparable.count >= 2 else { return nil }
        let average = Double(comparable.reduce(0) { $0 + $1.appetite }) / Double(comparable.count)
        guard average <= 2.5 else { return nil }
        return .init(
            targetCycleDay: target,
            averageAppetite: average,
            sampleCount: comparable.count,
            confidence: comparable.count >= 3 ? .likely : .emerging
        )
    }
}
