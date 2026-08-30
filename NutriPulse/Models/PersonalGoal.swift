import Foundation

enum GoalStatus: String, Codable {
    case draft, active, paused, completed, archived
}

enum GoalPeriod: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, annual, custom, ongoing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .annual: "Annually"
        case .custom: "Custom range"
        case .ongoing: "Ongoing"
        }
    }
}

enum GoalMeasurementKind: String, Codable, CaseIterable {
    case habit, accumulation, frequency, average, target, threshold, subjective
}

enum GoalAggregation: String, Codable {
    case latest, sum, count, average, rate
}

enum GoalComparison: String, Codable {
    case equal
    case atLeast = "at_least"
    case atMost = "at_most"
    case reach, increase, decrease, none
}

enum GoalSourceType: String, Codable {
    case manualBoolean = "manual_boolean"
    case manualNumber = "manual_number"
    case manualRating = "manual_rating"
    case automatic, combined
}

enum GoalSourceMetric: String, Codable, CaseIterable {
    case steps, workouts
    case workoutMinutes = "workout_minutes"
    case sleepDuration = "sleep_duration"
    case weight, protein, water
    case activeEnergy = "active_energy"
    case restingHeartRate = "resting_heart_rate"
    case hrv
}

struct PersonalGoal: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let status: GoalStatus
    let currentVersionId: UUID?
    let createdAt: Date
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case userId = "user_id"
        case currentVersionId = "current_version_id"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

struct GoalVersion: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let userId: UUID
    let versionNumber: Int
    let title: String
    let detail: String?
    let period: GoalPeriod
    let startDate: String
    let endDate: String?
    let timezoneId: String
    let scheduledWeekdays: [Int]
    let effectiveFrom: String
    let effectiveTo: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, detail, period
        case goalId = "goal_id"
        case userId = "user_id"
        case versionNumber = "version_number"
        case startDate = "start_date"
        case endDate = "end_date"
        case timezoneId = "timezone_id"
        case scheduledWeekdays = "scheduled_weekdays"
        case effectiveFrom = "effective_from"
        case effectiveTo = "effective_to"
        case createdAt = "created_at"
    }
}

struct GoalMeasurement: Codable, Identifiable {
    let id: UUID
    let goalVersionId: UUID
    let userId: UUID
    let role: String
    let name: String
    let kind: GoalMeasurementKind
    let aggregation: GoalAggregation
    let comparison: GoalComparison
    let targetValue: Double?
    let unit: String?
    let sourceType: GoalSourceType
    let sourceMetric: GoalSourceMetric?
    let minimumCoverage: Double
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role, name, kind, aggregation, comparison, unit
        case goalVersionId = "goal_version_id"
        case userId = "user_id"
        case targetValue = "target_value"
        case sourceType = "source_type"
        case sourceMetric = "source_metric"
        case minimumCoverage = "minimum_coverage"
        case createdAt = "created_at"
    }
}

struct GoalCheckin: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let userId: UUID
    let observedAt: Date
    let localDate: String
    let note: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, note
        case goalId = "goal_id"
        case userId = "user_id"
        case observedAt = "observed_at"
        case localDate = "local_date"
        case createdAt = "created_at"
    }
}

struct GoalObservation: Codable, Identifiable {
    let id: UUID
    let checkinId: UUID
    let measurementId: UUID
    let userId: UUID
    let valueBoolean: Bool?
    let valueNumber: Double?
    let valueText: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case checkinId = "checkin_id"
        case measurementId = "measurement_id"
        case userId = "user_id"
        case valueBoolean = "value_boolean"
        case valueNumber = "value_number"
        case valueText = "value_text"
        case createdAt = "created_at"
    }
}

struct PersonalGoalBundle: Identifiable {
    let goal: PersonalGoal
    let version: GoalVersion
    let measurements: [GoalMeasurement]
    let checkins: [GoalCheckin]
    let observations: [GoalObservation]

    var id: UUID { goal.id }
    var primaryMeasurement: GoalMeasurement? {
        measurements.first { $0.role == "primary" } ?? measurements.first
    }
}

