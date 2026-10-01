import Foundation

struct GoalMetricEvaluation {
    let values: [GoalDailyValue]
    let quality: MetricQualityAssessment?
}

@MainActor
struct GoalMetricService {
    private let analytics = AnalyticsRepository()

    func values(for bundle: PersonalGoalBundle, today: Date = .now) async -> [GoalDailyValue] {
        await evaluation(for: bundle, today: today).values
    }

    func evaluation(for bundle: PersonalGoalBundle, today: Date = .now) async -> GoalMetricEvaluation {
        guard let measurement = bundle.primaryMeasurement else {
            return .init(values: [], quality: nil)
        }
        if measurement.sourceType == .manualBoolean || measurement.sourceType == .manualNumber
            || measurement.sourceType == .manualRating {
            return .init(
                values: manualValues(bundle: bundle, measurement: measurement),
                quality: nil
            )
        }

        guard let source = measurement.sourceMetric else { return .init(values: [], quality: nil) }
        let dates = datesForLoading(version: bundle.version, today: today)
        guard !dates.isEmpty else { return .init(values: [], quality: nil) }

        guard let raw = await dailyValues(source: source, dates: dates) else {
            return qualityEvaluation(values: [], dates: dates, source: source, measurement: measurement, today: today)
        }
        let values: [GoalDailyValue]
        if source == .protein {
            // A protein goal is met or missed against today's target; the grams stay for display.
            let goal = try? await GoalRepository().fetchGoal(for: today)
            guard let proteinTarget = goal?.proteinG else {
                return qualityEvaluation(values: [], dates: dates, source: source, measurement: measurement, today: today)
            }
            values = raw.compactMap { value in
                guard let grams = value.number else { return nil }
                return GoalDailyValue(
                    date: value.date,
                    boolean: grams >= proteinTarget,
                    displayValue: grams,
                    displayTarget: proteinTarget
                )
            }
        } else {
            values = raw
        }
        let sourceAwareObservations: [HealthQualityObservation]
        if dates.count <= 60,
           source == .sleepDuration || source == .restingHeartRate || source == .hrv {
            sourceAwareObservations = await HealthKitManager.shared.fetchQualityObservations(
                metric: source.healthQualityMetric, dates: dates
            )
        } else {
            sourceAwareObservations = []
        }
        return qualityEvaluation(
            values: values,
            dates: dates,
            source: source,
            measurement: measurement,
            today: today,
            sourceAwareObservations: sourceAwareObservations
        )
    }

    /// One number per day from the metric's own store: HealthKit, or Footing's logs (protein in
    /// grams, water in ml, weight in kg). Nil when the Footing fetch failed; HealthKit days with
    /// nothing readable are simply absent. Shared by goals and experiment outcomes.
    func dailyValues(source: GoalSourceMetric, dates: [Date]) async -> [GoalDailyValue]? {
        guard let firstDate = dates.first, let lastDate = dates.last else { return [] }
        switch source {
        case .steps:
            return await healthKitValues(dates) { await $0.fetchSteps(for: $1) }
        case .sleepDuration:
            return await healthKitValues(dates) { await $0.fetchSleepHours(for: $1) }
        case .activeEnergy:
            return await healthKitValues(dates) { await $0.fetchActiveCalories(for: $1) }
        case .restingHeartRate:
            return await healthKitValues(dates) { await $0.fetchRestingHeartRate(for: $1) }
        case .hrv:
            return await healthKitValues(dates) { await $0.fetchHRV(for: $1) }
        case .workouts, .workoutMinutes:
            guard let movement = try? await analytics.fetchDailyMovement(from: firstDate, through: lastDate) else { return nil }
            return movement.map {
                GoalDailyValue(date: $0.date, number: source == .workouts ? Double($0.sessions) : $0.minutes)
            }
        case .protein:
            guard let summaries = try? await analytics.fetchDailySummaries(from: firstDate, through: lastDate) else { return nil }
            return summaries.compactMap { summary in
                summary.hasData ? GoalDailyValue(date: summary.date, number: summary.proteinG) : nil
            }
        case .water:
            guard let hydration = try? await analytics.fetchDailyHydration(from: firstDate, through: lastDate) else { return nil }
            return hydration.map { GoalDailyValue(date: $0.date, number: $0.amountMl) }
        case .weight:
            guard let weights = try? await analytics.fetchWeightLogs(from: firstDate, through: lastDate) else { return nil }
            return weights.map { GoalDailyValue(date: $0.loggedAt, number: $0.weightKg) }
        }
    }

