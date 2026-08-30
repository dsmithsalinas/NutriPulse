import Foundation

/// Metrics that can pass through the shared data-quality gate. Values are normalized to
/// the units Footing already uses before they reach this layer.
enum HealthQualityMetric: String, Codable, CaseIterable, Sendable {
    case steps
    case sleepDuration = "sleep_duration"
    case activeEnergy = "active_energy"
    case restingHeartRate = "resting_heart_rate"
    case hrv
    case weight
    case water
    case workoutCount = "workout_count"
    case workoutMinutes = "workout_minutes"
    case protein
}

enum HealthDataQualityStatus: String, Codable, Sendable {
    case usable
    case usableWithCaution = "usable_with_caution"
    case insufficientData = "insufficient_data"
    case conflictingSources = "conflicting_sources"
    case implausible
}

enum HealthDataQualityIssueCode: String, Codable, Sendable {
    case missingData = "missing_data"
    case lowCoverage = "low_coverage"
    case partialDay = "partial_day"
    case implausibleValue = "implausible_value"
    case abruptChange = "abrupt_change"
    case multipleSources = "multiple_sources"
    case conflictingSources = "conflicting_sources"
    case sourceChanged = "source_changed"
    case inconsistentWear = "inconsistent_wear"
}

struct HealthQualityObservation: Equatable, Sendable {
    let metric: HealthQualityMetric
    let value: Double
    let observedAt: Date
    /// Kept on-device. Callers should use a stable app/bundle identifier, not a serial number.
    let sourceIdentifier: String?
    let deviceClass: String?

    init(
        metric: HealthQualityMetric,
        value: Double,
        observedAt: Date,
        sourceIdentifier: String? = nil,
        deviceClass: String? = nil
    ) {
        self.metric = metric
        self.value = value
        self.observedAt = observedAt
        self.sourceIdentifier = sourceIdentifier
        self.deviceClass = deviceClass
    }
}

struct HealthDataQualityIssue: Equatable, Sendable {
    let code: HealthDataQualityIssueCode
    let detail: String
}

struct MetricQualityAssessment: Equatable, Sendable {
    static let algorithmVersion = 1

    let metric: HealthQualityMetric
    let status: HealthDataQualityStatus
    let observedCount: Int
    let expectedCount: Int
    let coverage: Double
    let sourceCount: Int
    let outlierCount: Int
    let issues: [HealthDataQualityIssue]
    /// Only observations safe for derived calculations. Raw source data is never mutated.
    let usableObservations: [HealthQualityObservation]

    var issueCodes: [String] { issues.map(\.code.rawValue) }
}

struct HealthDataQualityRule: Sendable {
    let plausibleRange: ClosedRange<Double>
    let maximumDayToDayChange: Double?
    let sourceDisagreementTolerance: Double?
    let minimumCoverage: Double
    let usesWearConsistencyProxy: Bool

