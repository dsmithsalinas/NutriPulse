import Foundation

enum GoalTrackingSource: String, CaseIterable, Identifiable {
    case appleHealth
    case foodLogs
    case waterLogs
    case workoutLogs
    case bodyLogs
    case manualBoolean
    case manualNumber
    case manualRating

    var id: String { rawValue }

    static let automatic: [GoalTrackingSource] = [
        .appleHealth, .foodLogs, .waterLogs, .workoutLogs,
    ]
    static let manual: [GoalTrackingSource] = [.manualBoolean, .manualNumber, .manualRating]

    var title: String {
        switch self {
        case .appleHealth: "Apple Health"
        case .foodLogs: "Food & protein logs"
        case .waterLogs: "Water logs"
        case .workoutLogs: "Workout logs"
        case .bodyLogs: "Body measurements"
        case .manualBoolean: "Yes / No"
        case .manualNumber: "Number"
        case .manualRating: "1–5 rating"
        }
    }

    var detail: String {
        switch self {
        case .appleHealth: "Steps, sleep, energy, heart rate, and HRV."
        case .foodLogs: "Uses meals you log in Footing."
        case .waterLogs: "Uses water you log in Footing."
        case .workoutLogs: "Uses workouts from Footing and Apple Health."
        case .bodyLogs: "Uses weight entries saved in Footing."
        case .manualBoolean: "A quick completed or not completed check-in."
        case .manualNumber: "Enter a number whenever you check in."
        case .manualRating: "Rate mood, energy, pain, stress, or another feeling."
        }
    }

    var symbol: String {
        switch self {
        case .appleHealth: "heart.fill"
        case .foodLogs: "fork.knife"
        case .waterLogs: "drop.fill"
        case .workoutLogs: "figure.run"
        case .bodyLogs: "scalemass.fill"
        case .manualBoolean: "checkmark.circle.fill"
        case .manualNumber: "number.square.fill"
        case .manualRating: "star.square.fill"
        }
    }

    var sourceType: GoalSourceType {
        switch self {
        case .manualBoolean: .manualBoolean
        case .manualNumber: .manualNumber
        case .manualRating: .manualRating
        default: .automatic
        }
    }

    var metrics: [GoalSourceMetric] {
        switch self {
        case .appleHealth: [.steps, .sleepDuration, .activeEnergy, .restingHeartRate, .hrv]
        case .foodLogs: [.protein]
        case .waterLogs: [.water]
        case .workoutLogs: [.workouts, .workoutMinutes]
        case .bodyLogs: [.weight]
        case .manualBoolean, .manualNumber, .manualRating: []
        }
    }
}

extension GoalSourceMetric {
    var displayName: String {
        switch self {
        case .steps: "Steps"
        case .workouts: "Workouts"
        case .workoutMinutes: "Workout minutes"
        case .sleepDuration: "Sleep duration"
        case .weight: "Weight"
        case .protein: "Protein target days"
        case .water: "Water"
        case .activeEnergy: "Active energy"
        case .restingHeartRate: "Resting heart rate"
        case .hrv: "Heart-rate variability"
        }
    }

    var sourceDisplayName: String {
        switch self {
        case .protein: "Food & protein logs"
        case .water: "Water logs"
        case .workouts, .workoutMinutes: "Footing + Apple Health workouts"
        case .weight: "Body measurements"
        default: "Apple Health"
        }
    }
}

struct GoalDraft {
    var title: String
    var detail: String
    var period: GoalPeriod
    var durationDays: Int
    var trackingSource: GoalTrackingSource
    var sourceMetric: GoalSourceMetric?
    var kind: GoalMeasurementKind
    var aggregation: GoalAggregation
    var comparison: GoalComparison
    var targetValue: Double
    var unit: String

    init() {
        title = ""
        detail = ""
        period = .custom
        durationDays = 21
        trackingSource = .manualBoolean
        sourceMetric = nil
        kind = .habit
        aggregation = .rate
        comparison = .atLeast
        targetValue = 0.8
        unit = ""
    }

    init(template: GoalTemplate) {
        title = template.title
        detail = template.detail
        period = template.period
        durationDays = template.defaultDays ?? 30
        sourceMetric = template.sourceMetric
        kind = template.kind
        aggregation = template.aggregation
        comparison = template.comparison
        targetValue = template.target ?? 0
        unit = template.unit ?? ""

        switch template.sourceType {
        case .manualBoolean: trackingSource = .manualBoolean
        case .manualNumber: trackingSource = .manualNumber
        case .manualRating: trackingSource = .manualRating
        case .automatic, .combined:
            switch template.sourceMetric {
            case .protein: trackingSource = .foodLogs
            case .water: trackingSource = .waterLogs
            case .workouts, .workoutMinutes: trackingSource = .workoutLogs
            case .weight: trackingSource = .bodyLogs
            default: trackingSource = .appleHealth
            }
        }
    }

