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
    /// DEBUG-only: experiments for `--goals-preview`/`--tour`, since those launches never hit
    /// Supabase. Empty outside DEBUG or when Goals' own preview flags aren't set.
    private(set) var previewExperiments: [PersonalExperiment] = []

    /// The built-in protein floor card — computed fresh each load, never stored as a goal of
    /// its own. `nil` only while loading or if there's no effective protein target yet.
    private(set) var floorSummary: ProteinFloorGoal.Summary?
    /// Wins worth celebrating on this load, keyed by goal id (`ProteinFloorGoal.syntheticGoalID`
    /// for the floor card). Already-shown wins are filtered out via `winStore` before landing
    /// here, so a view seeing an id in this dictionary should play its celebration once.
    private(set) var wins: [UUID: GoalWinKind] = [:]

    private let repository = PersonalGoalRepository()
    private let metrics = GoalMetricService()
    private let analyticsRepository = AnalyticsRepository()
    private let dailyGoalRepository = GoalRepository()
    private let winStore = GoalWinStore()

    func load() async {
        guard !isLoading else { return }
        #if DEBUG
        if DebugLaunch.has("--goals-preview")
            || DebugLaunch.has("--progress-preview") {
            let previews = Self.previewStates()
            let isProgressPreview = DebugLaunch.has("--progress-preview")
            active = isProgressPreview ? Array(previews.prefix(1)) : previews
            completed = isProgressPreview ? [] : Self.previewCompletedStates()
            floorSummary = isProgressPreview ? nil : Self.previewFloorSummary()
            wins = isProgressPreview ? [:] : Self.previewWins(floorSummary: floorSummary)
            previewExperiments = isProgressPreview ? [] : Self.previewExperimentFixtures(for: previews)
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
        await loadFloorSummary()
        refreshWins()
    }

    func state(for id: UUID) -> GoalCardState? {
        active.first { $0.id == id } ?? completed.first { $0.id == id }
    }

    /// A calm heads-up before adding a goal past the suggested active count — never a block.
    var shouldWarnBeforeAddingGoal: Bool {
        GoalCreationPolicy.shouldWarnBeforeAdding(activeGoalCount: active.count)
    }

    // Fetched independently from the personal-goals tables (and tolerant of failure there,
    // since a goal-loading error shouldn't also blank out the one card everyone always has).
    private func loadFloorSummary() async {
        let today = Date.now
        do {
            async let summariesTask = analyticsRepository.fetchDailySummaries(days: ProteinFloorGoal.windowDays)
            async let goalTask = dailyGoalRepository.fetchGoal(for: today)
            let (summaries, goal) = try await (summariesTask, goalTask)
            floorSummary = ProteinFloorGoal.summary(from: summaries, floorTarget: goal?.proteinG, today: today)
        } catch {
            // Leave any previously loaded floor summary in place rather than blanking it.
        }
    }

    // Detects wins across the active goals and the floor card, skipping any already shown
    // (persisted in `winStore`) and marking freshly-detected ones as shown so they play once.
    private func refreshWins() {
        var result: [UUID: GoalWinKind] = [:]
        for state in active {
            if let win = GoalWins.newWin(
                completed: state.progress.status == .met,
                currentStreak: state.progress.currentStreak,
                alreadyCelebrated: winStore.celebrated(for: state.id)
            ) {
                result[state.id] = win.kind
                winStore.markCelebrated(win.key, for: state.id)
            }
        }
        if let floorSummary {
            let id = ProteinFloorGoal.syntheticGoalID
            if let win = GoalWins.newWin(
                completed: false,
                currentStreak: floorSummary.currentStreak,
                alreadyCelebrated: winStore.celebrated(for: id)
            ) {
                result[id] = win.kind
                winStore.markCelebrated(win.key, for: id)
            }
        }
        wins = result
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

    // A floor streak that lands exactly on the 7-day milestone, with a couple of no-data and
    // below-floor days further back so the grid and "logged days" count show real variety.
    private static func previewFloorSummary() -> ProteinFloorGoal.Summary {
        let calendar = Calendar.current
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 30))!
        let floorTarget = 130.0
        // Oldest (13 days ago) to newest (today). `nil` means no log that day.
        let proteinByDay: [Double?] = [
            142, nil, 96, 150, 145, 138, 90,
            130, 141, 150, 144, 139, 152, 160,
        ]
        let summaries: [DailySummary] = proteinByDay.enumerated().compactMap { offset, protein in
            guard let protein else { return nil }
            let date = calendar.date(byAdding: .day, value: offset - (proteinByDay.count - 1), to: today)!
            return DailySummary(date: date, calories: 1_500, proteinG: protein, carbsG: 120, fatG: 50, fiberG: 22)
        }
        return ProteinFloorGoal.summary(from: summaries, floorTarget: floorTarget, today: today, calendar: calendar)!
    }

    // A couple of finished goals for the trophy shelf: one met, one honestly not.
    private static func previewCompletedStates() -> [GoalCardState] {
        let userId = UUID()
        let calendar = Calendar.current
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d))!
        }
        func completedBundle(title: String, start: String, end: String, metCount: Int, totalDays: Int) -> GoalCardState {
            let versionId = UUID()
            let goalId = UUID()
            let measurement = GoalMeasurement(
                id: UUID(), goalVersionId: versionId, userId: userId, role: "primary",
                name: title, kind: .habit, aggregation: .rate, comparison: .atLeast,
                targetValue: 0.75, unit: nil, sourceType: .manualBoolean, sourceMetric: nil,
                minimumCoverage: 0.5, createdAt: date(2026, 8, 1)
            )
            let goal = PersonalGoal(
                id: goalId, userId: userId, status: .completed,
                currentVersionId: versionId, createdAt: date(2026, 8, 1),
                completedAt: date(2026, 8, 21)
            )
            let version = GoalVersion(
                id: versionId, goalId: goalId, userId: userId, versionNumber: 1,
                title: title, detail: nil, period: .custom,
                startDate: start, endDate: end, timezoneId: TimeZone.current.identifier,
                scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7],
                effectiveFrom: start, effectiveTo: nil, createdAt: date(2026, 8, 1)
            )
            let goalBundle = PersonalGoalBundle(
                goal: goal, version: version, measurements: [measurement],
                checkins: [], observations: []
            )
            let startDate = date(2026, 8, 1)
            let values = (0..<totalDays).map { offset in
                GoalDailyValue(
                    date: calendar.date(byAdding: .day, value: offset, to: startDate)!,
                    boolean: offset < metCount
                )
            }
            let progress = GoalProgressCalculator.calculate(
                version: version, measurement: measurement, values: values,
                today: date(2026, 8, 21), calendar: calendar
            )
            return .init(bundle: goalBundle, values: values, progress: progress, quality: nil)
        }

        return [
            completedBundle(
                title: "Stretch after lunch", start: "2026-08-01", end: "2026-08-21",
                metCount: 18, totalDays: 21
            ),
            completedBundle(
                title: "10,000 steps average", start: "2026-08-01", end: "2026-08-21",
                metCount: 9, totalDays: 21
            ),
        ]
    }

    // Presentational only — a fixed win so screenshots and manual QA can see the celebration
    // without writing to (and permanently tripping) the real win store.
    private static func previewWins(floorSummary: ProteinFloorGoal.Summary?) -> [UUID: GoalWinKind] {
        guard let floorSummary, GoalWins.milestoneDays.contains(floorSummary.currentStreak) else { return [:] }
        return [ProteinFloorGoal.syntheticGoalID: .streak(days: floorSummary.currentStreak)]
    }

    /// One running experiment (against the protein goal above) and one finished experiment
    /// with a result (against the sleep goal), so the Goals tile and Personal experiments have
    /// something real to show under `--goals-preview`/`--tour`. Dates are relative to the
    /// actual current time rather than the fixed August 2026 used above, so "day X of Y" stays
    /// sensible however long after this was written the preview is run.
    private static func previewExperimentFixtures(for states: [GoalCardState]) -> [PersonalExperiment] {
        guard let runningGoal = states.first(where: { $0.bundle.version.title.contains("protein") }),
              let finishedGoal = states.first(where: { $0.bundle.version.title.contains("sleep") })
        else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func offset(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: today)! }

        let running = PersonalExperiment(
            id: UUID(), userId: runningGoal.bundle.goal.userId,
            interventionGoalId: runningGoal.id,
            question: "Does hitting my protein target improve my sleep?",
            status: .running, baselineStart: nil,
            interventionStart: offset(-6).isoDateString, endDate: offset(14).isoDateString,
            createdAt: offset(-6), completedAt: nil,
            outcomeMeasurements: [ExperimentOutcomeMeasurement(
                measurementId: UUID(), role: "primary_outcome",
                metric: ExperimentMetricSummary(name: "Sleep duration", unit: "hours", sourceType: .automatic, sourceMetric: .sleepDuration)
            )]
        )

        let finished = PersonalExperiment(
            id: UUID(), userId: finishedGoal.bundle.goal.userId,
            interventionGoalId: finishedGoal.id,
            question: "Does an earlier bedtime raise my morning energy?",
            status: .completed, baselineStart: nil,
            interventionStart: offset(-35).isoDateString, endDate: offset(-14).isoDateString,
            createdAt: offset(-35), completedAt: offset(-14),
            outcomeMeasurements: [ExperimentOutcomeMeasurement(
                measurementId: UUID(), role: "primary_outcome",
                metric: ExperimentMetricSummary(name: "Morning energy", unit: "out of 5", sourceType: .manualRating)
            )]
        )

        return [running, finished]
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