    static func rule(for metric: HealthQualityMetric, minimumCoverage: Double? = nil) -> Self {
        let base: Self
        switch metric {
        case .steps:
            base = .init(plausibleRange: 0...100_000, maximumDayToDayChange: nil,
                         sourceDisagreementTolerance: 5_000, minimumCoverage: 0.5,
                         usesWearConsistencyProxy: true)
        case .sleepDuration:
            base = .init(plausibleRange: 0.5...16, maximumDayToDayChange: 8,
                         sourceDisagreementTolerance: 1.5, minimumCoverage: 0.5,
                         usesWearConsistencyProxy: true)
        case .activeEnergy:
            base = .init(plausibleRange: 0...10_000, maximumDayToDayChange: 5_000,
                         sourceDisagreementTolerance: 1_000, minimumCoverage: 0.5,
                         usesWearConsistencyProxy: true)
        case .restingHeartRate:
            base = .init(plausibleRange: 25...240, maximumDayToDayChange: 50,
                         sourceDisagreementTolerance: 20, minimumCoverage: 0.5,
                         usesWearConsistencyProxy: true)
        case .hrv:
            base = .init(plausibleRange: 1...500, maximumDayToDayChange: 250,
                         sourceDisagreementTolerance: 100, minimumCoverage: 0.5,
                         usesWearConsistencyProxy: true)
        case .weight:
            base = .init(plausibleRange: 20...400, maximumDayToDayChange: 10,
                         sourceDisagreementTolerance: 2, minimumCoverage: 0.3,
                         usesWearConsistencyProxy: false)
        case .water:
            base = .init(plausibleRange: 0...20_000, maximumDayToDayChange: 12_000,
                         sourceDisagreementTolerance: nil, minimumCoverage: 0.5,
                         usesWearConsistencyProxy: false)
        case .workoutCount:
            base = .init(plausibleRange: 0...20, maximumDayToDayChange: nil,
                         sourceDisagreementTolerance: nil, minimumCoverage: 0.3,
                         usesWearConsistencyProxy: false)
        case .workoutMinutes:
            base = .init(plausibleRange: 0...1_440, maximumDayToDayChange: nil,
                         sourceDisagreementTolerance: 120, minimumCoverage: 0.3,
                         usesWearConsistencyProxy: false)
        case .protein:
            base = .init(plausibleRange: 0...1_000, maximumDayToDayChange: 500,
                         sourceDisagreementTolerance: nil, minimumCoverage: 0.5,
                         usesWearConsistencyProxy: false)
        }
        guard let minimumCoverage else { return base }
        return .init(
            plausibleRange: base.plausibleRange,
            maximumDayToDayChange: base.maximumDayToDayChange,
            sourceDisagreementTolerance: base.sourceDisagreementTolerance,
            minimumCoverage: min(max(minimumCoverage, 0), 1),
            usesWearConsistencyProxy: base.usesWearConsistencyProxy
        )
    }
}