    mutating func select(_ source: GoalTrackingSource) {
        trackingSource = source
        sourceMetric = source.metrics.first
        applyDefaults()
    }

    mutating func select(_ metric: GoalSourceMetric) {
        sourceMetric = metric
        applyDefaults()
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && targetValue > 0
            && (period != .custom || durationDays > 0)
    }

    var targetPrompt: String {
        switch trackingSource {
        case .manualBoolean: "Percent of check-ins"
        case .manualRating: "Average rating"
        default: "Target"
        }
    }

    var displayTargetValue: Double {
        get { trackingSource == .manualBoolean ? targetValue * 100 : targetValue }
        set { targetValue = trackingSource == .manualBoolean ? newValue / 100 : newValue }
    }

    private mutating func applyDefaults() {
        switch trackingSource {
        case .manualBoolean:
            kind = .habit; aggregation = .rate; comparison = .atLeast
            targetValue = 0.8; unit = ""; period = .custom; durationDays = 21
        case .manualNumber:
            kind = .average; aggregation = .average; comparison = .atLeast
            targetValue = 1; unit = "value"; period = .ongoing
        case .manualRating:
            kind = .subjective; aggregation = .average; comparison = .atLeast
            targetValue = 4; unit = "out of 5"; period = .ongoing
        default:
            applyMetricDefaults(sourceMetric)
        }
    }

    private mutating func applyMetricDefaults(_ metric: GoalSourceMetric?) {
        switch metric {
        case .steps:
            kind = .average; aggregation = .average; comparison = .atLeast
            targetValue = 8_000; unit = "steps"; period = .monthly
        case .sleepDuration:
            kind = .average; aggregation = .average; comparison = .atLeast
            targetValue = 8; unit = "hours"; period = .custom; durationDays = 42
        case .activeEnergy:
            kind = .average; aggregation = .average; comparison = .atLeast
            targetValue = 500; unit = "kcal"; period = .weekly
        case .restingHeartRate:
            kind = .average; aggregation = .average; comparison = .atMost
            targetValue = 70; unit = "bpm"; period = .ongoing
        case .hrv:
            kind = .average; aggregation = .average; comparison = .atLeast
            targetValue = 50; unit = "ms"; period = .ongoing
        case .protein:
            kind = .frequency; aggregation = .count; comparison = .atLeast
            targetValue = 5; unit = "days"; period = .weekly
        case .water:
            kind = .average; aggregation = .average; comparison = .atLeast
            targetValue = 2_000; unit = "ml"; period = .daily
        case .workouts:
            kind = .frequency; aggregation = .count; comparison = .atLeast
            targetValue = 3; unit = "workouts"; period = .weekly
        case .workoutMinutes:
            kind = .accumulation; aggregation = .sum; comparison = .atLeast
            targetValue = 150; unit = "minutes"; period = .weekly
        case .weight:
            kind = .target; aggregation = .latest; comparison = .reach
            targetValue = 75; unit = "kg"; period = .custom; durationDays = 90
        case nil:
            break
        }
    }
}

extension GoalMeasurement {
    var sourceDisplayName: String {
        if let sourceMetric { return sourceMetric.sourceDisplayName }
        return switch sourceType {
        case .manualBoolean: "Manual yes / no check-in"
        case .manualNumber: "Manual number check-in"
        case .manualRating: "Manual 1–5 check-in"
        case .automatic: "Connected data"
        case .combined: "Connected + manual data"
        }
    }

    var sourceSymbol: String {
        switch sourceMetric {
        case .protein: "fork.knife"
        case .water: "drop.fill"
        case .workouts, .workoutMinutes: "figure.run"
        case .weight: "scalemass.fill"
        case .steps: "shoeprints.fill"
        case .sleepDuration: "bed.double.fill"
        case .activeEnergy: "flame.fill"
        case .restingHeartRate, .hrv: "heart.fill"
        case nil: "hand.tap.fill"
        }
    }

    // Weight goals and check-ins are always stored in kg, regardless of the user's unit
    // choice — these two convert at the display edge so a goal card, review sheet, or day
    // detail never leaks the raw stored kilograms to an imperial user.
    func displayValue(_ storageValue: Double, units: UnitSystem) -> Double {
        sourceMetric == .weight ? units.weightInput(from: storageValue) : storageValue
    }

    // The stored `unit` string is always "kg" for a weight goal (it describes storage, not
    // display), so it's ignored here in favor of whatever the user's current unit choice is.
    func displayUnit(_ units: UnitSystem) -> String {
        sourceMetric == .weight ? units.weightUnit : (unit ?? "")
    }
}
