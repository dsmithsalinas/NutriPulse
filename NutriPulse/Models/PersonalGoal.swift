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

enum GoalAggregation: String, Codable, Equatable {
    case latest, sum, count, average, rate
}

enum GoalComparison: String, Codable {
    case equal
    case atLeast = "at_least"
    case atMost = "at_most"
    case reach, increase, decrease, none
}

enum GoalSourceType: String, Codable, Equatable {
    case manualBoolean = "manual_boolean"
    case manualNumber = "manual_number"
    case manualRating = "manual_rating"
    case automatic, combined
}

enum GoalSourceMetric: String, Codable, CaseIterable, Equatable {
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
    /// Filled in by `ExperimentRepository` after the base fetch, from `experiment_measurements`
    /// joined to `experiment_metrics`. Not a `personal_experiments` column, so it's left out of
    /// `CodingKeys`: decoding a plain row never touches it, and a failed follow-up read simply
    /// leaves it nil instead of failing the whole experiment fetch.
    var outcomeMeasurements: [ExperimentOutcomeMeasurement]? = nil

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

    /// The measurement Footing shows as "Measuring: <name>" — the primary outcome when one is
    /// tagged, otherwise whatever outcome measurement is available.
    var primaryOutcomeMeasurement: ExperimentOutcomeMeasurement? {
        outcomeMeasurements?.first(where: { $0.role == "primary_outcome" }) ?? outcomeMeasurements?.first
    }
}

/// A lightweight, embeddable summary of an `experiment_metrics` row — just enough to label an
/// outcome ("Sleep duration", "hours") without a second round trip for the common case.
struct ExperimentMetricSummary: Codable, Equatable {
    let name: String
    let unit: String?
    /// Where the outcome comes from: typed in at the check-in (a rating), or read live from its
    /// source (HealthKit, food logs). Optional so a summary decoded without them still labels.
    var sourceType: GoalSourceType? = nil
    var sourceMetric: GoalSourceMetric? = nil

    enum CodingKeys: String, CodingKey {
        case name, unit
        case sourceType = "source_type"
        case sourceMetric = "source_metric"
    }

    /// Read live from its source rather than from what was typed in.
    var isAutomatic: Bool {
        (sourceType == .automatic || sourceType == .combined) && sourceMetric != nil
    }
}

/// One row of `experiment_measurements`, with its `experiment_metrics` joined in.
struct ExperimentOutcomeMeasurement: Codable, Equatable, Identifiable {
    let measurementId: UUID
    let role: String
    let metric: ExperimentMetricSummary?
    var id: UUID { measurementId }

    enum CodingKeys: String, CodingKey {
        case measurementId = "measurement_id"
        case role
        case metric = "experiment_metrics"
    }
}

/// One `experiment_observations` row, reduced to a date and a single comparable number: the
/// observed value for numeric/rating outcomes, or 1/0 for a boolean outcome. Built by
/// `ExperimentRepository` from the raw row; not decoded directly (the raw row splits the value
/// across `value_number`/`value_boolean`).
struct ExperimentObservationValue: Equatable {
    let localDate: String
    let number: Double?

    /// One value per day from rows ordered oldest first: the last one for a day wins.
    static func latestPerDay(_ ordered: [ExperimentObservationValue]) -> [ExperimentObservationValue] {
        var byDate: [String: ExperimentObservationValue] = [:]
        for value in ordered where value.number != nil { byDate[value.localDate] = value }
        return byDate.values.sorted { $0.localDate < $1.localDate }
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

struct ExperimentOutcomeTemplate: Identifiable, Equatable {
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
    static let protein = ExperimentOutcomeTemplate(
        id: "protein", name: "Protein intake", aggregation: .average,
        unit: "g", sourceType: .automatic, sourceMetric: .protein
    )

    static let all: [ExperimentOutcomeTemplate] = [.sleep, .energy, .steps, .protein]
}
