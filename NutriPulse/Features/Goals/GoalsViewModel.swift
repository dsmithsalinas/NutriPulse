import Foundation

struct GoalCardState: Identifiable {
    let bundle: PersonalGoalBundle
    let values: [GoalDailyValue]
    let progress: GoalProgressSummary
    let quality: MetricQualityAssessment?

    var id: UUID { bundle.id }
    var measurement: GoalMeasurement? { bundle.primaryMeasurement }
}

@Observable
@MainActor
final class GoalsViewModel {
    private(set) var active: [GoalCardState] = []
    private(set) var completed: [GoalCardState] = []
    private(set) var isLoading = false
    var error: String?

    private let repository = PersonalGoalRepository()
    private let metrics = GoalMetricService()

    func load() async {
        guard !isLoading else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--goals-preview")
            || ProcessInfo.processInfo.arguments.contains("--progress-preview") {
            let previews = Self.previewStates()
            active = ProcessInfo.processInfo.arguments.contains("--progress-preview")
                ? Array(previews.prefix(1))
                : previews
            completed = []
            error = nil
            return
        }
        #endif
        isLoading = true
        defer { isLoading = false }
        do {
            var activeBundles = try await repository.fetchActiveGoals()
            let expired = activeBundles.filter { GoalLifecycle.hasEnded($0.version) }
            if !expired.isEmpty {
                for bundle in expired {
                    try await repository.complete(bundle.id)
                }
                activeBundles = try await repository.fetchActiveGoals()
            }

            let completedBundles = try await repository.fetchCompletedGoals()
            active = await states(for: activeBundles, completed: false)
            completed = await states(for: completedBundles, completed: true)
            error = nil
        } catch {
            self.error = "Goals couldn’t refresh. Your existing health data is unchanged."
        }
    }

    func state(for id: UUID) -> GoalCardState? {
        active.first { $0.id == id } ?? completed.first { $0.id == id }
    }

    private func states(
        for bundles: [PersonalGoalBundle],
        completed: Bool
    ) async -> [GoalCardState] {
        var states: [GoalCardState] = []
        for bundle in bundles {
            guard let measurement = bundle.primaryMeasurement else { continue }
            let evaluationDate = completed ? GoalLifecycle.evaluationDate(for: bundle) : .now
            let evaluation = await metrics.evaluation(for: bundle, today: evaluationDate)
            states.append(.init(
                bundle: bundle,
                values: evaluation.values,
                progress: GoalProgressCalculator.calculate(
                    version: bundle.version,
                    measurement: measurement,
                    values: evaluation.values,
                    today: evaluationDate
                ),
                quality: evaluation.quality
            ))
        }
        return states
    }

    #if DEBUG
    private static func previewStates() -> [GoalCardState] {
        let userId = UUID()
        let calendar = Calendar.current
        func date(_ day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 8, day: day))!
        }
        func bundle(
            title: String,
            period: GoalPeriod,
            start: String,
            end: String?,
            measurement: GoalMeasurement,
            values: [GoalDailyValue]
        ) -> GoalCardState {
            let goal = PersonalGoal(
                id: UUID(), userId: userId, status: .active,
                currentVersionId: measurement.goalVersionId,
                createdAt: date(1), completedAt: nil
            )
            let version = GoalVersion(
                id: measurement.goalVersionId, goalId: goal.id, userId: userId,
                versionNumber: 1, title: title, detail: nil, period: period,
                startDate: start, endDate: end, timezoneId: TimeZone.current.identifier,
                scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7],
                effectiveFrom: start, effectiveTo: nil, createdAt: date(1)
            )
            let goalBundle = PersonalGoalBundle(
                goal: goal, version: version, measurements: [measurement],
                checkins: [], observations: []
            )
            let progress = GoalProgressCalculator.calculate(
                version: version, measurement: measurement, values: values,
                today: date(30), calendar: calendar
            )
            return .init(bundle: goalBundle, values: values, progress: progress, quality: nil)
        }

        let proteinVersion = UUID()
        let protein = GoalMeasurement(
            id: UUID(), goalVersionId: proteinVersion, userId: userId, role: "primary",
            name: "Meet my protein target", kind: .frequency, aggregation: .count,
            comparison: .atLeast, targetValue: 5, unit: "days",
            sourceType: .automatic, sourceMetric: .protein,
            minimumCoverage: 0.5, createdAt: date(30)
        )
        let proteinValues = [
            GoalDailyValue(date: date(30), boolean: false, displayValue: 82, displayTarget: 140),
        ]

        let sleepVersion = UUID()
        let sleep = GoalMeasurement(
            id: UUID(), goalVersionId: sleepVersion, userId: userId, role: "primary",
            name: "6.5 hours of sleep", kind: .threshold, aggregation: .average,
            comparison: .atLeast, targetValue: 6, unit: "hours",
            sourceType: .automatic, sourceMetric: .sleepDuration,
            minimumCoverage: 0.5, createdAt: date(1)
        )
        let sleepValues = [GoalDailyValue(date: date(30), number: 6.5)]

        return [
            bundle(
                title: "Meet my protein target", period: .weekly,
                start: "2026-08-30", end: nil,
                measurement: protein, values: proteinValues
            ),
            bundle(
                title: "6.5 hours of sleep", period: .monthly,
                start: "2026-08-01", end: "2026-08-31",
                measurement: sleep, values: sleepValues
            ),
        ]
    }
    #endif

    func create(_ template: GoalTemplate) async -> Bool {
        await create(GoalDraft(template: template))
    }

    func create(_ draft: GoalDraft) async -> Bool {
        do {
            try await repository.createGoal(from: draft)
            await load()
            return true
        } catch {
            self.error = "That goal couldn’t be created. Please try again."
            return false
        }
    }

    func record(_ value: Bool, for state: GoalCardState) async {
        do {
            try await repository.recordBoolean(value, for: state.bundle)
            await load()
        } catch {
            self.error = "Your check-in couldn’t be saved yet."
        }
    }

    func record(_ value: Double, for state: GoalCardState) async {
        do {
            try await repository.recordNumber(value, for: state.bundle)
            await load()
        } catch {
            self.error = "Your check-in couldn’t be saved yet."
        }
    }
}