    private func qualityEvaluation(
        values: [GoalDailyValue],
        dates: [Date],
        source: GoalSourceMetric,
        measurement: GoalMeasurement,
        today: Date,
        sourceAwareObservations: [HealthQualityObservation] = []
    ) -> GoalMetricEvaluation {
        let metric = source.healthQualityMetric
        let observations = values.compactMap { value -> HealthQualityObservation? in
            // Frequency goals such as protein retain their Boolean result for progress, while
            // quality evaluates the underlying measured quantity when it is available.
            guard let number = value.number ?? value.displayValue else { return nil }
            return .init(metric: metric, value: number, observedAt: value.date)
        }
        let quality = HealthDataQualityEngine.assess(
            metric: metric,
            observations: sourceAwareObservations.isEmpty ? observations : sourceAwareObservations,
            expectedDates: dates,
            rule: .rule(for: metric, minimumCoverage: measurement.minimumCoverage),
            now: today
        )
        let usableDays = Set(quality.usableObservations.map { Calendar.current.startOfDay(for: $0.observedAt) })
        let filteredValues = values.filter { value in
            usableDays.contains(Calendar.current.startOfDay(for: value.date))
        }
        return .init(values: filteredValues, quality: quality)
    }

    private func manualValues(
        bundle: PersonalGoalBundle, measurement: GoalMeasurement
    ) -> [GoalDailyValue] {
        let checkinDates = Dictionary(uniqueKeysWithValues: bundle.checkins.map { ($0.id, $0.localDate) })
        return bundle.observations.compactMap { observation in
            guard observation.measurementId == measurement.id,
                  let dateString = checkinDates[observation.checkinId],
                  let date = Self.parse(dateString)
            else { return nil }
            if let value = observation.valueBoolean {
                return GoalDailyValue(date: date, boolean: value)
            }
            if let value = observation.valueNumber {
                return GoalDailyValue(date: date, number: value)
            }
            return nil
        }
    }

    private func healthKitValues(
        _ dates: [Date],
        fetch: (HealthKitManager, Date) async -> Double?
    ) async -> [GoalDailyValue] {
        let manager = HealthKitManager.shared
        var result: [GoalDailyValue] = []
        for date in dates {
            if let value = await fetch(manager, date) {
                result.append(GoalDailyValue(date: date, number: value))
            }
        }
        return result
    }

    private func datesForLoading(version: GoalVersion, today: Date) -> [Date] {
        let calendar = Calendar.current
        guard let start = Self.parse(version.startDate) else { return [] }
        let end = min(version.endDate.flatMap(Self.parse) ?? today, today)
        guard start <= end else { return [] }
        // A year is the longest first-release period. This protects HealthKit from an
        // accidental unbounded ongoing-goal query while preserving annual-goal semantics.
        let boundedStart = max(start, calendar.date(byAdding: .day, value: -365, to: end)!)
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: boundedStart)
        while cursor <= calendar.startOfDay(for: end) {
            result.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return result
    }

    private static func parse(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
        )
    }
}

// MARK: - Experiment outcomes

extension GoalMetricService {
    /// An experiment's primary outcome by day ("yyyy-MM-dd"). Typed-in outcomes (a rating) come
    /// from what the user recorded at the check-in; automatic ones (sleep, steps, protein) are
    /// read live from their source, the same as goals, over the experiment's window. Nil when
    /// it couldn't be loaded, so the result reads "not enough data" rather than a wrong number.
    func experimentOutcomes(
        for experiment: PersonalExperiment,
        outcome: ExperimentOutcomeMeasurement,
        repository: ExperimentRepository = ExperimentRepository(),
        today: Date = .now
    ) async -> [String: Double]? {
        if let metric = outcome.metric, metric.isAutomatic, let source = metric.sourceMetric {
            let dates = ExperimentOutcomeWindow.dates(
                start: experiment.baselineStart ?? experiment.interventionStart,
                end: experiment.endDate,
                source: source,
                today: today
            )
            guard let values = await dailyValues(source: source, dates: dates) else { return nil }
            return ExperimentOutcomeWindow.byDate(values)
        }
        guard let observations = try? await repository.fetchOutcomeObservations(measurementId: outcome.measurementId) else {
            return nil
        }
        return Dictionary(
            observations.compactMap { observation in observation.number.map { (observation.localDate, $0) } },
            uniquingKeysWith: { _, latest in latest }
        )
    }
}