struct GoalTemplate: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let period: GoalPeriod
    let defaultDays: Int?
    let kind: GoalMeasurementKind
    let aggregation: GoalAggregation
    let comparison: GoalComparison
    let target: Double?
    let unit: String?
    let sourceType: GoalSourceType
    let sourceMetric: GoalSourceMetric?

    static let caffeine = GoalTemplate(
        id: "caffeine-cutoff", title: "No caffeine after noon",
        detail: "Check in once a day after noon.", symbol: "cup.and.saucer",
        period: .custom, defaultDays: 21, kind: .habit, aggregation: .rate,
        comparison: .atLeast, target: 0.8, unit: nil,
        sourceType: .manualBoolean, sourceMetric: nil
    )

    static let steps = GoalTemplate(
        id: "steps", title: "Average 8,000 steps",
        detail: "Measured automatically with Apple Health.", symbol: "shoeprints.fill",
        period: .monthly, defaultDays: nil, kind: .average, aggregation: .average,
        comparison: .atLeast, target: 8_000, unit: "steps",
        sourceType: .automatic, sourceMetric: .steps
    )

    static let workouts = GoalTemplate(
        id: "workouts", title: "Exercise 3 times per week",
        detail: "Uses workouts from Footing and Apple Health.", symbol: "figure.run",
        period: .weekly, defaultDays: nil, kind: .frequency, aggregation: .count,
        comparison: .atLeast, target: 3, unit: "workouts",
        sourceType: .automatic, sourceMetric: .workouts
    )

    static let protein = GoalTemplate(
        id: "protein", title: "Meet my protein target",
        detail: "Count days your existing protein target is reached.", symbol: "fork.knife",
        period: .weekly, defaultDays: nil, kind: .frequency, aggregation: .count,
        comparison: .atLeast, target: 5, unit: "days",
        sourceType: .automatic, sourceMetric: .protein
    )

    static let energy = GoalTemplate(
        id: "energy", title: "Track morning energy",
        detail: "A quick 1–5 subjective check-in.", symbol: "sun.max",
        period: .ongoing, defaultDays: nil, kind: .subjective, aggregation: .average,
        comparison: .none, target: nil, unit: "out of 5",
        sourceType: .manualRating, sourceMetric: nil
    )

    static let all: [GoalTemplate] = [.caffeine, .steps, .workouts, .protein, .energy]
}

enum ExperimentStatus: String, Codable {
    case draft, baseline, running, completed, archived
}

struct PersonalExperiment: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let interventionGoalId: UUID
    let question: String
    let status: ExperimentStatus
    let baselineStart: String?
    let interventionStart: String
    let endDate: String?
    let createdAt: Date
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, question, status
        case userId = "user_id"
        case interventionGoalId = "intervention_goal_id"
        case baselineStart = "baseline_start"
        case interventionStart = "intervention_start"
        case endDate = "end_date"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

struct ExperimentMetric: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let aggregation: GoalAggregation
    let unit: String?
    let sourceType: GoalSourceType
    let sourceMetric: GoalSourceMetric?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, aggregation, unit
        case userId = "user_id"
        case sourceType = "source_type"
        case sourceMetric = "source_metric"
        case createdAt = "created_at"
    }
}

struct ExperimentOutcomeTemplate: Identifiable {
    let id: String
    let name: String
    let aggregation: GoalAggregation
    let unit: String
    let sourceType: GoalSourceType
    let sourceMetric: GoalSourceMetric?

    static let sleep = ExperimentOutcomeTemplate(
        id: "sleep", name: "Sleep duration", aggregation: .average,
        unit: "hours", sourceType: .automatic, sourceMetric: .sleepDuration
    )
    static let energy = ExperimentOutcomeTemplate(
        id: "energy", name: "Morning energy", aggregation: .average,
        unit: "out of 5", sourceType: .manualRating, sourceMetric: nil
    )
    static let steps = ExperimentOutcomeTemplate(
        id: "steps", name: "Daily steps", aggregation: .average,
        unit: "steps", sourceType: .automatic, sourceMetric: .steps
    )

    static let all: [ExperimentOutcomeTemplate] = [.sleep, .energy, .steps]
}