enum HealthDataQualityEngine {
    static func assess(
        metric: HealthQualityMetric,
        observations: [HealthQualityObservation],
        expectedDates: [Date],
        rule: HealthDataQualityRule? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MetricQualityAssessment {
        let rule = rule ?? .rule(for: metric)
        let today = calendar.startOfDay(for: now)
        let expectedDays = Set(expectedDates.map { calendar.startOfDay(for: $0) })
            .filter { $0 <= today }
        let metricObservations = observations
            .filter { $0.metric == metric && $0.observedAt <= now }
            .sorted { $0.observedAt < $1.observedAt }
        let invalid = metricObservations.filter { !rule.plausibleRange.contains($0.value) }
        var usable = metricObservations.filter { rule.plausibleRange.contains($0.value) }
        var issues: [HealthDataQualityIssue] = []

        if !invalid.isEmpty {
            issues.append(.init(
                code: .implausibleValue,
                detail: "\(invalid.count) reading\(invalid.count == 1 ? "" : "s") fell outside Footing’s conservative validation range and \(invalid.count == 1 ? "was" : "were") excluded."
            ))
        }

        let sources = Set(usable.compactMap(\.sourceIdentifier))
        if sources.count > 1 {
            issues.append(.init(
                code: .multipleSources,
                detail: "This metric was recorded by more than one source."
            ))
        }

        var conflictingDays = Set<Date>()
        if let tolerance = rule.sourceDisagreementTolerance {
            let byDay = Dictionary(grouping: usable) { calendar.startOfDay(for: $0.observedAt) }
            for (day, rows) in byDay where Set(rows.compactMap(\.sourceIdentifier)).count > 1 {
                let values = rows.map(\.value)
                if let low = values.min(), let high = values.max(), high - low > tolerance {
                    conflictingDays.insert(day)
                }
            }
            if !conflictingDays.isEmpty {
                issues.append(.init(
                    code: .conflictingSources,
                    detail: "Sources disagreed beyond the expected tolerance on \(conflictingDays.count) day\(conflictingDays.count == 1 ? "" : "s")."
                ))
                usable.removeAll { conflictingDays.contains(calendar.startOfDay(for: $0.observedAt)) }
            }
        }

        let observationsByDay = Dictionary(grouping: usable) {
            calendar.startOfDay(for: $0.observedAt)
        }
        let dominantSources = observationsByDay.keys.sorted().compactMap { day in
            dominantSource(in: observationsByDay[day] ?? [])
        }
        if zip(dominantSources, dominantSources.dropFirst()).contains(where: { pair in
            pair.0 != pair.1
        }) {
            issues.append(.init(
                code: .sourceChanged,
                detail: "The primary measurement source changed during this period, so comparisons may be less reliable."
            ))
        }

        if let maximumChange = rule.maximumDayToDayChange {
            let daily = Dictionary(grouping: usable) { calendar.startOfDay(for: $0.observedAt) }
                .compactMapValues { rows in rows.map(\.value).reduce(0, +) / Double(rows.count) }
                .sorted { $0.key < $1.key }
            if zip(daily, daily.dropFirst()).contains(where: { pair in
                abs(pair.0.value - pair.1.value) > maximumChange
            }) {
                issues.append(.init(
                    code: .abruptChange,
                    detail: "At least one change was much larger than this metric usually supports for trend interpretation."
                ))
            }
        }

        let observedDays = Set(usable.map { calendar.startOfDay(for: $0.observedAt) })
            .intersection(expectedDays)
        let expectedCount = expectedDays.count
        let observedCount = observedDays.count
        let coverage = expectedCount > 0 ? Double(observedCount) / Double(expectedCount) : 0

        if observedCount == 0 {
            issues.append(.init(code: .missingData, detail: "No usable readings were available for this period."))
        } else if coverage < rule.minimumCoverage {
            issues.append(.init(
                code: .lowCoverage,
                detail: "Only \(Int((coverage * 100).rounded()))% of expected days had usable data."
            ))
        }
        let partialDayMetrics: Set<HealthQualityMetric> = [
            .steps, .activeEnergy, .restingHeartRate, .hrv, .water,
            .workoutCount, .workoutMinutes, .protein,
        ]
        if partialDayMetrics.contains(metric), expectedDays.contains(today),
           now < calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now)! {
            issues.append(.init(
                code: .partialDay,
                detail: "Today is still in progress, so its total may increase."
            ))
        }
        if rule.usesWearConsistencyProxy, expectedCount >= 3, coverage < 0.5 {
            issues.append(.init(
                code: .inconsistentWear,
                detail: "There is not enough sampling coverage to confirm consistent device wear."
            ))
        }

        let status: HealthDataQualityStatus
        if usable.isEmpty, !invalid.isEmpty {
            status = .implausible
        } else if !conflictingDays.isEmpty {
            status = .conflictingSources
        } else if observedCount == 0 || coverage < rule.minimumCoverage {
            status = .insufficientData
        } else if !issues.isEmpty {
            status = .usableWithCaution
        } else {
            status = .usable
        }

        return .init(
            metric: metric,
            status: status,
            observedCount: observedCount,
            expectedCount: expectedCount,
            coverage: coverage,
            sourceCount: sources.count,
            outlierCount: invalid.count,
            issues: issues,
            usableObservations: usable
        )
    }

    private static func dominantSource(in rows: [HealthQualityObservation]) -> String? {
        var counts: [String: Int] = [:]
        for row in rows {
            guard let source = row.sourceIdentifier else { continue }
            counts[source, default: 0] += 1
        }
        guard !counts.isEmpty else { return nil }
        let maximum = counts.values.max() ?? 0
        let leaders = counts.filter { $0.value == maximum }.map(\.key).sorted()
        // A tied source mix is not evidence that the primary source changed.
        return leaders.count == 1 ? leaders[0] : nil
    }
}

extension GoalSourceMetric {
    var healthQualityMetric: HealthQualityMetric {
        switch self {
        case .steps: .steps
        case .workouts: .workoutCount
        case .workoutMinutes: .workoutMinutes
        case .sleepDuration: .sleepDuration
        case .weight: .weight
        case .protein: .protein
        case .water: .water
        case .activeEnergy: .activeEnergy
        case .restingHeartRate: .restingHeartRate
        case .hrv: .hrv
        }
    }
}
