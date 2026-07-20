import Foundation

enum WorkoutSource: String, Codable {
    case manual
    case healthkit
}

// The five options the manual entry sheet offers. HealthKit imports are NOT
// constrained to this list — they keep whatever activity type HealthKit reports.
enum ManualActivityType: String, CaseIterable, Codable {
    case walk
    case strength
    case cycling
    case running
    case other

    var displayName: String {
        switch self {
        case .walk:     return "Walk"
        case .strength: return "Strength"
        case .cycling:  return "Cycling"
        case .running:  return "Running"
        case .other:    return "Workout"
        }
    }

    var symbolName: String {
        switch self {
        case .walk:     return "figure.walk"
        case .strength: return "dumbbell.fill"
        case .cycling:  return "figure.outdoor.cycle"
        case .running:  return "figure.run"
        case .other:    return "figure.mixed.cardio"
        }
    }
}

struct WorkoutLog: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let loggedAt: Date
    let logDate: String         // "YYYY-MM-DD" — same no-timezone convention as FoodLog
    let activityType: String    // manual slug or HealthKit slug; `source` says which
    let durationMinutes: Double
    let activeCalories: Double?
    let distanceMeters: Double?
    let source: WorkoutSource
    let healthKitUUID: String?  // HKWorkout.uuid for imports; nil for manual
    let startedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId          = "user_id"
        case loggedAt        = "logged_at"
        case logDate         = "log_date"
        case activityType    = "activity_type"
        case durationMinutes = "duration_minutes"
        case activeCalories  = "active_calories"
        case distanceMeters  = "distance_meters"
        case source
        case healthKitUUID   = "healthkit_uuid"
        case startedAt       = "started_at"
    }

    var displayName: String {
        if let manual = ManualActivityType(rawValue: activityType) {
            return manual.displayName
        }
        return Self.humanize(activityType)
    }

    var symbolName: String {
        if let manual = ManualActivityType(rawValue: activityType) {
            return manual.symbolName
        }
        return Self.healthKitSymbols[activityType] ?? "figure.mixed.cardio"
    }

    // "traditionalStrengthTraining" → "Traditional Strength Training". Covers the
    // long tail of HealthKit slugs that have no entry in healthKitSymbols.
    private static func humanize(_ slug: String) -> String {
        var spaced = ""
        for char in slug {
            if char.isUppercase { spaced.append(" ") }
            spaced.append(char)
        }
        return spaced.capitalized
    }

    // SF Symbols for the HealthKit activity types we expect to see most. Anything
    // absent falls back to the generic figure — display-only, so an unmapped slug
    // is a cosmetic gap, never an error.
    private static let healthKitSymbols: [String: String] = [
        "walking":                      "figure.walk",
        "running":                      "figure.run",
        "cycling":                      "figure.outdoor.cycle",
        "hiking":                       "figure.hiking",
        "yoga":                         "figure.yoga",
        "traditionalStrengthTraining":  "dumbbell.fill",
        "functionalStrengthTraining":   "dumbbell.fill",
        "highIntensityIntervalTraining": "figure.highintensity.intervaltraining",
        "swimming":                     "figure.pool.swim",
        "elliptical":                   "figure.elliptical",
        "rowing":                       "figure.rower",
        "pilates":                      "figure.pilates",
        "stairClimbing":                "figure.stair.stepper",
        "coreTraining":                 "figure.core.training",
        "dance":                        "figure.dance",
        "tennis":                       "figure.tennis",
        "golf":                         "figure.golf",
        "mixedCardio":                  "figure.mixed.cardio",
    ]
}
