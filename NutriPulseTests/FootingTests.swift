import XCTest
import Supabase
import UserNotifications
import SwiftData
@testable import Footing

final class FootingTests: XCTestCase {
    func testMealSortOrder() {
        let meals = Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(meals, [.breakfast, .lunch, .preWorkout, .postWorkout, .dinner, .snack])
    }

    func testWorkoutMealCategoriesUseStableStorageValuesAndFriendlyLabels() {
        XCTAssertEqual(Meal.preWorkout.rawValue, "pre_workout")
        XCTAssertEqual(Meal.postWorkout.rawValue, "post_workout")
        XCTAssertEqual(Meal.preWorkout.displayName, "Pre-Workout")
        XCTAssertEqual(Meal.postWorkout.displayName, "Post-Workout")
        XCTAssertNotNil(Meal(rawValue: "snack"))
    }

    func testFoodLogTotals() {
        let log = FoodLog(
            id: UUID(),
            userId: UUID(),
            loggedAt: Date(),
            logDate: "2024-03-15",
            meal: .breakfast,
            foodItemId: UUID(),
            quantity: 2.0,
            caloriesSnapshot: 100,
            proteinGSnapshot: 10,
            carbsGSnapshot: 15,
            fatGSnapshot: 3,
            fiberGSnapshot: 2,
            foodItems: nil
        )
        XCTAssertEqual(log.totalCalories, 200)
        XCTAssertEqual(log.totalProteinG, 20)
        XCTAssertEqual(log.totalFiberG, 4)
    }

    func testDateISOString() {
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.isoDateString, "2024-03-15")
    }
}

// MARK: - Progress summaries

final class ProgressSummaryTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .iso8601)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day))!
    }

    private func summaries(count: Int, endingOn end: Date? = nil) -> [DailySummary] {
        let end = end ?? date(30)
        return (0..<count).map { offset in
            DailySummary(
                date: calendar.date(byAdding: .day, value: offset - (count - 1), to: end)!,
                calories: offset % 5 == 0 ? 0 : 1_400,
                proteinG: offset % 3 == 0 ? 100 : 140,
                carbsG: 120,
                fatG: 50,
                fiberG: 20
            )
        }
    }

    func testSummaryRequiresThreeMeasuredDays() {
        let notReady = ProgressMetrics(summaries: Array(summaries(count: 3).prefix(2)), proteinGoal: 130)
        let ready = ProgressMetrics(summaries: summaries(count: 4), proteinGoal: 130)
        XCTAssertFalse(notReady.summaryReady)
        XCTAssertTrue(ready.summaryReady)
    }

    func testNoGoalUsesLoggedStateInsteadOfMet() {
        let logged = DailySummary(date: date(30), calories: 1_400, proteinG: 120, carbsG: 0, fatG: 0, fiberG: 0)
        let metrics = ProgressMetrics(summaries: [logged], proteinGoal: nil)
        XCTAssertEqual(metrics.state(for: logged), .logged)
        XCTAssertFalse(metrics.hasGoal)
        XCTAssertEqual(metrics.completion, 1)
    }

    func testNinetyDaysBecomeThirteenWeeklyIntervals() {
        let intervals = ProgressTimelineBuilder.thirteenWeeks(
            summaries: summaries(count: 90),
            proteinGoal: 130
        )
        XCTAssertEqual(intervals.count, 13)
        XCTAssertEqual(intervals.reduce(0) { $0 + $1.expectedDays }, 90)
    }

    func testSinceLastShotStartsOnMostRecentDose() {
        let userId = UUID()
        let shots = [20, 27].map { day in
            GLP1Log(
                id: UUID(), userId: userId, injectedAt: date(day),
                medication: "Zepbound", doseMg: 5, site: nil, nextDueAt: nil
            )
        }
        let window = ProgressSummaryPeriod.sinceLastShot.window(
            shots: shots,
            now: date(30),
            calendar: calendar
        )
        XCTAssertEqual(window?.lowerBound, date(27))
        XCTAssertEqual(window?.upperBound, date(30))
    }

    func testPreviousSevenDaySummariesExcludeCurrentPeriod() {
        let data = summaries(count: 28)
        let history = ProgressHistoryBuilder.previousPeriods(
            for: .week,
            summaries: data,
            shots: [],
            now: date(30),
            calendar: calendar
        )
        XCTAssertEqual(history.count, 3)
        XCTAssertFalse(history[0].dateRange.contains("Aug 30"))
    }
}

// MARK: - Daylight Progress hero (trend pill, "Try this" suggestion)

final class ProgressTrendTests: XCTestCase {
    func testRollingAverageSmoothsATrailingWindow() {
        XCTAssertEqual(ProgressTrendBuilder.rollingAverage([100, 140, 120, 160], window: 3),
                       [100, 120, 120, 140])
        XCTAssertEqual(ProgressTrendBuilder.rollingAverage([5, 7], window: 1), [5, 7])
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .iso8601)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day))!
    }

    private func summary(_ day: Int, protein: Double) -> DailySummary {
        DailySummary(date: date(day), calories: 1_400, proteinG: protein, carbsG: 120, fatG: 50, fiberG: 20)
    }

    func testTrendComparesMetCountsBetweenPeriods() {
        let current = ProgressMetrics(
            summaries: [summary(8, protein: 140), summary(9, protein: 140), summary(10, protein: 90)],
            proteinGoal: 130
        )
        let previous = ProgressMetrics(
            summaries: [summary(1, protein: 90), summary(2, protein: 90), summary(3, protein: 140)],
            proteinGoal: 130
        )
        let trend = ProgressTrendBuilder.trend(current: current, previous: previous)
        XCTAssertEqual(trend?.currentMet, 2)
        XCTAssertEqual(trend?.previousMet, 1)
        XCTAssertEqual(trend?.direction, .up)
        XCTAssertEqual(trend?.label, "Up from 1")
    }

    func testTrendIsNilWithoutAGoal() {
        let current = ProgressMetrics(summaries: [summary(8, protein: 140)], proteinGoal: nil)
        let previous = ProgressMetrics(summaries: [summary(1, protein: 90)], proteinGoal: nil)
        XCTAssertNil(ProgressTrendBuilder.trend(current: current, previous: previous))
    }

    func testTrendIsNilWithNoMeasuredPreviousDays() {
        let current = ProgressMetrics(summaries: [summary(8, protein: 140)], proteinGoal: 130)
        let previous = ProgressMetrics(summaries: [], proteinGoal: 130)
        XCTAssertNil(ProgressTrendBuilder.trend(current: current, previous: previous))
    }

    func testPreviousWindowIsSameLengthImmediatelyBeforeCurrent() {
        let window = ProgressRange.week.previousWindow(now: date(30), calendar: calendar)
        // .week covers the trailing 7 days ending "now" (Aug 24...Aug 30), so the previous
        // window is the 7 days immediately before that.
        XCTAssertEqual(window.lowerBound, date(17))
        XCTAssertEqual(window.upperBound, date(23))
    }

    func testTryThisFlagsAverageBelowFloor() {
        let metrics = ProgressMetrics(
            summaries: [summary(8, protein: 100), summary(9, protein: 100)],
            proteinGoal: 130
        )
        XCTAssertTrue(ProgressTryThisBuilder.text(metrics).contains("under your floor"))
    }

    func testTryThisPraisesWhenFloorIsCleared() {
        let metrics = ProgressMetrics(
            summaries: [summary(8, protein: 140), summary(9, protein: 150)],
            proteinGoal: 130
        )
        XCTAssertTrue(ProgressTryThisBuilder.text(metrics).contains("keep repeating"))
    }
}

// MARK: - Health data quality

final class HealthDataQualityEngineTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .iso8601)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    func testMissingReadingsAreInsufficientRatherThanZero() {
        let result = HealthDataQualityEngine.assess(
            metric: .steps,
            observations: [],
            expectedDates: [date(28), date(29), date(30)],
            now: date(30, hour: 23),
            calendar: calendar
        )
        XCTAssertEqual(result.status, .insufficientData)
        XCTAssertEqual(result.observedCount, 0)
        XCTAssertTrue(result.issueCodes.contains(HealthDataQualityIssueCode.missingData.rawValue))
    }

    func testImplausibleReadingIsQuarantinedWithoutChangingRawInput() {
        let raw = [HealthQualityObservation(metric: .sleepDuration, value: 27, observedAt: date(30))]
        let result = HealthDataQualityEngine.assess(
            metric: .sleepDuration,
            observations: raw,
            expectedDates: [date(30)],
            now: date(30, hour: 23),
            calendar: calendar
        )
        XCTAssertEqual(raw.count, 1)
        XCTAssertTrue(result.usableObservations.isEmpty)
        XCTAssertEqual(result.outlierCount, 1)
        XCTAssertEqual(result.status, .implausible)
        XCTAssertEqual(
            result.issues.first { $0.code == .implausibleValue }?.detail,
            "1 reading fell outside Footing’s conservative validation range and was excluded."
        )
    }

    func testDisagreeingSourcesAreExcludedFromDerivedResults() {
        let observations = [
            HealthQualityObservation(metric: .sleepDuration, value: 7, observedAt: date(30), sourceIdentifier: "watch"),
            HealthQualityObservation(metric: .sleepDuration, value: 10, observedAt: date(30), sourceIdentifier: "ring"),
        ]
        let result = HealthDataQualityEngine.assess(
            metric: .sleepDuration,
            observations: observations,
            expectedDates: [date(30)],
            now: date(30, hour: 23),
            calendar: calendar
        )
        XCTAssertEqual(result.status, .conflictingSources)
        XCTAssertEqual(result.sourceCount, 2)
        XCTAssertTrue(result.usableObservations.isEmpty)
        XCTAssertEqual(
            result.issues.first { $0.code == .conflictingSources }?.detail,
            "Sources disagreed beyond the expected tolerance on 1 day."
        )
    }

    func testSourceTransitionMakesTrendUsableWithCaution() {
        let observations = [
            HealthQualityObservation(metric: .weight, value: 90, observedAt: date(28), sourceIdentifier: "scale-a"),
            HealthQualityObservation(metric: .weight, value: 89.8, observedAt: date(29), sourceIdentifier: "scale-a"),
            HealthQualityObservation(metric: .weight, value: 89.7, observedAt: date(30), sourceIdentifier: "scale-b"),
        ]
        let result = HealthDataQualityEngine.assess(
            metric: .weight,
            observations: observations,
            expectedDates: [date(28), date(29), date(30)],
            now: date(30, hour: 23),
            calendar: calendar
        )
        XCTAssertEqual(result.status, .usableWithCaution)
        XCTAssertTrue(result.issueCodes.contains(HealthDataQualityIssueCode.sourceChanged.rawValue))
    }

    func testInProgressDayIsMarkedPartial() {
        let result = HealthDataQualityEngine.assess(
            metric: .steps,
            observations: [.init(metric: .steps, value: 4_000, observedAt: date(30, hour: 10))],
            expectedDates: [date(30)],
            now: date(30, hour: 12),
            calendar: calendar
        )
        XCTAssertEqual(result.status, .usableWithCaution)
        XCTAssertTrue(result.issueCodes.contains(HealthDataQualityIssueCode.partialDay.rawValue))
    }

    func testLastNightsSleepIsNotTreatedAsPartialToday() {
        let result = HealthDataQualityEngine.assess(
            metric: .sleepDuration,
            observations: [.init(metric: .sleepDuration, value: 7.5, observedAt: date(30, hour: 8))],
            expectedDates: [date(30)],
            now: date(30, hour: 12),
            calendar: calendar
        )
        XCTAssertEqual(result.status, .usable)
        XCTAssertFalse(result.issueCodes.contains(HealthDataQualityIssueCode.partialDay.rawValue))
    }
}

// MARK: - Personal goals

final class GoalProgressCalculatorTests: XCTestCase {
    private let userId = UUID()
    private let goalId = UUID()
    private let versionId = UUID()
    private var calendar: Calendar {
        var value = Calendar(identifier: .iso8601)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ value: String) -> Date {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: .init(year: parts[0], month: parts[1], day: parts[2]))!
    }

    private func version(
        period: GoalPeriod = .custom,
        start: String = "2026-08-24",
        end: String? = "2026-08-30"
    ) -> GoalVersion {
        GoalVersion(
            id: versionId, goalId: goalId, userId: userId, versionNumber: 1,
            title: "Test goal", detail: nil, period: period,
            startDate: start, endDate: end, timezoneId: "UTC",
            scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7],
            effectiveFrom: start, effectiveTo: nil, createdAt: date(start)
        )
    }

    private func measurement(
        kind: GoalMeasurementKind,
        aggregation: GoalAggregation,
        comparison: GoalComparison,
        target: Double?,
        coverage: Double = 0
    ) -> GoalMeasurement {
        GoalMeasurement(
            id: UUID(), goalVersionId: versionId, userId: userId, role: "primary",
            name: "Test", kind: kind, aggregation: aggregation,
            comparison: comparison, targetValue: target, unit: nil,
            sourceType: .manualNumber, sourceMetric: nil,
            minimumCoverage: coverage, createdAt: date("2026-08-24")
        )
    }

    func testHabitMissingDayDoesNotBecomeFailureOrBreakConfirmedStreak() {
        let metric = measurement(kind: .habit, aggregation: .rate, comparison: .atLeast, target: 0.75)
        let values = [
            GoalDailyValue(date: date("2026-08-24"), boolean: true),
            GoalDailyValue(date: date("2026-08-26"), boolean: true),
            GoalDailyValue(date: date("2026-08-27"), boolean: false),
            GoalDailyValue(date: date("2026-08-29"), boolean: true),
            GoalDailyValue(date: date("2026-08-30"), boolean: true),
        ]
        let result = GoalProgressCalculator.calculate(
            version: version(), measurement: metric, values: values,
            today: date("2026-08-30"), calendar: calendar
        )
        XCTAssertEqual(result.metCount, 4)
        XCTAssertEqual(result.missedCount, 1)
        XCTAssertEqual(result.measuredCount, 5)
        XCTAssertEqual(result.currentStreak, 2)
    }

    func testAccumulationUsesTargetToDate() {
        let metric = measurement(kind: .accumulation, aggregation: .sum, comparison: .atLeast, target: 700)
        let values = (24...27).map { GoalDailyValue(date: date("2026-08-\($0)"), number: 100) }
        let result = GoalProgressCalculator.calculate(
            version: version(), measurement: metric, values: values,
            today: date("2026-08-27"), calendar: calendar
        )
        XCTAssertEqual(result.value, 400)
        XCTAssertEqual(result.status, .onTrack)
    }

    func testFrequencyCountsConfirmedQualifyingEvents() {
        let metric = measurement(kind: .frequency, aggregation: .count, comparison: .atLeast, target: 3)
        let values = [24, 25, 26].map { GoalDailyValue(date: date("2026-08-\($0)"), boolean: true) }
        let result = GoalProgressCalculator.calculate(
            version: version(), measurement: metric, values: values,
            today: date("2026-08-26"), calendar: calendar
        )
        XCTAssertEqual(result.value, 3)
        XCTAssertEqual(result.status, .onTrack)
    }

    func testAverageAndThresholdCompareOnlyMeasuredValues() {
        let metric = measurement(kind: .average, aggregation: .average, comparison: .atLeast, target: 8)
        let values = [7.0, 9.0].enumerated().map {
            GoalDailyValue(date: date("2026-08-\(24 + $0.offset)"), number: $0.element)
        }
        let result = GoalProgressCalculator.calculate(
            version: version(), measurement: metric, values: values,
            today: date("2026-08-25"), calendar: calendar
        )
        XCTAssertEqual(result.value, 8)
        XCTAssertEqual(result.status, .onTrack)
    }

    func testReachTargetUsesBaselineAndElapsedPace() {
        let metric = measurement(kind: .target, aggregation: .latest, comparison: .reach, target: 90)
        let values = [
            GoalDailyValue(date: date("2026-08-24"), number: 100),
            GoalDailyValue(date: date("2026-08-27"), number: 94),
        ]
        let result = GoalProgressCalculator.calculate(
            version: version(), measurement: metric, values: values,
            today: date("2026-08-27"), calendar: calendar
        )
        XCTAssertEqual(result.status, .onTrack)
    }

    func testBelowThresholdAndRate() {
        let threshold = measurement(kind: .threshold, aggregation: .average, comparison: .atMost, target: 5)
        let thresholdResult = GoalProgressCalculator.calculate(
            version: version(), measurement: threshold,
            values: [GoalDailyValue(date: date("2026-08-24"), number: 4)],
            today: date("2026-08-24"), calendar: calendar
        )
        XCTAssertEqual(thresholdResult.status, .onTrack)

        let rate = measurement(kind: .habit, aggregation: .rate, comparison: .atLeast, target: 0.5)
        let rateResult = GoalProgressCalculator.calculate(
            version: version(), measurement: rate,
            values: [
                GoalDailyValue(date: date("2026-08-24"), boolean: true),
                GoalDailyValue(date: date("2026-08-25"), boolean: false),
            ],
            today: date("2026-08-25"), calendar: calendar
        )
        XCTAssertEqual(rateResult.value, 0.5)
        XCTAssertEqual(rateResult.status, .onTrack)
    }

    func testSubjectiveCheckinTracksWithoutJudgingSuccess() {
        let metric = measurement(kind: .subjective, aggregation: .average, comparison: .none, target: nil)
        let result = GoalProgressCalculator.calculate(
            version: version(period: .ongoing, end: nil), measurement: metric,
            values: [GoalDailyValue(date: date("2026-08-30"), number: 3)],
            today: date("2026-08-30"), calendar: calendar
        )
        XCTAssertEqual(result.value, 3)
        XCTAssertEqual(result.status, .pending)
    }

    func testGoalRemainsActiveThroughItsInclusiveEndDate() {
        XCTAssertFalse(GoalLifecycle.hasEnded(
            version(end: "2026-08-30"),
            today: date("2026-08-30"),
            calendar: calendar
        ))
    }

    func testFiniteGoalEndsOnTheFollowingLocalDay() {
        XCTAssertTrue(GoalLifecycle.hasEnded(
            version(end: "2026-08-30"),
            today: date("2026-08-31"),
            calendar: calendar
        ))
    }

    func testOngoingGoalDoesNotAutoComplete() {
        XCTAssertFalse(GoalLifecycle.hasEnded(
            version(period: .ongoing, end: nil),
            today: date("2027-08-30"),
            calendar: calendar
        ))
    }
}

final class GoalDraftTests: XCTestCase {
    func testProteinSuggestionUsesFoodLogsRatherThanAppleHealth() {
        let draft = GoalDraft(template: .protein)
        XCTAssertEqual(draft.trackingSource, .foodLogs)
        XCTAssertEqual(draft.sourceMetric, .protein)
        XCTAssertEqual(draft.targetValue, 5)
        XCTAssertEqual(draft.period, .weekly)
    }

    func testSelectingAppleHealthMetricAppliesCoherentDefaults() {
        var draft = GoalDraft()
        draft.select(.appleHealth)
        draft.select(.sleepDuration)
        XCTAssertEqual(draft.trackingSource, .appleHealth)
        XCTAssertEqual(draft.kind, .average)
        XCTAssertEqual(draft.aggregation, .average)
        XCTAssertEqual(draft.targetValue, 8)
        XCTAssertEqual(draft.unit, "hours")
        XCTAssertEqual(draft.durationDays, 42)
    }

    func testManualBooleanDisplaysPercentButStoresRate() {
        var draft = GoalDraft()
        draft.displayTargetValue = 85
        XCTAssertEqual(draft.targetValue, 0.85, accuracy: 0.0001)
        XCTAssertEqual(draft.displayTargetValue, 85, accuracy: 0.0001)
    }

    func testCustomGoalRequiresATitle() {
        var draft = GoalDraft()
        XCTAssertFalse(draft.isValid)
        draft.title = "Stretch after lunch"
        XCTAssertTrue(draft.isValid)
    }
}

// MARK: - Protein floor (built-in goal)

final class ProteinFloorGoalTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .iso8601)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ value: String) -> Date {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: .init(year: parts[0], month: parts[1], day: parts[2]))!
    }

    private func summary(_ date: Date, protein: Double) -> DailySummary {
        DailySummary(date: date, calories: 1_500, proteinG: protein, carbsG: 100, fatG: 50, fiberG: 20)
    }

    func testNoEffectiveFloorMeansNoCard() {
        let result = ProteinFloorGoal.summary(
            from: [], floorTarget: nil, today: date("2026-08-30"), calendar: calendar
        )
        XCTAssertNil(result)

        let zeroTarget = ProteinFloorGoal.summary(
            from: [], floorTarget: 0, today: date("2026-08-30"), calendar: calendar
        )
        XCTAssertNil(zeroTarget)
    }

    func testDaysWithoutLogsAreNoDataNeverBelow() {
        let today = date("2026-08-30")
        // Only today has a summary; every other day of the window is unlogged.
        let result = ProteinFloorGoal.summary(
            from: [summary(today, protein: 150)], floorTarget: 130, today: today, calendar: calendar
        )!
        XCTAssertEqual(result.days.count, ProteinFloorGoal.windowDays)
        XCTAssertEqual(result.days.dropLast().allSatisfy { $0.state == .missing }, true)
        XCTAssertEqual(result.days.last?.state, .met)
        XCTAssertEqual(result.loggedDays, 1)
        XCTAssertEqual(result.totalDays, ProteinFloorGoal.windowDays)
    }

    func testStreakSkipsMissingDaysButStopsAtAConfirmedMiss() {
        let today = date("2026-08-30")
        let summaries = [
            summary(calendar.date(byAdding: .day, value: -3, to: today)!, protein: 90),   // below
            // -2 days ago: no log at all (missing, skipped)
            summary(calendar.date(byAdding: .day, value: -1, to: today)!, protein: 140),  // met
            summary(today, protein: 150),                                                 // met
        ]
        let result = ProteinFloorGoal.summary(from: summaries, floorTarget: 130, today: today, calendar: calendar)!
        XCTAssertEqual(result.currentStreak, 2)
    }

    func testTodayProgressAndCaption() {
        let today = date("2026-08-30")
        let underFloor = ProteinFloorGoal.summary(
            from: [summary(today, protein: 90)], floorTarget: 130, today: today, calendar: calendar
        )!
        XCTAssertEqual(underFloor.todayCaption, "40g to go")
        XCTAssertFalse(underFloor.todayMet)
        XCTAssertEqual(underFloor.todayProgress, 90.0 / 130.0, accuracy: 0.0001)

        let clearedFloor = ProteinFloorGoal.summary(
            from: [summary(today, protein: 160)], floorTarget: 130, today: today, calendar: calendar
        )!
        XCTAssertEqual(clearedFloor.todayCaption, "Floor cleared")
        XCTAssertTrue(clearedFloor.todayMet)
        XCTAssertEqual(clearedFloor.todayProgress, 1, accuracy: 0.0001)
    }

    func testNoLogTodayShowsFullRemainingFloor() {
        let today = date("2026-08-30")
        let result = ProteinFloorGoal.summary(from: [], floorTarget: 130, today: today, calendar: calendar)!
        XCTAssertEqual(result.todayProteinG, 0)
        XCTAssertEqual(result.todayCaption, "130g to go")
        XCTAssertFalse(result.todayMet)
    }
}

// MARK: - Gentle cap on active goals

final class GoalCreationPolicyTests: XCTestCase {
    func testWarnsAtAndAboveTheSuggestedLimitButNotBelowIt() {
        XCTAssertFalse(GoalCreationPolicy.shouldWarnBeforeAdding(activeGoalCount: 0))
        XCTAssertFalse(GoalCreationPolicy.shouldWarnBeforeAdding(activeGoalCount: 2))
        XCTAssertTrue(GoalCreationPolicy.shouldWarnBeforeAdding(activeGoalCount: 3))
        XCTAssertTrue(GoalCreationPolicy.shouldWarnBeforeAdding(activeGoalCount: 4))
    }

    func testCustomLimitIsRespected() {
        XCTAssertFalse(GoalCreationPolicy.shouldWarnBeforeAdding(activeGoalCount: 3, limit: 5))
        XCTAssertTrue(GoalCreationPolicy.shouldWarnBeforeAdding(activeGoalCount: 5, limit: 5))
    }
}

// MARK: - Goal wins

final class GoalWinsTests: XCTestCase {
    func testCompletionWinsOnceThenStopsWithoutRelitigating() {
        let first = GoalWins.newWin(completed: true, currentStreak: 0, alreadyCelebrated: [])
        XCTAssertEqual(first?.kind, .completed)

        let repeatCall = GoalWins.newWin(completed: true, currentStreak: 0, alreadyCelebrated: [GoalWins.Keys.completed])
        XCTAssertNil(repeatCall)
    }

    func testStreakMilestoneFiresExactlyOnceAtEachMilestone() {
        let sevenDay = GoalWins.newWin(completed: false, currentStreak: 7, alreadyCelebrated: [])
        XCTAssertEqual(sevenDay?.kind, .streak(days: 7))
        XCTAssertEqual(sevenDay?.key, GoalWins.Keys.streak(7))

        let alreadyShown = GoalWins.newWin(
            completed: false, currentStreak: 7, alreadyCelebrated: [GoalWins.Keys.streak(7)]
        )
        XCTAssertNil(alreadyShown)
    }

    func testStreakWinsCelebrateTheHighestMilestoneReachedOnce() {
        // Missing the exact day doesn't lose the win: first opened on day 9, the 7 still plays.
        XCTAssertEqual(GoalWins.newWin(completed: false, currentStreak: 9, alreadyCelebrated: [])?.kind, .streak(days: 7))
        // Past 14 before ever looking: celebrate 14, and 7 never fires afterward.
        XCTAssertEqual(GoalWins.newWin(completed: false, currentStreak: 16, alreadyCelebrated: [])?.kind, .streak(days: 14))
        XCTAssertNil(GoalWins.newWin(completed: false, currentStreak: 16, alreadyCelebrated: [GoalWins.Keys.streak(14)]))
        XCTAssertNil(GoalWins.newWin(completed: false, currentStreak: 6, alreadyCelebrated: []))
        XCTAssertNil(GoalWins.newWin(completed: false, currentStreak: 0, alreadyCelebrated: []))
    }

    func testCompletionTakesPriorityWhenBothLandOnTheSameDay() {
        let win = GoalWins.newWin(completed: true, currentStreak: 14, alreadyCelebrated: [])
        XCTAssertEqual(win?.kind, .completed)
    }
}

final class GoalWinStoreTests: XCTestCase {
    private func makeStore() -> GoalWinStore {
        let suiteName = "GoalWinStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return GoalWinStore(defaults: defaults)
    }

    func testUncelebratedGoalStartsEmpty() {
        let store = makeStore()
        XCTAssertTrue(store.celebrated(for: UUID()).isEmpty)
    }

    func testMarkingCelebratedPersistsPerGoalAndKey() {
        let store = makeStore()
        let goalA = UUID()
        let goalB = UUID()
        store.markCelebrated(GoalWins.Keys.completed, for: goalA)
        store.markCelebrated(GoalWins.Keys.streak(7), for: goalA)
        store.markCelebrated(GoalWins.Keys.streak(7), for: goalB)

        XCTAssertEqual(store.celebrated(for: goalA), [GoalWins.Keys.completed, GoalWins.Keys.streak(7)])
        XCTAssertEqual(store.celebrated(for: goalB), [GoalWins.Keys.streak(7)])
    }
}

// MARK: - Explainable insights

final class InsightEngineTests: XCTestCase {
    private let userId = UUID()

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
    }

    func testWeeklyReviewRequiresEnoughRealDays() {
        let sparse = [
            DailySummary(date: day(-2), calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0),
            DailySummary(date: day(-1), calories: 1800, proteinG: 110, carbsG: 0, fatG: 0, fiberG: 0),
            DailySummary(date: day(0), calories: 1700, proteinG: 100, carbsG: 0, fatG: 0, fiberG: 0),
        ]
        XCTAssertNil(WeeklyReviewEngine.build(summaries: sparse, movement: [], checkIns: [], proteinGoal: 120))

        var enough = sparse
        enough[0].calories = 1600
        enough[0].proteinG = 125
        XCTAssertNotNil(WeeklyReviewEngine.build(summaries: enough, movement: [], checkIns: [], proteinGoal: 120))
    }

    func testCycleAnalyticsAlignsNutritionToDaySinceDose() {
        let injection = GLP1Log(
            id: UUID(), userId: userId, injectedAt: day(-2), medication: "Zepbound",
            doseMg: 5, site: nil, nextDueAt: day(5)
        )
        let summaries = [
            DailySummary(date: day(-2), calories: 1600, proteinG: 120, carbsG: 0, fatG: 0, fiberG: 0),
            DailySummary(date: day(-1), calories: 1500, proteinG: 100, carbsG: 0, fatG: 0, fiberG: 0),
        ]
        let result = CycleAnalyticsEngine.build(
            summaries: summaries, hydration: [], movement: [], weightLogs: [],
            checkIns: [], injections: [injection]
        )
        XCTAssertEqual(result.map(\.cycleDay), [0, 1])
        XCTAssertEqual(result.last?.averageProteinG, 100)
    }

    func testRecoveryContextExplainsSignalsInsteadOfProducingAScore() throws {
        let context = try XCTUnwrap(RecoveryContextEngine.build(
            sleepHours: 6, baselineSleep: 7.5,
            hrv: 35, baselineHRV: 50,
            restingHR: 65, baselineRestingHR: 58,
            workoutMinutes: 50,
            proteinG: 50, proteinGoalG: 120,
            waterMl: 500, waterGoalMl: 2000
        ))
        XCTAssertEqual(context.headline, "Give recovery more room today")
        XCTAssertGreaterThanOrEqual(context.signals.count, 3)
        XCTAssertFalse(context.headline.lowercased().contains("score"))
    }

    func testBodyMilestoneRecognizesLeanMassProtection() {
        let milestones = BodyMilestoneEngine.detect(
            weight: [(day(-30), 100), (day(0), 97)],
            leanMass: [(day(-30), 65), (day(0), 64.5)],
            waist: []
        )
        XCTAssertTrue(milestones.contains { $0.title == "Lean mass held" })
    }
}

final class ExperimentComparisonEngineTests: XCTestCase {
    func testDaysJoinsOutcomeAndInterventionByDate() {
        let days = ExperimentComparisonEngine.days(
            outcomeByDate: ["2026-09-01": 7.0, "2026-09-02": 6.0, "2026-09-04": 5.5],
            interventionByDate: ["2026-09-01": true, "2026-09-03": false]
        )
        XCTAssertEqual(days.map(\.localDate), ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04"])
        XCTAssertEqual(days[0].didIntervene, true)
        XCTAssertEqual(days[0].outcomeValue, 7.0)
        XCTAssertNil(days[1].didIntervene)
        XCTAssertEqual(days[2].didIntervene, false)
        XCTAssertNil(days[2].outcomeValue)
    }

    func testCompareReturnsNilWithoutDataOnBothSides() {
        let onlyIntervention = (0..<6).map {
            ExperimentDayObservation(localDate: "day\($0)", didIntervene: true, outcomeValue: 7)
        }
        XCTAssertNil(ExperimentComparisonEngine.compare(onlyIntervention))
    }

    func testCompareIsUnreadableBelowFiveMeasuredDaysPerSide() {
        // 4 intervention days, 4 non-intervention days — under the floor on both sides.
        var days: [ExperimentDayObservation] = []
        for i in 0..<4 {
            days.append(.init(localDate: "with\(i)", didIntervene: true, outcomeValue: 8.0))
            days.append(.init(localDate: "without\(i)", didIntervene: false, outcomeValue: 6.0))
        }
        let result = try! XCTUnwrap(ExperimentComparisonEngine.compare(days))
        XCTAssertFalse(result.isReadable)
        XCTAssertEqual(result.interventionCount, 4)
        XCTAssertEqual(result.nonInterventionCount, 4)
    }

    func testCompareIsUnreadableWhenDifferenceIsWithinNormalVariation() {
        // Five measured days each side, but the values are noisy enough that a ~0.2 gap is not
        // distinguishable from ordinary day-to-day variation.
        let interventionValues: [Double] = [6.0, 7.5, 6.5, 7.2, 6.3]
        let nonInterventionValues: [Double] = [6.1, 7.3, 6.4, 7.0, 6.2]
        var days: [ExperimentDayObservation] = []
        for (i, v) in interventionValues.enumerated() {
            days.append(.init(localDate: "with\(i)", didIntervene: true, outcomeValue: v))
        }
        for (i, v) in nonInterventionValues.enumerated() {
            days.append(.init(localDate: "without\(i)", didIntervene: false, outcomeValue: v))
        }
        let result = try! XCTUnwrap(ExperimentComparisonEngine.compare(days))
        XCTAssertFalse(result.isReadable)
    }

    func testCompareIsReadableWithEnoughDaysAndAClearDifference() {
        let interventionValues: [Double] = [7.8, 8.0, 7.9, 8.1, 7.7, 8.0]
        let nonInterventionValues: [Double] = [6.2, 6.0, 6.3, 6.1, 6.4, 6.0]
        var days: [ExperimentDayObservation] = []
        for (i, v) in interventionValues.enumerated() {
            days.append(.init(localDate: "with\(i)", didIntervene: true, outcomeValue: v))
        }
        for (i, v) in nonInterventionValues.enumerated() {
            days.append(.init(localDate: "without\(i)", didIntervene: false, outcomeValue: v))
        }
        let result = try! XCTUnwrap(ExperimentComparisonEngine.compare(days))
        XCTAssertTrue(result.isReadable)
        XCTAssertEqual(result.interventionCount, 6)
        XCTAssertEqual(result.nonInterventionCount, 6)
        XCTAssertEqual(result.interventionMean, 7.9166, accuracy: 0.01)
        XCTAssertEqual(result.nonInterventionMean, 6.1666, accuracy: 0.01)
        XCTAssertEqual(result.difference, result.interventionMean - result.nonInterventionMean, accuracy: 0.0001)
    }
}

final class ExperimentInterventionDaysTests: XCTestCase {
    func testBuildReadsBooleanObservationsByLocalDate() {
        let measurementId = UUID()
        let otherMeasurementId = UUID()
        let checkinA = UUID(); let checkinB = UUID(); let checkinC = UUID()
        let userId = UUID()
        let checkins = [
            GoalCheckin(id: checkinA, goalId: UUID(), userId: userId, observedAt: .now, localDate: "2026-09-01", note: nil, createdAt: .now),
            GoalCheckin(id: checkinB, goalId: UUID(), userId: userId, observedAt: .now, localDate: "2026-09-02", note: nil, createdAt: .now),
            GoalCheckin(id: checkinC, goalId: UUID(), userId: userId, observedAt: .now, localDate: "2026-09-03", note: nil, createdAt: .now),
        ]
        let observations = [
            GoalObservation(id: UUID(), checkinId: checkinA, measurementId: measurementId, userId: userId, valueBoolean: true, valueNumber: nil, valueText: nil, createdAt: .now),
            GoalObservation(id: UUID(), checkinId: checkinB, measurementId: measurementId, userId: userId, valueBoolean: false, valueNumber: nil, valueText: nil, createdAt: .now),
            // Different measurement — must be ignored.
            GoalObservation(id: UUID(), checkinId: checkinC, measurementId: otherMeasurementId, userId: userId, valueBoolean: true, valueNumber: nil, valueText: nil, createdAt: .now),
        ]
        let result = ExperimentInterventionDays.build(checkins: checkins, observations: observations, measurementId: measurementId)
        XCTAssertEqual(result, ["2026-09-01": true, "2026-09-02": false])
    }
}

final class ExperimentTimelineCalculatorTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testTimelineComputesDayIndexAndTotalDays() {
        let timeline = try! XCTUnwrap(ExperimentTimelineCalculator.timeline(
            interventionStart: "2026-09-01", endDate: "2026-09-21", today: date(2026, 9, 8)
        ))
        XCTAssertEqual(timeline.dayIndex, 8)
        XCTAssertEqual(timeline.totalDays, 21)
        XCTAssertEqual(timeline.progress, 8.0 / 21.0, accuracy: 0.0001)
        XCTAssertFalse(timeline.hasElapsed)
    }

    func testTimelineHasElapsedOncePastTheWindow() {
        let timeline = try! XCTUnwrap(ExperimentTimelineCalculator.timeline(
            interventionStart: "2026-09-01", endDate: "2026-09-07", today: date(2026, 9, 30)
        ))
        XCTAssertTrue(timeline.hasElapsed)
        XCTAssertEqual(timeline.progress, 1.0, accuracy: 0.0001)
    }

    func testTimelineWithoutEndDateHasNoTotalAndNeverElapses() {
        let timeline = try! XCTUnwrap(ExperimentTimelineCalculator.timeline(
            interventionStart: "2026-09-01", endDate: nil, today: date(2026, 10, 1)
        ))
        XCTAssertNil(timeline.totalDays)
        XCTAssertFalse(timeline.hasElapsed)
    }
}

final class ExperimentSuggestionEngineTests: XCTestCase {
    private func insight(
        day: Int, protein: Double?, energy: Double? = nil,
        nutritionSamples: Int = 3, checkInSamples: Int = 3
    ) -> CycleDayInsight {
        CycleDayInsight(
            cycleDay: day, sampleCount: max(nutritionSamples, checkInSamples),
            averageProteinG: protein, averageCalories: nil, averageWaterMl: nil,
            averageWorkoutMinutes: nil, averageAppetite: nil, averageEnergy: energy,
            averageNausea: nil, averageWeightKg: nil,
            nutritionSampleCount: nutritionSamples, hydrationSampleCount: 0,
            movementSampleCount: 0, checkInSampleCount: checkInSamples, weightSampleCount: 0
        )
    }

    func testNoSuggestionsWithoutAClearDip() {
        let flat = (0...6).map { insight(day: $0, protein: 130, energy: 4) }
        XCTAssertTrue(ExperimentSuggestionEngine.suggestions(from: flat).isEmpty)
    }

    func testNoSuggestionWhenDippingDayIsUnderSampled() {
        var insights = (0...6).map { insight(day: $0, protein: 130) }
        // Day 2 dips hard, but only appears once — not enough to call it a pattern.
        insights[2] = insight(day: 2, protein: 60, nutritionSamples: 1)
        XCTAssertTrue(ExperimentSuggestionEngine.suggestions(from: insights).isEmpty)
    }

    func testProteinDipSuggestionNamesTheRangeAndNumbers() {
        var insights = (0...6).map { insight(day: $0, protein: 140) }
        insights[2] = insight(day: 2, protein: 90)
        insights[3] = insight(day: 3, protein: 95)
        let suggestions = ExperimentSuggestionEngine.suggestions(from: insights)
        let protein = try! XCTUnwrap(suggestions.first { $0.outcome == .protein })
        XCTAssertTrue(protein.why.contains("2–3"), protein.why)
        XCTAssertTrue(protein.why.contains("shot day"), protein.why)
        XCTAssertEqual(protein.suggestedDurationDays, ExperimentSuggestionEngine.defaultDurationDays)
    }

    func testSingleDayDipUsesSingularPhrasingNotARange() {
        var insights = (0...6).map { insight(day: $0, protein: 140) }
        insights[5] = insight(day: 5, protein: 80)
        let suggestions = ExperimentSuggestionEngine.suggestions(from: insights)
        let protein = try! XCTUnwrap(suggestions.first { $0.outcome == .protein })
        XCTAssertTrue(protein.why.contains("shot day 5"), protein.why)
        XCTAssertFalse(protein.why.contains("–"))
    }

    func testEnergyDipSuggestionIsIndependentOfProtein() {
        var insights = (0...6).map { insight(day: $0, protein: 130, energy: 4.0) }
        insights[1] = insight(day: 1, protein: 130, energy: 2.0)
        let suggestions = ExperimentSuggestionEngine.suggestions(from: insights)
        let energy = try! XCTUnwrap(suggestions.first { $0.outcome == .energy })
        XCTAssertTrue(energy.why.contains("energy"), energy.why)
        XCTAssertFalse(suggestions.contains { $0.outcome == .protein })
    }

    func testSuggestionsCapAtThree() {
        var insights = (0...6).map { insight(day: $0, protein: 140, energy: 4.0) }
        insights[2] = insight(day: 2, protein: 90, energy: 4.0)
        insights[5] = insight(day: 5, protein: 140, energy: 2.0)
        let suggestions = ExperimentSuggestionEngine.suggestions(from: insights)
        XCTAssertLessThanOrEqual(suggestions.count, 3)
    }
}

final class PulseGateTests: XCTestCase {
    func testHandoffBlockedWhenPulseIsOff() {
        XCTAssertEqual(PulseGate.handoff(pulseEnabled: false, aiConsentAt: nil), .blocked)
        // Even a device that's already consented drops the hand-off once Pulse itself is off —
        // it's the master switch, not just the AI-sharing question.
        XCTAssertEqual(PulseGate.handoff(pulseEnabled: false, aiConsentAt: .now), .blocked)
    }

    func testHandoffNeedsConsentWhenOnButNeverAgreed() {
        XCTAssertEqual(PulseGate.handoff(pulseEnabled: true, aiConsentAt: nil), .needsConsent)
    }

    func testHandoffAllowedWhenOnAndConsented() {
        XCTAssertEqual(PulseGate.handoff(pulseEnabled: true, aiConsentAt: .now), .allowed)
    }

    func testIsActiveMatchesAllowedHandoffOnly() {
        XCTAssertTrue(PulseGate.isActive(pulseEnabled: true, aiConsentAt: .now))
        XCTAssertFalse(PulseGate.isActive(pulseEnabled: true, aiConsentAt: nil))
        XCTAssertFalse(PulseGate.isActive(pulseEnabled: false, aiConsentAt: .now))
        XCTAssertFalse(PulseGate.isActive(pulseEnabled: false, aiConsentAt: nil))
    }

    func testTabVisibilityFollowsPulseEnabledOnly() {
        // Not yet consented still shows the tab — that's what makes the consent sheet reachable.
        XCTAssertTrue(PulseGate.showsPulseTab(pulseEnabled: true))
        XCTAssertFalse(PulseGate.showsPulseTab(pulseEnabled: false))
    }

    func testTodayStripFollowsPulseOnTodayOnly() {
        XCTAssertTrue(PulseGate.showsPulseStripOnToday(pulseOnToday: true))
        XCTAssertFalse(PulseGate.showsPulseStripOnToday(pulseOnToday: false))
    }
}

final class SmartNotificationEngineTests: XCTestCase {
    private let userId = UUID()
    private let foodId = UUID()

    private func date(daysAgo: Int, hour: Int) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    private func log(daysAgo: Int, hour: Int = 8, meal: Meal = .breakfast) -> FoodLog {
        let loggedAt = date(daysAgo: daysAgo, hour: hour)
        return FoodLog(
            id: UUID(), userId: userId, loggedAt: loggedAt,
            logDate: loggedAt.isoDateString, meal: meal, foodItemId: foodId,
            quantity: 1, caloriesSnapshot: 250, proteinGSnapshot: 25,
            carbsGSnapshot: 20, fatGSnapshot: 6, fiberGSnapshot: 3,
            foodItems: nil
        )
    }

    func testRepeatedMealRequiresThreeMatchingDaysAndNoMealToday() {
        let now = date(daysAgo: 0, hour: 8)
        let history = [log(daysAgo: 1), log(daysAgo: 2), log(daysAgo: 3)]
        XCTAssertNotNil(RepeatedMealDetector.detect(history: history, todayLogs: [], now: now))
        XCTAssertNil(RepeatedMealDetector.detect(history: Array(history.prefix(2)), todayLogs: [], now: now))
        XCTAssertNil(RepeatedMealDetector.detect(history: history, todayLogs: [log(daysAgo: 0)], now: now))
    }

    func testWorkoutRecoveryOutranksOtherCandidates() {
        let now = date(daysAgo: 0, hour: 18)
        let recovery = RecoveryOpportunity(
            workoutName: "Strength", durationMinutes: 40,
            proteinGap: 30, waterGapMl: 500,
            finishedAt: now.addingTimeInterval(-20 * 60)
        )
        let result = SmartNotificationEngine.bestOpportunity(
            recovery: recovery, proteinGap: 30, calorieRoom: 500,
            rescueOptions: [], repeatedMeal: nil, now: now
        )
        XCTAssertEqual(result?.kind, .workoutRecovery)
        XCTAssertEqual(result?.priority, 3)
    }

    func testProteinCloseoutNeedsARealOneTapOption() {
        let now = date(daysAgo: 0, hour: 18)
        let favorite = FavoriteQuickAdd(
            foodItemId: foodId, name: "Usual shake", brand: nil,
            servingDesc: "1 shake", quantity: 1,
            caloriesSnapshot: 180, proteinGSnapshot: 30,
            carbsGSnapshot: 8, fatGSnapshot: 3, fiberGSnapshot: 1
        )
        let option = ProteinRescuePlanner.options(
            favorites: [favorite], proteinGap: 28, calorieRoom: 400
        )
        XCTAssertEqual(SmartNotificationEngine.bestOpportunity(
            recovery: nil, proteinGap: 28, calorieRoom: 400,
            rescueOptions: option, repeatedMeal: nil, now: now
        )?.kind, .proteinCloseout)
        XCTAssertNil(SmartNotificationEngine.bestOpportunity(
            recovery: nil, proteinGap: 28, calorieRoom: 400,
            rescueOptions: [], repeatedMeal: nil, now: now
        ))
    }

    func testQuietHoursSuppressEverything() {
        let late = date(daysAgo: 0, hour: 22)
        let recovery = RecoveryOpportunity(
            workoutName: "Walk", durationMinutes: 30,
            proteinGap: 20, waterGapMl: 300, finishedAt: late
        )
        XCTAssertNil(SmartNotificationEngine.bestOpportunity(
            recovery: recovery, proteinGap: 20, calorieRoom: 400,
            rescueOptions: [], repeatedMeal: nil, now: late
        ))
    }

    func testCustomQuietHoursCanAllowLaterOpportunity() {
        let late = date(daysAgo: 0, hour: 22)
        let recovery = RecoveryOpportunity(
            workoutName: "Walk", durationMinutes: 30,
            proteinGap: 20, waterGapMl: 300, finishedAt: late
        )
        XCTAssertEqual(SmartNotificationEngine.bestOpportunity(
            recovery: recovery, proteinGap: 20, calorieRoom: 400,
            rescueOptions: [], repeatedMeal: nil,
            quietStartHour: 23, quietEndHour: 6, now: late
        )?.kind, .workoutRecovery)
    }
}

final class SmartNotificationHistoryStoreTests: XCTestCase {
    func testHistoryUpsertsAndPersistsFeedback() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SmartNotificationHistoryStoreTests"))
        defaults.removePersistentDomain(forName: "SmartNotificationHistoryStoreTests")
        let entry = SmartNotificationHistoryEntry(
            id: "smart-test", kind: .proteinCloseout,
            title: "Protein", body: "20g to go", rationale: "Within reach",
            scheduledAt: .now, fireDate: .now, feedback: nil
        )
        SmartNotificationHistoryStore.upsert(entry, defaults: defaults)
        SmartNotificationHistoryStore.setFeedback(.helpful, for: entry.id, defaults: defaults)
        XCTAssertEqual(SmartNotificationHistoryStore.load(defaults: defaults).first?.feedback, .helpful)
        SmartNotificationHistoryStore.setStatus(.opened, for: entry.id, defaults: defaults)
        XCTAssertEqual(SmartNotificationHistoryStore.load(defaults: defaults).first?.status, .opened)
        SmartNotificationHistoryStore.remove(ids: [entry.id], defaults: defaults)
        XCTAssertTrue(SmartNotificationHistoryStore.load(defaults: defaults).isEmpty)
    }

    func testNegativeFeedbackCanExplicitlyDisableItsOpportunityKind() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SmartNotificationFeedbackTests"))
        defaults.removePersistentDomain(forName: "SmartNotificationFeedbackTests")
        SmartNotificationPreferences.setEnabled(false, for: .proteinCloseout, defaults: defaults)
        XCTAssertFalse(SmartNotificationPreferences.load(defaults: defaults).proteinCloseout)
        XCTAssertTrue(SmartNotificationPreferences.load(defaults: defaults).workoutRecovery)
    }
}

// MARK: - Trustworthy user-facing state

final class TrustworthyStateTests: XCTestCase {
    func testOfflinePendingChangesSayTheyAreOnlyOnThisPhone() {
        let status = SyncEngine.statusMessage(
            isOnline: false,
            isSyncing: false,
            pendingCount: 2,
            failedStage: nil
        )

        XCTAssertEqual(status?.title, "Saved on this phone")
        XCTAssertEqual(status?.canRetry, false)
        XCTAssertTrue(status?.detail.contains("2 changes") == true)
    }

    func testFailedRefreshDoesNotClaimPendingDataWhenThereIsNone() {
        let status = SyncEngine.statusMessage(
            isOnline: true,
            isSyncing: false,
            pendingCount: 0,
            failedStage: .goalRefresh
        )

        XCTAssertEqual(status?.title, "Couldn't refresh")
        XCTAssertEqual(status?.canRetry, true)
        XCTAssertTrue(status?.detail.contains("goal refresh") == true)
    }

    func testHealthySyncStateStaysOutOfTheWay() {
        XCTAssertNil(SyncEngine.statusMessage(
            isOnline: true,
            isSyncing: false,
            pendingCount: 0,
            failedStage: nil
        ))
    }

    func testAutomaticCoachMessagesCarryHistoricalContext() {
        let message = CoachMessage(
            id: UUID(),
            userId: UUID(),
            role: "assistant",
            content: "A saved check-in",
            messageType: "checkin",
            createdAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(message.isAutomatic)
        XCTAssertTrue(message.automaticContextLabel?.hasPrefix("Check-in ·") == true)
    }

    func testChatMessagesDoNotGainAutomaticContextLabel() {
        let message = CoachMessage(
            id: UUID(),
            userId: UUID(),
            role: "assistant",
            content: "A live reply",
            messageType: "chat",
            createdAt: Date()
        )

        XCTAssertNil(message.automaticContextLabel)
    }

    func testPasswordRecoveryRequiresEightMatchingCharacters() {
        XCTAssertNotNil(PasswordRecoveryViewModel.passwordValidationError(
            password: "short",
            confirmation: "short"
        ))
        XCTAssertNotNil(PasswordRecoveryViewModel.passwordValidationError(
            password: "long-enough",
            confirmation: "different"
        ))
        XCTAssertNil(PasswordRecoveryViewModel.passwordValidationError(
            password: "long-enough",
            confirmation: "long-enough"
        ))
    }
}

// MARK: - Pulse suggestion pills

final class CoachSuggestionTests: XCTestCase {
    func testEmptyDayOffersPlanningInsteadOfPretendingThereIsProgress() {
        let suggestions = CoachSuggestionBuilder.suggestions(
            hasFoodLogs: false,
            totalProteinG: 0,
            proteinGoalG: 120,
            hasWorkout: false,
            hour: 9
        )

        XCTAssertEqual(suggestions, [
            "Help me plan today",
            "Give me an easy protein breakfast",
            "Review my goals",
        ])
    }

    func testProteinGapGetsSpecificNextMoves() {
        let suggestions = CoachSuggestionBuilder.suggestions(
            hasFoodLogs: true,
            totalProteinG: 55,
            proteinGoalG: 120,
            hasWorkout: false,
            hour: 18
        )

        XCTAssertEqual(suggestions, [
            "Help me close my protein gap",
            "Give me a dinner idea",
            "Review my week",
        ])
    }

    func testWorkoutMakesRecoveryTheFirstSuggestion() {
        let suggestions = CoachSuggestionBuilder.suggestions(
            hasFoodLogs: true,
            totalProteinG: 70,
            proteinGoalG: 120,
            hasWorkout: true,
            hour: 13
        )

        XCTAssertEqual(suggestions.first, "Plan my recovery meal")
        XCTAssertEqual(suggestions.count, 3)
    }

    func testSelectedSuggestionRotatesOutAfterImmediateSend() {
        let suggestions = CoachSuggestionBuilder.suggestions(
            hasFoodLogs: true,
            totalProteinG: 55,
            proteinGoalG: 120,
            hasWorkout: false,
            hour: 18,
            excluding: "Help me close my protein gap"
        )

        XCTAssertFalse(suggestions.contains("Help me close my protein gap"))
        XCTAssertEqual(suggestions.count, 3)
    }

    func testSuggestionsAreCommandsNotEngagementQuestions() {
        let suggestions = CoachSuggestionBuilder.suggestions(
            hasFoodLogs: true,
            totalProteinG: 120,
            proteinGoalG: 120,
            hasWorkout: false,
            hour: 18
        )

        XCTAssertTrue(suggestions.allSatisfy { !$0.hasSuffix("?") })
    }

    // MARK: - Pulse start screen tiles

    private func pacificCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func pacificDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    func testProteinGapOver15gShowsEveningDinnerPrompt() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 18, calendar: calendar) // Tuesday evening

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 50,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(
                kind: .proteinGap,
                eyebrow: "70g to go",
                prompt: "Give me an easy dinner to close my protein"
            ),
            PulseStartSuggestion(kind: .meal, eyebrow: "Dinner", prompt: "Give me a dinner idea"),
        ])
    }

    func testProteinGapOver15gShowsMorningBreakfastPrompt() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 10, day: 1, hour: 9, calendar: calendar) // Thursday morning

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 20,
            proteinGoalG: 100,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(
                kind: .proteinGap,
                eyebrow: "80g to go",
                prompt: "Give me an easy breakfast to close my protein"
            ),
            PulseStartSuggestion(kind: .meal, eyebrow: "Breakfast", prompt: "Give me an easy protein breakfast"),
        ])
    }

    func testProteinGapAtOrUnder15gShowsNoProteinTile() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar)

        // 10g gap: comfortably under the threshold.
        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 110,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(kind: .meal, eyebrow: "Lunch", prompt: "Give me a protein-forward lunch"),
        ])

        // 15g gap exactly: the threshold is exclusive, so this still shows no protein tile.
        let atThreshold = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 105,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(atThreshold.contains { $0.kind == .proteinGap })
    }

    func testNilProteinGoalShowsNoProteinTile() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 10,
            proteinGoalG: nil,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(kind: .meal, eyebrow: "Lunch", prompt: "Give me a protein-forward lunch"),
        ])
    }

    func testShotDayZeroEyebrowAndPrompt() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 110,
            proteinGoalG: 120,
            cycleDay: 0,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(kind: .shotCycle, eyebrow: "Shot day", prompt: "Help me plan around today's shot"),
            PulseStartSuggestion(kind: .meal, eyebrow: "Lunch", prompt: "Give me a protein-forward lunch"),
        ])
    }

    func testShotCycleDayTwoEyebrowAndNotHungryPrompt() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 110,
            proteinGoalG: 120,
            cycleDay: 2,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(
                kind: .shotCycle,
                eyebrow: "Shot day 2",
                prompt: "Help me get protein in when I'm not hungry"
            ),
            PulseStartSuggestion(kind: .meal, eyebrow: "Lunch", prompt: "Give me a protein-forward lunch"),
        ])
    }

    func testShotCycleLaterWeekEyebrowAndPrompt() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 110,
            proteinGoalG: 120,
            cycleDay: 5,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(
                kind: .shotCycle,
                eyebrow: "Shot day 5",
                prompt: "Make the most of my appetite this week"
            ),
            PulseStartSuggestion(kind: .meal, eyebrow: "Lunch", prompt: "Give me a protein-forward lunch"),
        ])
    }

    func testNilCycleDayShowsNoShotTile() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar) // Tuesday, midday

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 30,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: true,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(
                kind: .proteinGap,
                eyebrow: "90g to go",
                prompt: "Give me an easy lunch to close my protein"
            ),
            PulseStartSuggestion(kind: .mondayRecap, eyebrow: "It's Tuesday", prompt: "Monday Recap"),
        ])
        XCTAssertFalse(suggestions.contains { $0.kind == .shotCycle })
    }

    func testRecapDueShowsMondayRecapTileWithWeekdayEyebrow() {
        let calendar = pacificCalendar()
        // Midday so the weekday the recap eyebrow reads (in the device's time zone) matches
        // this Pacific-built date regardless of which US time zone the test runs in.
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 110,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: true,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(kind: .mondayRecap, eyebrow: "It's Tuesday", prompt: "Monday Recap"),
            PulseStartSuggestion(kind: .meal, eyebrow: "Lunch", prompt: "Give me a protein-forward lunch"),
        ])
    }

    func testRecapNotDueShowsNoRecapTile() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 18, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 50,
            proteinGoalG: 120,
            cycleDay: 2,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(
                kind: .proteinGap,
                eyebrow: "70g to go",
                prompt: "Give me an easy dinner to close my protein"
            ),
            PulseStartSuggestion(
                kind: .shotCycle,
                eyebrow: "Shot day 2",
                prompt: "Help me get protein in when I'm not hungry"
            ),
        ])
        XCTAssertFalse(suggestions.contains { $0.kind == .mondayRecap })
    }

    func testFewerThanTwoTilesArePaddedWithMealFallback() {
        let calendar = pacificCalendar()
        // No protein gap, no shot cycle, no recap: nothing but the meal fallback.
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 20, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 110,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(kind: .meal, eyebrow: "Dinner", prompt: "Give me a dinner idea"),
        ])
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertLessThanOrEqual(suggestions.count, 3)
    }

    func testAllThreeSignalsProduceOrderedGridCappedAtThree() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 30,
            proteinGoalG: 120,
            cycleDay: 2,
            recapDue: true,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(
                kind: .proteinGap,
                eyebrow: "90g to go",
                prompt: "Give me an easy lunch to close my protein"
            ),
            PulseStartSuggestion(
                kind: .shotCycle,
                eyebrow: "Shot day 2",
                prompt: "Help me get protein in when I'm not hungry"
            ),
            PulseStartSuggestion(kind: .mondayRecap, eyebrow: "It's Tuesday", prompt: "Monday Recap"),
        ])
        XCTAssertEqual(suggestions.count, 3)
    }

    func testStartSuggestionsAreCommandsNotEngagementQuestions() {
        let calendar = pacificCalendar()
        var allPrompts: [String] = []

        // Every meal bucket, for both the protein-gap prompt and the meal-fallback prompt.
        for hour in [9, 12, 16, 20] {
            let now = pacificDate(year: 2026, month: 9, day: 29, hour: hour, calendar: calendar)
            let suggestions = CoachSuggestionBuilder.startSuggestions(
                totalProteinG: 10,
                proteinGoalG: 120,
                cycleDay: nil,
                recapDue: false,
                now: now,
                calendar: calendar
            )
            allPrompts.append(contentsOf: suggestions.map(\.prompt))
        }

        // Every shot-cycle prompt branch.
        for cycleDay in [0, 2, 5] {
            let now = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar)
            let suggestions = CoachSuggestionBuilder.startSuggestions(
                totalProteinG: 110,
                proteinGoalG: 120,
                cycleDay: cycleDay,
                recapDue: false,
                now: now,
                calendar: calendar
            )
            allPrompts.append(contentsOf: suggestions.map(\.prompt))
        }

        // The Monday Recap prompt.
        let recapNow = pacificDate(year: 2026, month: 9, day: 29, hour: 12, calendar: calendar)
        let recapSuggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 110,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: true,
            now: recapNow,
            calendar: calendar
        )
        allPrompts.append(contentsOf: recapSuggestions.map(\.prompt))

        XCTAssertFalse(allPrompts.isEmpty)
        XCTAssertTrue(allPrompts.allSatisfy { !$0.hasSuffix("?") })
    }

    func testTopicsExposeTheFourFixedChipsInOrder() {
        XCTAssertEqual(CoachSuggestionBuilder.topics.map(\.label), [
            "Meal ideas",
            "How I'm trending",
            "Eating out",
            "Workouts & recovery",
        ])
    }

    // MARK: - Experiment check-in tile

    func testExperimentCheckInTileLeadsWhenDueToday() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 9, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 110,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar,
            experimentCheckIn: ExperimentCheckInPrompt(dayIndex: 4, totalDays: 14, hasCheckedInToday: false)
        )

        XCTAssertEqual(suggestions.first, PulseStartSuggestion(
            kind: .experimentCheckIn,
            eyebrow: "Experiment · day 4 of 14",
            prompt: "Log today's check-in"
        ))
    }

    func testExperimentCheckInTileHidesOnceLoggedToday() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 9, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 110,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar,
            experimentCheckIn: ExperimentCheckInPrompt(dayIndex: 4, totalDays: 14, hasCheckedInToday: true)
        )

        XCTAssertFalse(suggestions.contains { $0.kind == .experimentCheckIn })
    }

    func testExperimentCheckInWithoutATotalStillShowsADay() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 9, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 0,
            proteinGoalG: nil,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar,
            experimentCheckIn: ExperimentCheckInPrompt(dayIndex: 2, totalDays: nil, hasCheckedInToday: false)
        )

        XCTAssertEqual(suggestions.first?.eyebrow, "Experiment · day 2")
    }

    // Every existing call site omits `experimentCheckIn`; the new parameter must default away
    // to nothing so those calls and their expected results are unaffected.
    func testOmittingExperimentCheckInLeavesExistingBehaviorUnchanged() {
        let calendar = pacificCalendar()
        let now = pacificDate(year: 2026, month: 9, day: 29, hour: 18, calendar: calendar)

        let suggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: 50,
            proteinGoalG: 120,
            cycleDay: nil,
            recapDue: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(suggestions, [
            PulseStartSuggestion(
                kind: .proteinGap,
                eyebrow: "70g to go",
                prompt: "Give me an easy dinner to close my protein"
            ),
            PulseStartSuggestion(kind: .meal, eyebrow: "Dinner", prompt: "Give me a dinner idea"),
        ])
    }
}

// MARK: - Structured Pulse replies (docs/daylight-redesign.md)
//
// The wire contract lives in supabase/functions/_shared/pulse-context.ts (`pulseReplySchema`,
// `pulseRecapSchema`); these cover the app's side of it: a missing `payload` key decodes to nil
// (older rows, and any environment where the payload migration hasn't run yet), a nil payload
// encodes with no key at all (so a save against that same environment looks unchanged), and the
// pure presentation logic that decides which food cards and chips actually show.
final class PulseStructuredReplyTests: XCTestCase {

    // MARK: CoachMessagePayload round-trip

    func testCoachMessagePayloadRoundTripsThroughJSON() throws {
        let payload = CoachMessagePayload(
            foods: [.init(name: "Protein shake", why: "30g, no cooking")],
            followUps: ["Something warm?", "Plan tomorrow"],
            recap: .init(story: "s", wentWell: "w", pattern: "p", focus: "f")
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CoachMessagePayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    // MARK: CoachMessage: a missing `payload` key decodes to nil

    func testCoachMessageDecodesWithoutPayloadKeyAsNil() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "user_id": "\(UUID().uuidString)",
          "role": "assistant",
          "content": "Hi",
          "message_type": "chat",
          "created_at": 0
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let message = try decoder.decode(CoachMessage.self, from: json)
        XCTAssertNil(message.payload)
    }

    func testCoachMessageDecodesAPresentPayload() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "user_id": "\(UUID().uuidString)",
          "role": "assistant",
          "content": "Hi",
          "message_type": "chat",
          "created_at": 0,
          "payload": { "followUps": ["Plan tomorrow"] }
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let message = try decoder.decode(CoachMessage.self, from: json)
        XCTAssertEqual(message.payload?.followUps, ["Plan tomorrow"])
        XCTAssertNil(message.payload?.foods)
        XCTAssertNil(message.payload?.recap)
    }

    // MARK: NewCoachMessage: nil payload sends no key, a present one encodes fully

    func testNewCoachMessageEncodesNilPayloadWithNoKeyAtAll() throws {
        let message = NewCoachMessage(userId: UUID(), role: "assistant", content: "Hi", messageType: "chat", payload: nil)
        let data = try JSONEncoder().encode(message)
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(obj["payload"], "a nil payload must not appear as a JSON null either")
        XCTAssertFalse(obj.keys.contains("payload"))
    }

    func testNewCoachMessageEncodesAPresentPayloadAndOmitsItsNilFields() throws {
        let payload = CoachMessagePayload(
            foods: [.init(name: "Greek yogurt", why: "20g")],
            followUps: nil,
            recap: nil
        )
        let message = NewCoachMessage(userId: UUID(), role: "assistant", content: "Hi", messageType: "chat", payload: payload)
        let data = try JSONEncoder().encode(message)
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let payloadObj = try XCTUnwrap(obj["payload"] as? [String: Any])
        let foods = try XCTUnwrap(payloadObj["foods"] as? [[String: Any]])
        XCTAssertEqual(foods.first?["name"] as? String, "Greek yogurt")
        XCTAssertNil(payloadObj["followUps"])
        XCTAssertNil(payloadObj["recap"])
    }

    // MARK: PulseFoodResolver

    private func foodLog(name: String, minutesAgo: Double, now: Date) -> FoodLog {
        FoodLog(
            id: UUID(), userId: UUID(), loggedAt: now.addingTimeInterval(-minutesAgo * 60),
            logDate: now.isoDateString, meal: .snack, foodItemId: UUID(), quantity: 1,
            caloriesSnapshot: 100, proteinGSnapshot: 20, carbsGSnapshot: 5, fatGSnapshot: 2, fiberGSnapshot: 1,
            foodItems: .init(name: name, brand: nil, servingDesc: nil)
        )
    }

    func testResolveMatchesCaseInsensitivelyAndTrimmed() {
        let now = Date.now
        let log = foodLog(name: "Greek Yogurt", minutesAgo: 10, now: now)
        XCTAssertEqual(PulseFoodResolver.resolve("  greek yogurt  ", in: [log])?.id, log.id)
    }

    func testResolveReturnsNilWithNoMatch() {
        let now = Date.now
        let log = foodLog(name: "Greek Yogurt", minutesAgo: 10, now: now)
        XCTAssertNil(PulseFoodResolver.resolve("Protein shake", in: [log]))
    }

    func testResolveReturnsTheMostRecentLogWhenTheNameRepeats() {
        let now = Date.now
        let older = foodLog(name: "Greek yogurt", minutesAgo: 120, now: now)
        let newer = foodLog(name: "Greek yogurt", minutesAgo: 5, now: now)
        XCTAssertEqual(PulseFoodResolver.resolve("Greek yogurt", in: [older, newer])?.id, newer.id)
    }

    func testResolveReturnsNilForBlankName() {
        let now = Date.now
        let log = foodLog(name: "Greek yogurt", minutesAgo: 5, now: now)
        XCTAssertNil(PulseFoodResolver.resolve("   ", in: [log]))
    }

    // MARK: PulseChipSource

    private func message(role: String, followUps: [String]?) -> CoachMessage {
        CoachMessage(
            id: UUID(), userId: UUID(), role: role, content: "x", messageType: "chat", createdAt: .now,
            payload: followUps.map { CoachMessagePayload(foods: nil, followUps: $0, recap: nil) }
        )
    }

    func testChipsUsesFollowUpsFromTheNewestAssistantMessage() {
        let assistant = message(role: "assistant", followUps: ["A", "B"])
        XCTAssertEqual(PulseChipSource.chips(latestMessage: assistant, fallback: ["Fallback"]), ["A", "B"])
    }

    func testChipsFallBackWhenTheNewestMessageIsFromTheUser() {
        let user = message(role: "user", followUps: ["A"])
        XCTAssertEqual(PulseChipSource.chips(latestMessage: user, fallback: ["Fallback"]), ["Fallback"])
    }

    func testChipsFallBackWhenFollowUpsAreMissingOrEmpty() {
        XCTAssertEqual(
            PulseChipSource.chips(latestMessage: message(role: "assistant", followUps: nil), fallback: ["Fallback"]),
            ["Fallback"]
        )
        XCTAssertEqual(
            PulseChipSource.chips(latestMessage: message(role: "assistant", followUps: []), fallback: ["Fallback"]),
            ["Fallback"]
        )
    }

    func testChipsFallBackWithNoMessagesYet() {
        XCTAssertEqual(PulseChipSource.chips(latestMessage: nil, fallback: ["Fallback"]), ["Fallback"])
    }
}

// MARK: - What Pulse knows about you (docs/daylight-redesign.md, step 8)

final class PulseProfileTests: XCTestCase {
    func testQueuedPreferencesMergeWithoutDuplicatesOrLosingAllergies() {
        let server = PulsePreferences(allergies: ["Peanuts"], allergyNote: "", eatingPatterns: [.halal], loves: ["Eggs"], avoids: [])
        let queued = PulsePreferences(allergies: ["peanuts", "Shellfish"], allergyNote: "Mild", eatingPatterns: [.dairyFree], loves: [], avoids: ["Olives"])
        let merged = server.merged(with: queued)
        XCTAssertEqual(merged.allergies, ["Peanuts", "Shellfish"])
        XCTAssertEqual(merged.allergyNote, "Mild")
        XCTAssertEqual(merged.eatingPatterns, [.halal, .dairyFree])
        XCTAssertEqual(merged.avoids, ["Olives"])
    }


    // MARK: PulsePreferences.normalized

    func testNormalizedTrimsDedupesCaseInsensitivelyAndCapsLovesAndAvoids() {
        var prefs = PulsePreferences()
        prefs.loves = Array(repeating: " Yogurt ", count: 5) + (1...35).map { "Food \($0)" }
        prefs.avoids = ["  Cilantro  ", "cilantro", "CILANTRO"]
        let normalized = prefs.normalized

        // First spelling wins, case-insensitive duplicates collapse, whitespace is trimmed.
        XCTAssertEqual(normalized.avoids, ["Cilantro"])
        XCTAssertEqual(normalized.loves.first, "Yogurt")
        // 1 unique "Yogurt" + 35 unique "Food N" = 36 candidates, capped at 30.
        XCTAssertEqual(normalized.loves.count, 30)
    }

    func testNormalizedCapsAllergiesAtTwentyAndTruncatesLongItemsTo60Characters() {
        var prefs = PulsePreferences()
        prefs.allergies = (1...25).map { "Allergen \($0)" }
        prefs.avoids = [String(repeating: "x", count: 100)]
        let normalized = prefs.normalized

        XCTAssertEqual(normalized.allergies.count, 20)
        XCTAssertEqual(normalized.avoids.first?.count, 60)
    }

    func testNormalizedTruncatesTheAllergyNoteTo300Characters() {
        var prefs = PulsePreferences()
        prefs.allergyNote = "  " + String(repeating: "a", count: 400) + "  "
        XCTAssertEqual(prefs.normalized.allergyNote.count, 300)
    }

    func testNormalizedDropsBlankItemsAfterTrimming() {
        var prefs = PulsePreferences()
        prefs.loves = ["   ", "", "Mango"]
        XCTAssertEqual(prefs.normalized.loves, ["Mango"])
    }

    // MARK: PulsePreferences.isEmpty

    func testIsEmptyIsTrueOnlyWithNothingSet() {
        XCTAssertTrue(PulsePreferences().isEmpty)
        var prefs = PulsePreferences()
        prefs.avoids = ["Cilantro"]
        XCTAssertFalse(prefs.isEmpty)
    }

    // MARK: AboutYouContext mapping

    func testAboutYouContextMapsEveryFieldAndSortsEatingPatterns() {
        let prefs = PulsePreferences(
            allergies: ["Peanuts"],
            allergyNote: "Carries an EpiPen",
            eatingPatterns: [.vegan, .dairyFree],
            loves: ["Greek yogurt"],
            avoids: ["Cilantro"]
        )
        let context = AboutYouContext(prefs)

        XCTAssertEqual(context.allergies, ["Peanuts"])
        XCTAssertEqual(context.allergyNote, "Carries an EpiPen")
        XCTAssertEqual(context.eatingPatterns, ["dairy_free", "vegan"], "sorted, so the prompt is stable across runs")
        XCTAssertEqual(context.loves, ["Greek yogurt"])
        XCTAssertEqual(context.avoids, ["Cilantro"])
    }

    // MARK: PulseRememberSuggestion.label

    func testRememberSuggestionLabels() {
        XCTAssertEqual(PulseRememberSuggestion(kind: .allergy, value: "Peanuts").label, "Allergy: Peanuts")
        XCTAssertEqual(PulseRememberSuggestion(kind: .avoid, value: "Cilantro").label, "Avoid: Cilantro")
        XCTAssertEqual(PulseRememberSuggestion(kind: .love, value: "Mango").label, "Loves: Mango")
    }

    // MARK: CoachMessagePayload.remember — decode/encode

    func testCoachMessagePayloadRoundTripsRememberThroughJSON() throws {
        let payload = CoachMessagePayload(
            remember: [.init(kind: .avoid, value: "Cilantro"), .init(kind: .allergy, value: "Peanuts")]
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CoachMessagePayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testCoachMessageDecodesRememberFromAPresentPayload() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "user_id": "\(UUID().uuidString)",
          "role": "assistant",
          "content": "Noted.",
          "message_type": "chat",
          "created_at": 0,
          "payload": { "remember": [{"kind": "avoid", "value": "Cilantro"}] }
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let message = try decoder.decode(CoachMessage.self, from: json)
        XCTAssertEqual(message.payload?.remember, [.init(kind: .avoid, value: "Cilantro")])
    }

    // A row saved before `remember` existed (or any payload missing the key) must still decode,
    // with `remember` reading as nil rather than throwing.
    func testCoachMessageDecodesWithoutRememberKeyAsNil() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "user_id": "\(UUID().uuidString)",
          "role": "assistant",
          "content": "Hi",
          "message_type": "chat",
          "created_at": 0,
          "payload": { "followUps": ["Plan tomorrow"] }
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let message = try decoder.decode(CoachMessage.self, from: json)
        XCTAssertNil(message.payload?.remember)
    }

    // MARK: CoachViewModel — not re-offering what Pulse already knows

    @MainActor
    func testRememberCardsExcludesSuggestionsAlreadyInWhatPulseKnows() {
        let restore = PulseProfileStore.shared.preferences
        defer { PulseProfileStore.shared.setForPreview(preferences: restore) }
        PulseProfileStore.shared.setForPreview(preferences: PulsePreferences(avoids: ["Cilantro"]))

        let vm = CoachViewModel()
        let known = PulseRememberSuggestion(kind: .avoid, value: "cilantro") // case-insensitive match
        let new = PulseRememberSuggestion(kind: .love, value: "Mango")
        let message = CoachMessage(
            id: UUID(), userId: UUID(), role: "assistant", content: "Noted", messageType: "chat",
            createdAt: .now, payload: CoachMessagePayload(remember: [known, new])
        )

        XCTAssertEqual(vm.rememberCards(for: message), [new])
    }

    @MainActor
    func testDismissedRememberSuggestionStaysHiddenForThatMessage() {
        let restore = PulseProfileStore.shared.preferences
        defer { PulseProfileStore.shared.setForPreview(preferences: restore) }
        PulseProfileStore.shared.setForPreview(preferences: PulsePreferences())

        let vm = CoachViewModel()
        let suggestion = PulseRememberSuggestion(kind: .avoid, value: "Cilantro")
        let message = CoachMessage(
            id: UUID(), userId: UUID(), role: "assistant", content: "Noted", messageType: "chat",
            createdAt: .now, payload: CoachMessagePayload(remember: [suggestion])
        )

        XCTAssertEqual(vm.rememberCards(for: message), [suggestion])
        vm.dismissRememberSuggestion(suggestion, in: message)
        XCTAssertTrue(vm.rememberCards(for: message).isEmpty)
    }
}

// MARK: - GLP-1 dose formatting

final class GLP1DoseFormattingTests: XCTestCase {

    // The regression: "%.2g" means two *significant digits*, so Mounjaro's real
    // 12.5 mg titration step rendered as "12 mg" in the dose picker and chart axis.
    func testHalfMilligramDoseIsNotTruncated() {
        XCTAssertEqual(String(format: "%.2g", 12.5), "12", "precondition: this is the old, wrong behavior")
        XCTAssertNotEqual((12.5).glp1DoseString, "12")
    }

    // Locale-independent correctness check: every dose the app offers must survive
    // a render → parse round trip.
    func testEveryAvailableDoseRoundTrips() throws {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current

        for medication in GLP1Medication.allCases {
            for dose in medication.availableDoses {
                let rendered = dose.glp1DoseString
                let parsed = try XCTUnwrap(
                    formatter.number(from: rendered)?.doubleValue,
                    "\(medication.rawValue): '\(rendered)' is not parseable as a number"
                )
                XCTAssertEqual(
                    parsed, dose, accuracy: 0.0001,
                    "\(medication.rawValue) dose \(dose) mg rendered as '\(rendered)'"
                )
            }
        }
    }

    func testWholeDosesDropTheFraction() {
        XCTAssertEqual((10.0).glp1DoseString, "10")
        XCTAssertEqual((5.0).glp1DoseString, "5")
    }
}

// MARK: - Barcode normalization

final class BarcodeNormalizerTests: XCTestCase {

    // The scanner accepts .upce but forwarded the compressed code verbatim; FatSecret's
    // find_id_for_barcode wants a GTIN-13, so every small-package product came back
    // "Barcode Not Found" even when FatSecret had it.
    func testExpandsUPCEToUPCA() {
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("04252614"), "042100005264")
    }

    func testUPCEBecomesThirteenDigits() {
        XCTAssertEqual(BarcodeNormalizer.gtin13(value: "04252614", symbology: .upce), "0042100005264")
    }

    // Each trailing digit selects a different zero-reinsertion rule.
    func testEveryUPCECompressionRule() {
        // last digit 0-2: M1 M2 [last] 0000 M3 M4 M5
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("01278906")?.prefix(11), "01200000789")
        // last digit 3: M1 M2 M3 00000 M4 M5
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("01234531")?.prefix(11), "01230000045")
        // last digit 4: M1 M2 M3 M4 00000 M5
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("01234541")?.prefix(11), "01234000005")
        // last digit 5-9: M1..M5 0000 [last]
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("05673894")?.prefix(11), "05673800009")
    }

    // EAN-8 and UPC-E are both eight digits — only the symbology distinguishes them, so an
    // EAN-8 must be zero-padded, never expanded as if it were a compressed UPC-A.
    func testEAN8IsPaddedNotExpanded() {
        XCTAssertEqual(BarcodeNormalizer.gtin13(value: "04252614", symbology: .ean8), "0000004252614")
    }

    func testEAN13PassesThroughAndUPCAIsPadded() {
        XCTAssertEqual(BarcodeNormalizer.gtin13(value: "5000112637922", symbology: .ean13), "5000112637922")
        XCTAssertEqual(BarcodeNormalizer.gtin13(value: "042100005264", symbology: .ean13), "0042100005264")
    }

    func testRejectsGarbage() {
        XCTAssertNil(BarcodeNormalizer.gtin13(value: "abc", symbology: .other))
        XCTAssertNil(BarcodeNormalizer.gtin13(value: "12345678901234", symbology: .other), "longer than GTIN-13")
        XCTAssertNil(BarcodeNormalizer.expandUPCE("12345"), "too short for UPC-E")
        XCTAssertNil(BarcodeNormalizer.expandUPCE("92345678"), "number system must be 0 or 1")
    }

    func testCheckDigit() {
        XCTAssertEqual(BarcodeNormalizer.upcCheckDigit("04210000526"), "4")
    }
}

// MARK: - Date → ISO day string

final class ISODateStringTests: XCTestCase {

    private let newYork = TimeZone(identifier: "America/New_York")!
    private let tokyo   = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: iso)!
    }

    // The whole point: the day depends on the zone you ask in. The old cached
    // DateFormatter froze TimeZone.current at first use, so after a timezone change the
    // app kept writing log_date in the old zone while isToday had already moved.
    func testDayDependsOnTimeZone() {
        let instant = date("2024-03-16T03:30:00Z")   // Mar 15, 11:30pm EDT / Mar 16, 12:30pm JST
        XCTAssertEqual(instant.isoDateString(in: newYork), "2024-03-15")
        XCTAssertEqual(instant.isoDateString(in: tokyo),   "2024-03-16")
    }

    func testZeroPadsMonthAndDay() {
        XCTAssertEqual(date("2024-01-05T12:00:00Z").isoDateString(in: .gmt), "2024-01-05")
    }

    // Zero-padded ISO strings are compared lexicographically in LocalStore.fetchGoal and
    // pruneDeletedFoodLogs. That only holds if every component is fixed-width.
    func testLexicographicOrderingMatchesChronology() {
        let earlier = date("2024-09-30T12:00:00Z").isoDateString(in: .gmt)
        let later   = date("2024-10-01T12:00:00Z").isoDateString(in: .gmt)
        XCTAssertTrue(earlier < later)
        XCTAssertEqual(earlier, "2024-09-30")
        XCTAssertEqual(later,   "2024-10-01")
    }

    // Anything that parses a log_date must read it back in the zone it was written in. The
    // body-fat chart parsed it as UTC midnight and plotted a day earlier than the calories and
    // weight charts built from the same log.
    func testISODateStringRoundTripsInTheSameZone() throws {
        for zone in [newYork, tokyo, TimeZone.gmt] {
            let original = try XCTUnwrap(Date.fromISODateString("2026-07-06", in: zone))
            XCTAssertEqual(original.isoDateString(in: zone), "2026-07-06")
        }
    }

    func testParsingAsUTCWouldShiftTheDayWestOfUTC() throws {
        // The old code did `logDate + "T00:00:00Z"`.
        let asUTC = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-06T00:00:00Z"))
        XCTAssertEqual(asUTC.isoDateString(in: newYork), "2026-07-05", "this is the bug")

        let parsedLocally = try XCTUnwrap(Date.fromISODateString("2026-07-06", in: newYork))
        XCTAssertEqual(parsedLocally.isoDateString(in: newYork), "2026-07-06", "this is the fix")
    }

    func testRejectsMalformedDateStrings() {
        XCTAssertNil(Date.fromISODateString("not-a-date"))
        XCTAssertNil(Date.fromISODateString("2026-07"))
    }

    func testMidnightBoundaryBelongsToTheNewDay() {
        XCTAssertEqual(date("2024-03-15T04:00:00Z").isoDateString(in: newYork), "2024-03-15",
                       "00:00 EDT is still the 15th")
        XCTAssertEqual(date("2024-03-15T03:59:59Z").isoDateString(in: newYork), "2024-03-14",
                       "one second earlier is the 14th")
    }
}

// MARK: - Goal calculation

final class GoalCalculatorTests: XCTestCase {

    // Mifflin-St Jeor. These must not drift: the extraction out of OnboardingViewModel has to
    // be behaviour-preserving.
    func testMifflinStJeorMatchesTheFormula() {
        // 10(80) + 6.25(180) − 5(30) + 5 = 800 + 1125 − 150 + 5
        XCTAssertEqual(
            GoalCalculator.bmr(sex: .male, ageYears: 30, heightCm: 180, weightKg: 80),
            1780, accuracy: 0.001
        )
        // ...− 161
        XCTAssertEqual(
            GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 180, weightKg: 80),
            1614, accuracy: 0.001
        )
    }

    // `.other` is the average of the male and female formulas, as the original code computed it.
    func testOtherSexAveragesTheTwoFormulas() {
        let male   = GoalCalculator.bmr(sex: .male,   ageYears: 30, heightCm: 180, weightKg: 80)
        let female = GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 180, weightKg: 80)
        XCTAssertEqual(
            GoalCalculator.bmr(sex: .other, ageYears: 30, heightCm: 180, weightKg: 80),
            (male + female) / 2, accuracy: 0.001
        )
    }

    // An aggressive deficit must never recommend a starvation target.
    func testCalorieFloorClampsAggressiveDeficits() {
        let goals = GoalCalculator.goals(
            sex: .female, ageYears: 60, heightCm: 150, weightKg: 45,
            activity: .sedentary, weightGoal: .lose
        )
        XCTAssertEqual(goals.calories, GoalCalculator.calorieFloor)
        XCTAssertGreaterThan(goals.calories, 0, "never negative")
    }

    // Allocation order: protein anchored to weight (1.6 g/kg), fat 30% of calories,
    // carbs the remainder. Protein must NOT scale with calories — a deficit that deepens
    // may not shrink the protein target.
    func testProteinIsAnchoredToWeightNotCalories() {
        let goals = GoalCalculator.macros(calories: 2000, weightKg: 80)
        XCTAssertEqual(goals.proteinG, 128)   // 1.6 × 80
        XCTAssertEqual(goals.fatG,      67)   // 30% / 9, rounded
        XCTAssertEqual(goals.carbsG,   221)   // remainder
        XCTAssertEqual(goals.fiberG,    28)   // 14g per 1000 kcal
        XCTAssertEqual(goals.waterMlTarget, 2800)  // 35 ml/kg

        // The same body at a deeper deficit keeps the same protein target.
        XCTAssertEqual(GoalCalculator.macros(calories: 1600, weightKg: 80).proteinG, 128)
    }

    func testMacrosSumToTheCalorieGoal() {
        for calories in [1200.0, 1850, 2470, 3000] {
            let g = GoalCalculator.macros(calories: calories, weightKg: 90)
            let sum = g.proteinG * 4 + g.carbsG * 4 + g.fatG * 9
            XCTAssertEqual(sum, calories, accuracy: 6,
                           "independent rounding must not drift the displayed total")
        }
    }

    // The 35%-of-calories cap: the 1200-floor + high-body-weight corner can't prescribe a
    // plate that's half protein.
    func testProteinCapsAtThirtyFivePercentOfCalories() {
        let goals = GoalCalculator.macros(calories: 1200, weightKg: 130, heightCm: 160, sex: .male)
        XCTAssertEqual(goals.proteinG, 105)   // 1200 × 0.35 / 4, not 1.6 × anchor
    }

    // Above BMI 30 the anchor is adjusted body weight (Devine IBW + 25% of the excess),
    // so heavy users get reachable targets. At or below BMI 30, actual weight.
    func testProteinAnchorUsesAdjustedWeightAboveBMI30() {
        // 175 cm, 120 kg (BMI 39): IBW ≈ 70.5, adjusted ≈ 82.9 → 1.6 g/kg ≈ 133 g.
        let heavy = GoalCalculator.macros(calories: 2200, weightKg: 120, heightCm: 175, sex: .male)
        XCTAssertEqual(heavy.proteinG, 133)
        // 175 cm, 90 kg (BMI 29.4): no adjustment → 1.6 × 90 = 144 g.
        let under = GoalCalculator.macros(calories: 2200, weightKg: 90, heightCm: 175, sex: .male)
        XCTAssertEqual(under.proteinG, 144)
    }

    func testFiberAndWaterMinimums() {
        let goals = GoalCalculator.macros(calories: 1200, weightKg: 45)
        XCTAssertEqual(goals.fiberG, 25, "floor, not 16.8")
        XCTAssertEqual(goals.waterMlTarget, 2000, "floor, not 1575")
    }

    func testFiberAndWaterCaps() {
        let goals = GoalCalculator.macros(calories: 3000, weightKg: 150)
        XCTAssertEqual(goals.fiberG, 38, "capped, not 42")
        XCTAssertEqual(goals.waterMlTarget, 4000, "capped, not 5250")
    }

    // Katch-McArdle when body fat is known: 370 + 21.6 × lean mass. Junk readings fall
    // back to Mifflin rather than producing an absurd lean mass.
    func testKatchMcArdleWhenBodyFatKnown() {
        XCTAssertEqual(
            GoalCalculator.bmr(sex: .male, ageYears: 30, heightCm: 180, weightKg: 100, bodyFatPct: 30),
            370 + 21.6 * 70, accuracy: 0.001
        )
        // Sex drops out of Katch-McArdle entirely.
        XCTAssertEqual(
            GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 180, weightKg: 100, bodyFatPct: 30),
            GoalCalculator.bmr(sex: .male, ageYears: 30, heightCm: 180, weightKg: 100, bodyFatPct: 30)
        )
        // nil and out-of-range values use Mifflin.
        let mifflin = GoalCalculator.bmr(sex: .male, ageYears: 30, heightCm: 180, weightKg: 100)
        XCTAssertEqual(
            GoalCalculator.bmr(sex: .male, ageYears: 30, heightCm: 180, weightKg: 100, bodyFatPct: 75),
            mifflin, accuracy: 0.001, "junk body fat falls back"
        )
    }

    // The pure trigger behind Today's "update your targets?" card. Direction-agnostic.
    func testWeightDriftThreshold() {
        XCTAssertFalse(GoalCalculator.weightDriftExceeds(baselineKg: 100, recentAvgKg: 102.4))
        XCTAssertTrue(GoalCalculator.weightDriftExceeds(baselineKg: 100, recentAvgKg: 102.5))
        XCTAssertTrue(GoalCalculator.weightDriftExceeds(baselineKg: 100, recentAvgKg: 97.5),
                      "losing drifts too, not just gaining")
        XCTAssertFalse(GoalCalculator.weightDriftExceeds(baselineKg: 0, recentAvgKg: 90),
                       "no baseline, no prompt")
    }

    // Retargeting must preserve the user's current adjustment — the deficit they chose, or a
    // target they hand-tuned — rather than re-deriving from a WeightGoal profiles doesn't store.
    func testRetargetPreservesTheUsersDeficit() {
        // Living 500 kcal under maintenance; maintenance drops by 200 after weight loss.
        let goals = GoalCalculator.retargeted(
            currentCalories: 2000, oldTDEE: 2500, newTDEE: 2300, newWeightKg: 80
        )
        XCTAssertEqual(goals.calories, 1800, "the 500 kcal deficit follows the new TDEE")
    }

    func testRetargetPreservesAManualSurplus() {
        let goals = GoalCalculator.retargeted(
            currentCalories: 2750, oldTDEE: 2500, newTDEE: 2600, newWeightKg: 90
        )
        XCTAssertEqual(goals.calories, 2850, "the +250 surplus is kept")
    }

    func testRetargetRespectsTheFloor() {
        let goals = GoalCalculator.retargeted(
            currentCalories: 1300, oldTDEE: 1800, newTDEE: 1500, newWeightKg: 50
        )
        XCTAssertEqual(goals.calories, GoalCalculator.calorieFloor)
    }
}

// MARK: - Height unit conversion

final class HeightConversionTests: XCTestCase {

    private let imperial = UnitSystem.imperial

    // 172 cm is 67.7 inches. Truncating gave 67 → displayed 5'7" → saved back 170.18 cm.
    func testTotalInchesRoundsRatherThanTruncates() {
        XCTAssertEqual(UnitSystem.totalInches(fromCm: 172), 68)
        XCTAssertEqual(imperial.feetFrom(172), 5)
        XCTAssertEqual(imperial.inchesFrom(172), 8)
    }

    // Flooring the feet and separately rounding the remainder produced "5 ft 12 in".
    func testNeverProducesTwelveInches() {
        for cm in stride(from: 120.0, through: 220.0, by: 0.25) {
            let inches = imperial.inchesFrom(cm)
            XCTAssertTrue((0...11).contains(Int(inches)), "\(cm) cm produced \(inches) inches")
        }
        XCTAssertEqual(imperial.feetFrom(182), 6, "182 cm is 6 ft 0 in, not 5 ft 12 in")
        XCTAssertEqual(imperial.inchesFrom(182), 0)
    }

    func testFormatHeightRounds() {
        XCTAssertEqual(imperial.formatHeight(172), "5'8\"")
        XCTAssertEqual(imperial.formatHeight(170), "5'7\"")
    }

    // Opening Edit Stats and tapping Save without touching anything must not change height.
    // cm → ft/in → cm is lossy (whole inches only), so the conversion has to be skipped.
    func testUnchangedImperialHeightRoundTripsExactly() {
        for storedCm in [170.0, 172.0, 175.3, 182.0, 160.9] {
            let feet   = imperial.feetFrom(storedCm)
            let inches = imperial.inchesFrom(storedCm)
            let saved  = imperial.cmFrom(feet: feet, inches: inches, unchangedFrom: storedCm)
            XCTAssertEqual(saved, storedCm, "reopening and saving rewrote \(storedCm) cm")
        }
    }

    // A real edit still converts.
    func testEditedImperialHeightConverts() {
        let saved = imperial.cmFrom(feet: 6, inches: 0, unchangedFrom: 172)
        XCTAssertEqual(saved, 182.88, accuracy: 0.001)
    }
}

// MARK: - GLP-1 decoding

final class GLP1LogDecodingTests: XCTestCase {

    // site and next_due_at are nullable columns. Decoding them as non-optional threw a
    // DecodingError for the entire array on a single NULL row, blanking the GLP-1 card and
    // the titration chart — one bad row took out the whole feature.
    func testDecodesRowWithNullSiteAndNextDue() throws {
        let json = """
        [
          {"id":"\(UUID().uuidString)","user_id":"\(UUID().uuidString)",
           "injected_at":"2026-07-01T12:00:00Z","medication":"Mounjaro","dose_mg":12.5,
           "site":null,"next_due_at":null},
          {"id":"\(UUID().uuidString)","user_id":"\(UUID().uuidString)",
           "injected_at":"2026-07-08T12:00:00Z","medication":"Mounjaro","dose_mg":12.5,
           "site":"Left Thigh","next_due_at":"2026-07-15T12:00:00Z"}
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let logs = try decoder.decode([GLP1Log].self, from: json)

        XCTAssertEqual(logs.count, 2, "one NULL row must not take the rest down with it")
        XCTAssertNil(logs[0].site)
        XCTAssertNil(logs[0].nextDueAt)
        XCTAssertEqual(logs[1].site, "Left Thigh")
        XCTAssertNotNil(logs[1].nextDueAt)
    }
}

// MARK: - Ring closure semantics

final class RingClosureTests: XCTestCase {

    // 1800 kcal, 135g protein, 180g carbs, 30g fiber
    private let goal = DailyGoal(
        id: UUID(), userId: UUID(), effectiveDate: "2026-07-07",
        calories: 1800, proteinG: 135, carbsG: 180, fatG: 60, fiberG: 30, waterMlTarget: 2000
    )

    private func closed(_ cal: Double, _ pro: Double = 140, _ carb: Double = 170, _ fib: Double = 32) -> Bool {
        goal.ringsClosed(calories: cal, proteinG: pro, carbsG: carb, fiberG: fib)
    }

    func testHittingTheTargetCloses() {
        XCTAssertTrue(closed(1750))
        XCTAssertTrue(closed(1800), "exactly on the calorie goal")
        XCTAssertTrue(closed(1620), "the 90% band floor")
    }

    // The bug: calories and carbs are ceilings, but both the haptic and CelebrationEngine
    // tested `>=`, so a 3200-calorie day earned a success haptic and a compliment from Pulse.
    func testOvereatingDoesNotClose() {
        XCTAssertFalse(closed(3200))
        XCTAssertFalse(closed(1801), "one calorie over the ceiling")
    }

    func testUndereatingDoesNotClose() {
        XCTAssertFalse(closed(900))
        XCTAssertFalse(closed(1619), "just under the 90% band floor")
    }

    func testCarbCeilingIsNotAFloor() {
        XCTAssertFalse(closed(1750, 140, 181, 32), "carbs one gram over the ceiling")
        XCTAssertTrue(closed(1750, 140, 100, 32), "well under the carb ceiling is fine")
    }

    func testProteinAndFiberAreFloors() {
        XCTAssertFalse(closed(1750, 134, 170, 32), "protein under the floor")
        XCTAssertFalse(closed(1750, 140, 170, 29), "fiber under the floor")
        XCTAssertTrue(closed(1750, 300, 170, 90), "way over the floors is still a win")
    }

    // A zero calorie goal is corrupt data, not a day where every ring is trivially closed.
    func testZeroGoalNeverCloses() {
        let zeroGoal = DailyGoal(
            id: UUID(), userId: UUID(), effectiveDate: "2026-07-07",
            calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0, waterMlTarget: 2000
        )
        XCTAssertFalse(zeroGoal.ringsClosed(calories: 0, proteinG: 0, carbsG: 0, fiberG: 0))
    }

    // The Today haptic and Pulse's recentWins must never disagree — that was the whole bug.
    func testCelebrationEngineAgreesWithRingsClosed() {
        let overate = DailySummary(date: .now, calories: 3200, proteinG: 140, carbsG: 170, fatG: 60, fiberG: 32)
        let wins = CelebrationEngine.detectWins(goal: goal, history: [overate])
        XCTAssertFalse(
            wins.contains { $0.contains("Closed every ring") },
            "Pulse must not congratulate a 3200-calorie day on an 1800-calorie goal"
        )
    }
}

// MARK: - Decimal text input

final class DecimalInputTests: XCTestCase {

    private let us = Locale(identifier: "en_US")
    private let de = Locale(identifier: "de_DE")

    // The core of the manual-entry bug: what the user types must reach the model
    // immediately, on every keystroke, with no focus change.
    func testParsesPlainInput() {
        XCTAssertEqual(DecimalInput.value(from: "250", locale: us), 250)
        XCTAssertEqual(DecimalInput.value(from: "12.5", locale: us), 12.5)
        XCTAssertEqual(DecimalInput.value(from: "", locale: us), 0)
    }

    // Mid-typing state: "1." must already parse, or the field fights the user.
    func testParsesTrailingSeparator() {
        XCTAssertEqual(DecimalInput.value(from: "1.", locale: us), 1)
        XCTAssertEqual(DecimalInput.value(from: "1,", locale: de), 1)
    }

    // German/French/Spanish keypads emit a comma. Double("75,5") is nil.
    func testCommaDecimalLocale() {
        XCTAssertEqual(DecimalInput.sanitize("75,5", locale: de), "75,5")
        XCTAssertEqual(DecimalInput.value(from: "75,5", locale: de), 75.5)
    }

    // A period typed on a comma keypad (and vice versa) normalizes to the locale's.
    func testSeparatorNormalization() {
        XCTAssertEqual(DecimalInput.sanitize("75.5", locale: de), "75,5")
        XCTAssertEqual(DecimalInput.sanitize("75,5", locale: us), "75.5")
    }

    // .decimalPad has no minus key, but paste bypasses the keyboard. A negative macro
    // corrupts every daily total that sums it.
    func testStripsNegativeSign() {
        XCTAssertEqual(DecimalInput.sanitize("-50", locale: us), "50")
        XCTAssertEqual(DecimalInput.value(from: DecimalInput.sanitize("-50", locale: us), locale: us), 50)
    }

    func testStripsJunkAndExtraSeparators() {
        XCTAssertEqual(DecimalInput.sanitize("1.2.3", locale: us), "1.23")
        XCTAssertEqual(DecimalInput.sanitize("12abc3", locale: us), "123")
        XCTAssertEqual(DecimalInput.sanitize("½", locale: us), "", "vulgar fractions are isNumber but not a value")
    }

    // Round trip: rendering must not emit grouping separators, or the next keystroke
    // re-reads "1,000" as a decimal.
    func testTextRoundTripsWithoutGrouping() {
        XCTAssertEqual(DecimalInput.text(from: 1000, locale: us), "1000")
        XCTAssertEqual(DecimalInput.text(from: 0, locale: us), "", "zero shows the placeholder instead")
        XCTAssertEqual(DecimalInput.value(from: DecimalInput.text(from: 12.5, locale: de), locale: de), 12.5)
    }
}

final class WaterUndoTests: XCTestCase {
    // Undoing a glass larger than what's left (e.g. the goal was edited, or a second
    // undo races the first) must clamp at zero rather than going negative.
    func testNeverGoesBelowZero() {
        XCTAssertEqual(TodayViewModel.waterIntakeAfterUndo(150, removing: 250), 0)
    }

    func testSubtractsNormally() {
        XCTAssertEqual(TodayViewModel.waterIntakeAfterUndo(750, removing: 250), 500)
    }

    func testExactUndoReachesZeroNotNegativeZero() {
        XCTAssertEqual(TodayViewModel.waterIntakeAfterUndo(250, removing: 250), 0)
    }
}

// MARK: - LocalStore sync-state transitions
//
// These pin the compare-and-set behaviour that keeps a push from clobbering an
// edit or delete the user made while the request was in flight.

@MainActor
final class LocalStoreSyncStateTests: XCTestCase {

    private var container: ModelContainer!
    private let userId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        // The app's latest versioned schema, not a hand-listed copy — a new @Model
        // (SDWorkoutLog was the lesson) must not silently be missing from the test store.
        let schema = Schema(versionedSchema: NutriPulseSchemaLatest.self)
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        LocalStore.shared.configure(with: container)
    }

    // MARK: Helpers

    @discardableResult
    private func insertLog(quantity: Double = 1.0) throws -> UUID {
        let id = UUID()
        try LocalStore.shared.insertFoodLog(
            id: id, userId: userId, logDate: "2026-07-07", meal: "lunch",
            foodItemId: UUID(), foodItemName: "Rice", quantity: quantity,
            caloriesSnapshot: 100, proteinGSnapshot: 2,
            carbsGSnapshot: 20, fatGSnapshot: 1, fiberGSnapshot: 1
        )
        return id
    }

    private func row(_ id: UUID) throws -> SDFoodLog? {
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        return try container.mainContext.fetch(descriptor).first
    }

    // MARK: Create

    func testCleanCreatePushMarksSynced() throws {
        let id = try insertLog()
        let pushed = try XCTUnwrap(row(id)).revision

        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: pushed)

        XCTAssertEqual(try XCTUnwrap(row(id)).syncState, "synced")
    }

    // Edit lands while the create is in flight: the remote row now exists, so the
    // newer values need a real UPDATE. Marking it "synced" here silently discarded
    // the edit, and the next pull overwrote local state with the stale server value.
    func testEditDuringInFlightCreateBecomesPendingUpdate() throws {
        let id = try insertLog(quantity: 1.0)
        let pushedRevision = try XCTUnwrap(row(id)).revision  // push captures this...

        try LocalStore.shared.updateFoodLog(id: id, meal: "dinner", quantity: 2.5)  // ...user edits mid-flight

        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: pushedRevision)

        let log = try XCTUnwrap(row(id))
        XCTAssertEqual(log.syncState, "pendingUpdate")
        XCTAssertEqual(log.quantity, 2.5)
    }

    // Delete lands while the create is in flight. The tombstone must survive, or the
    // entry the user just deleted comes back on the next pull.
    func testDeleteDuringInFlightCreateKeepsTombstone() throws {
        let id = try insertLog()
        let pushedRevision = try XCTUnwrap(row(id)).revision

        try LocalStore.shared.markFoodLogDeleted(id: id)

        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: pushedRevision)

        XCTAssertEqual(try XCTUnwrap(row(id)).syncState, "pendingDelete")
        XCTAssertTrue(try LocalStore.shared.fetchFoodLogs(for: dateFor("2026-07-07"), userId: userId).isEmpty)
    }

    // Deleting an unsynced row must tombstone, not hard-delete: its create may
    // already have reached the server.
    func testDeletingPendingCreateTombstonesRatherThanDropping() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogDeleted(id: id)
        XCTAssertNotNil(try row(id), "row was hard-deleted; the server copy would be orphaned")
        XCTAssertEqual(try XCTUnwrap(row(id)).syncState, "pendingDelete")
    }

    // MARK: Update

    func testEditDuringInFlightUpdateStaysPending() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)

        try LocalStore.shared.updateFoodLog(id: id, meal: "dinner", quantity: 2.0)
        let pushedRevision = try XCTUnwrap(row(id)).revision   // push captures this...
        try LocalStore.shared.updateFoodLog(id: id, meal: "dinner", quantity: 3.0)  // ...user edits again

        try LocalStore.shared.markFoodLogUpdated(id: id, pushedRevision: pushedRevision)

        let log = try XCTUnwrap(row(id))
        XCTAssertEqual(log.syncState, "pendingUpdate", "the newer quantity still needs pushing")
        XCTAssertEqual(log.quantity, 3.0)
    }

    func testCleanUpdatePushMarksSynced() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)
        try LocalStore.shared.updateFoodLog(id: id, meal: "dinner", quantity: 2.0)

        try LocalStore.shared.markFoodLogUpdated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)

        XCTAssertEqual(try XCTUnwrap(row(id)).syncState, "synced")
    }

    // MARK: Delete

    func testDeleteCompletionOnlyRemovesTombstonedRows() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)

        try LocalStore.shared.removeFoodLogAfterDelete(id: id)   // row is "synced", not tombstoned

        XCTAssertNotNil(try row(id), "a synced row must not be removed by a delete completion")

        try LocalStore.shared.markFoodLogDeleted(id: id)
        try LocalStore.shared.removeFoodLogAfterDelete(id: id)
        XCTAssertNil(try row(id))
    }

    // MARK: Pull reconciliation

    private func remoteLog(id: UUID, meal: Meal, quantity: Double, logDate: String = "2026-07-07") -> FoodLog {
        FoodLog(
            id: id, userId: userId, loggedAt: Date(), logDate: logDate, meal: meal,
            foodItemId: UUID(), quantity: quantity,
            caloriesSnapshot: 100, proteinGSnapshot: 2, carbsGSnapshot: 20,
            fatGSnapshot: 1, fiberGSnapshot: 1,
            foodItems: FoodItemSummary(name: "Rice", brand: nil, servingDesc: nil)
        )
    }

    // The pull applied quantity and macros but never `meal`, so moving an item from lunch
    // to dinner on another device never reached this one.
    func testPullAppliesMealChange() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)
        XCTAssertEqual(try XCTUnwrap(row(id)).meal, "lunch")

        try LocalStore.shared.upsertFoodLog(from: remoteLog(id: id, meal: .dinner, quantity: 1))

        XCTAssertEqual(try XCTUnwrap(row(id)).meal, "dinner")
    }

    // A log deleted on another device used to live here forever — phantom calories in
    // Today's totals that disagreed with Analytics.
    func testPruneRemovesRowsTheServerNoLongerHas() throws {
        let kept = try insertLog()
        let deletedRemotely = try insertLog()
        for id in [kept, deletedRemotely] {
            try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)
        }

        try LocalStore.shared.pruneDeletedFoodLogs(
            userId: userId, since: "2026-07-01", remoteIds: [kept]
        )

        XCTAssertNotNil(try row(kept))
        XCTAssertNil(try row(deletedRemotely))
    }

    // Pruning must never touch rows with local changes still waiting to be pushed.
    func testPruneSparesUnsyncedRows() throws {
        let pendingCreate = try insertLog()

        let pendingUpdate = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: pendingUpdate, pushedRevision: try XCTUnwrap(row(pendingUpdate)).revision)
        try LocalStore.shared.updateFoodLog(id: pendingUpdate, meal: "dinner", quantity: 2)

        let pendingDelete = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: pendingDelete, pushedRevision: try XCTUnwrap(row(pendingDelete)).revision)
        try LocalStore.shared.markFoodLogDeleted(id: pendingDelete)

        // Server returned none of them.
        try LocalStore.shared.pruneDeletedFoodLogs(userId: userId, since: "2026-07-01", remoteIds: [])

        XCTAssertNotNil(try row(pendingCreate), "never pushed — pruning it would lose the log")
        XCTAssertNotNil(try row(pendingUpdate), "edit not yet pushed")
        XCTAssertNotNil(try row(pendingDelete), "tombstone still needs to reach the server")
    }

    func testPruneIgnoresRowsOutsideTheWindowAndOtherUsers() throws {
        let old = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: old, pushedRevision: try XCTUnwrap(row(old)).revision)

        // Window starts after this row's logDate ("2026-07-07").
        try LocalStore.shared.pruneDeletedFoodLogs(userId: userId, since: "2026-07-08", remoteIds: [])
        XCTAssertNotNil(try row(old), "outside the pulled window — the server was never asked about it")

        try LocalStore.shared.pruneDeletedFoodLogs(userId: UUID(), since: "2026-07-01", remoteIds: [])
        XCTAssertNotNil(try row(old), "belongs to a different user")
    }

    // MARK: Water undo

    private func waterRow(_ id: UUID) throws -> SDWaterLog? {
        let descriptor = FetchDescriptor<SDWaterLog>(predicate: #Predicate { $0.id == id })
        return try container.mainContext.fetch(descriptor).first
    }

    @discardableResult
    private func insertWater(amountMl: Double = 250) throws -> UUID {
        let id = UUID()
        try LocalStore.shared.insertWaterLog(
            id: id, userId: userId, logDate: "2026-07-07", amountMl: amountMl
        )
        return id
    }

    // Undo must tombstone, not hard-delete (same contract as food/workout deletes), and
    // the tombstoned row must stop counting toward the day's total immediately.
    func testUndoTombstonesWaterLogAndExcludesItFromTotal() throws {
        let id = try insertWater(amountMl: 250)
        XCTAssertEqual(try LocalStore.shared.fetchWaterTotal(for: dateFor("2026-07-07"), userId: userId), 250)

        try LocalStore.shared.markWaterLogDeleted(id: id)

        XCTAssertNotNil(try waterRow(id), "row was hard-deleted; an in-flight create would be orphaned")
        XCTAssertEqual(try XCTUnwrap(waterRow(id)).syncState, "pendingDelete")
        XCTAssertEqual(try LocalStore.shared.fetchWaterTotal(for: dateFor("2026-07-07"), userId: userId), 0)
    }

    // A create push that lands after Undo must not resurrect the water: markWaterLogSynced
    // only flips pendingCreate → synced, mirroring markWorkoutLogSynced's guard.
    func testMarkWaterLogSyncedDoesNotResurrectATombstone() throws {
        let id = try insertWater()
        try LocalStore.shared.markWaterLogDeleted(id: id)

        try LocalStore.shared.markWaterLogSynced(id: id)

        XCTAssertEqual(try XCTUnwrap(waterRow(id)).syncState, "pendingDelete")
    }

    // Completion of the delete push only removes rows still tombstoned — a race where the
    // row was somehow re-synced first must not hard-delete it out from under that state.
    func testRemoveWaterLogAfterDeleteOnlyRemovesTombstonedRows() throws {
        let id = try insertWater()
        try LocalStore.shared.markWaterLogSynced(id: id)   // not tombstoned yet

        try LocalStore.shared.removeWaterLogAfterDelete(id: id)
        XCTAssertNotNil(try waterRow(id), "a synced row must not be removed by a delete completion")

        try LocalStore.shared.markWaterLogDeleted(id: id)
        try LocalStore.shared.removeWaterLogAfterDelete(id: id)
        XCTAssertNil(try waterRow(id))
    }

    // A pull that skips existing ids must not resurrect a tombstoned row: the local
    // pendingDelete row already exists at that id, so upsertWaterLog's exists-check skips it.
    func testPullSkipsATombstonedWaterLog() throws {
        let id = try insertWater(amountMl: 250)
        try LocalStore.shared.markWaterLogDeleted(id: id)

        try LocalStore.shared.upsertWaterLog(
            id: id, userId: userId, logDate: "2026-07-07", amountMl: 250, loggedAt: .now
        )

        XCTAssertEqual(try XCTUnwrap(waterRow(id)).syncState, "pendingDelete")
        XCTAssertEqual(try LocalStore.shared.fetchWaterTotal(for: dateFor("2026-07-07"), userId: userId), 0)
    }

    // pendingCount feeds the "N changes waiting to sync" badge; a pending water delete
    // (from Undo) must count just like a pending water create does.
    func testPendingCountIncludesPendingWaterDeletes() throws {
        XCTAssertEqual(try LocalStore.shared.pendingCount(), 0)

        let id = try insertWater()
        XCTAssertEqual(try LocalStore.shared.pendingCount(), 1)

        try LocalStore.shared.markWaterLogSynced(id: id)
        XCTAssertEqual(try LocalStore.shared.pendingCount(), 0)

        try LocalStore.shared.markWaterLogDeleted(id: id)
        XCTAssertEqual(try LocalStore.shared.pendingCount(), 1)
    }

    // MARK: Workout reconciliation

    private func remoteWorkout(
        id: UUID = UUID(),
        healthKitUUID: String,
        startedAt: Date = Date(timeIntervalSince1970: 2_000_000)
    ) -> WorkoutLog {
        WorkoutLog(
            id: id, userId: userId, loggedAt: startedAt,
            logDate: "2026-07-07", activityType: "traditionalStrengthTraining",
            durationMinutes: 33, activeCalories: 145, distanceMeters: nil,
            source: .healthkit, healthKitUUID: healthKitUUID, startedAt: startedAt
        )
    }

    func testWorkoutPullCoalescesPendingImportWithSameHealthKitUUID() throws {
        let healthKitUUID = UUID().uuidString
        try LocalStore.shared.insertWorkoutLog(
            id: UUID(), userId: userId, logDate: "2026-07-07",
            activityType: "traditionalStrengthTraining", durationMinutes: 33,
            activeCalories: 145, distanceMeters: nil, source: "healthkit",
            healthKitUUID: healthKitUUID, startedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        let remote = remoteWorkout(healthKitUUID: healthKitUUID)

        try LocalStore.shared.upsertWorkoutLog(from: remote)

        let rows = try LocalStore.shared.fetchWorkoutLogs(for: dateFor("2026-07-07"), userId: userId)
        XCTAssertEqual(rows.map(\.id), [remote.id])
        XCTAssertTrue(try LocalStore.shared.pendingWorkoutLogs().isEmpty)
    }

    func testWorkoutPullCleansDuplicateEvenWhenCanonicalRemoteRowAlreadyExists() throws {
        let healthKitUUID = UUID().uuidString
        let remote = remoteWorkout(healthKitUUID: healthKitUUID)
        try LocalStore.shared.upsertWorkoutLog(from: remote)
        try LocalStore.shared.insertWorkoutLog(
            id: UUID(), userId: userId, logDate: "2026-07-07",
            activityType: remote.activityType, durationMinutes: remote.durationMinutes,
            activeCalories: remote.activeCalories, distanceMeters: nil, source: "healthkit",
            healthKitUUID: healthKitUUID, startedAt: remote.startedAt
        )

        try LocalStore.shared.upsertWorkoutLog(from: remote)

        let rows = try LocalStore.shared.fetchWorkoutLogs(for: dateFor("2026-07-07"), userId: userId)
        XCTAssertEqual(rows.map(\.id), [remote.id])
        XCTAssertTrue(try LocalStore.shared.pendingWorkoutLogs().isEmpty)
    }

    func testWorkoutPullRekeysPendingDeletionToRemoteID() throws {
        let healthKitUUID = UUID().uuidString
        let localID = UUID()
        try LocalStore.shared.insertWorkoutLog(
            id: localID, userId: userId, logDate: "2026-07-07",
            activityType: "traditionalStrengthTraining", durationMinutes: 33,
            activeCalories: 145, distanceMeters: nil, source: "healthkit",
            healthKitUUID: healthKitUUID, startedAt: Date(timeIntervalSince1970: 2_000_000)
        )
        try LocalStore.shared.markWorkoutLogDeleted(id: localID)
        let remote = remoteWorkout(healthKitUUID: healthKitUUID)

        try LocalStore.shared.upsertWorkoutLog(from: remote)

        XCTAssertTrue(try LocalStore.shared.fetchWorkoutLogs(
            for: dateFor("2026-07-07"), userId: userId
        ).isEmpty)
        XCTAssertEqual(try LocalStore.shared.deletedWorkoutLogs().map(\.id), [remote.id])
    }

    // MARK: Goal ownership

    // The cross-account leak: SDDailyGoal had no owner, so the next user to sign in
    // on this device read the previous user's calorie and macro targets.
    func testGoalIsScopedToItsOwner() throws {
        let otherUser = UUID()
        try LocalStore.shared.upsertGoal(goal(for: userId, calories: 1800))

        XCTAssertEqual(try LocalStore.shared.fetchGoal(for: .now, userId: userId)?.calories, 1800)
        XCTAssertNil(try LocalStore.shared.fetchGoal(for: .now, userId: otherUser))
    }

    func testWipeAllClearsCachedRows() throws {
        let id = try insertLog()
        try LocalStore.shared.upsertGoal(goal(for: userId, calories: 1800))

        try LocalStore.shared.wipeAll()

        XCTAssertNil(try row(id))
        XCTAssertNil(try LocalStore.shared.fetchGoal(for: .now, userId: userId))
    }

    // MARK: Fixtures

    private func goal(for userId: UUID, calories: Double) -> DailyGoal {
        DailyGoal(
            id: UUID(), userId: userId,
            effectiveDate: Date.now.isoDateString,
            calories: calories, proteinG: 150, carbsG: 180,
            fatG: 60, fiberG: 30, waterMlTarget: 2000
        )
    }

    private func dateFor(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.date(from: iso)!
    }
}

// MARK: - HealthKit workout overlap deduplication

@MainActor
final class HealthKitWorkoutDeduplicationTests: XCTestCase {
    private func workout(
        _ uuid: String,
        activity: String = "traditionalStrengthTraining",
        startMinute: Double,
        duration: Double,
        calories: Double? = nil
    ) -> HealthKitManager.HKWorkoutSummary {
        HealthKitManager.HKWorkoutSummary(
            uuid: uuid, activitySlug: activity,
            startDate: Date(timeIntervalSince1970: startMinute * 60),
            durationMinutes: duration, activeCalories: calories, distanceMeters: nil
        )
    }

    func testNearIdenticalOverlappingHealthWorkoutsCollapse() {
        let first = workout("a", startMinute: 0, duration: 33, calories: 145)
        let mirrored = workout("b", startMinute: 1, duration: 32, calories: 155)

        let result = HealthKitManager.deduplicatedWorkouts([mirrored, first])

        XCTAssertEqual(result.map(\.uuid), ["a"], "the longer equally-rich record wins")
    }

    func testAdjacentWorkoutsRemainSeparate() {
        let first = workout("a", startMinute: 0, duration: 30)
        let second = workout("b", startMinute: 30, duration: 30)
        XCTAssertEqual(
            HealthKitManager.deduplicatedWorkouts([second, first]).map(\.uuid),
            ["a", "b"]
        )
    }

    func testDifferentActivitiesRemainSeparateEvenWhenTheyOverlap() {
        let strength = workout("a", startMinute: 0, duration: 30)
        let walk = workout("b", activity: "walking", startMinute: 1, duration: 30)
        XCTAssertEqual(
            HealthKitManager.deduplicatedWorkouts([walk, strength]).map(\.uuid),
            ["a", "b"]
        )
    }
}

final class StoredWorkoutDeduplicationTests: XCTestCase {
    private let userID = UUID()

    private func workout(
        id: UUID = UUID(),
        source: WorkoutSource = .healthkit,
        startMinute: Double,
        duration: Double
    ) -> WorkoutLog {
        WorkoutLog(
            id: id, userId: userID, loggedAt: Date(timeIntervalSince1970: startMinute * 60),
            logDate: "2026-07-07", activityType: "traditionalStrengthTraining",
            durationMinutes: duration, activeCalories: 145, distanceMeters: nil,
            source: source, healthKitUUID: source == .healthkit ? UUID().uuidString : nil,
            startedAt: Date(timeIntervalSince1970: startMinute * 60)
        )
    }

    func testExistingMirroredServerRowsCollapseForConsumers() {
        let first = workout(startMinute: 0, duration: 33)
        let mirrored = workout(startMinute: 1, duration: 32)
        XCTAssertEqual(WorkoutLog.deduplicated([mirrored, first]).map(\.id), [first.id])
    }

    func testOverlappingManualEntriesAreNeverSilentlyCollapsed() {
        let first = workout(source: .manual, startMinute: 0, duration: 33)
        let second = workout(source: .manual, startMinute: 1, duration: 32)
        XCTAssertEqual(WorkoutLog.deduplicated([second, first]).count, 2)
    }
}

// MARK: - Sleep interval merging

// HealthKitManager.mergedDuration is the fix for a real double-count: an Apple Watch and a
// sleep app (AutoSleep, Oura, Whoop) each write their own "asleep" samples for the same
// night, so summing every sample reported ~14h for a 7h night. It must count any covered
// stretch once, regardless of overlap or input order. Pure and nonisolated, so it tests
// without touching HealthKit.
final class SleepMergeTests: XCTestCase {

    // A fixed reference instant; offsets are in hours for readability.
    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private func h(_ hours: Double) -> Date { base.addingTimeInterval(hours * 3600) }
    private func interval(_ start: Double, _ end: Double) -> (start: Date, end: Date) {
        (start: h(start), end: h(end))
    }

    func testEmptyIsZero() {
        XCTAssertEqual(HealthKitManager.mergedDuration(of: []), 0)
    }

    func testSingleInterval() {
        XCTAssertEqual(HealthKitManager.mergedDuration(of: [interval(0, 7)]), 7 * 3600, accuracy: 0.001)
    }

    // Two non-overlapping stretches (woke up, fell back asleep) sum.
    func testDisjointIntervalsSum() {
        let d = HealthKitManager.mergedDuration(of: [interval(0, 3), interval(4, 7)])
        XCTAssertEqual(d, 6 * 3600, accuracy: 0.001)
    }

    // The bug this guards: two sources logging the SAME 7h night must not become 14h.
    func testIdenticalOverlapCountsOnce() {
        let watch = interval(0, 7)
        let sleepApp = interval(0, 7)
        XCTAssertEqual(HealthKitManager.mergedDuration(of: [watch, sleepApp]), 7 * 3600, accuracy: 0.001)
    }

    // 0–5 and 4–9 overlap on 4–5; the union is 0–9.
    func testPartialOverlapMerges() {
        let d = HealthKitManager.mergedDuration(of: [interval(0, 5), interval(4, 9)])
        XCTAssertEqual(d, 9 * 3600, accuracy: 0.001)
    }

    // An interval fully inside another contributes nothing extra.
    func testNestedIntervalAbsorbed() {
        let d = HealthKitManager.mergedDuration(of: [interval(0, 8), interval(2, 5)])
        XCTAssertEqual(d, 8 * 3600, accuracy: 0.001)
    }

    // Touching (end == next start) is one continuous stretch, not a gap.
    func testAdjacentIntervalsJoin() {
        let d = HealthKitManager.mergedDuration(of: [interval(0, 3), interval(3, 7)])
        XCTAssertEqual(d, 7 * 3600, accuracy: 0.001)
    }

    // HealthKit returns samples in no guaranteed order; the merge must sort first.
    func testUnsortedInputIsMerged() {
        let d = HealthKitManager.mergedDuration(of: [interval(4, 9), interval(0, 5)])
        XCTAssertEqual(d, 9 * 3600, accuracy: 0.001)
    }

    // Zero- and negative-length intervals are dropped, never counted or crashed on.
    func testDegenerateIntervalsIgnored() {
        let d = HealthKitManager.mergedDuration(of: [interval(2, 2), interval(5, 4), interval(0, 6)])
        XCTAssertEqual(d, 6 * 3600, accuracy: 0.001)
    }
}

// MARK: - Age from date of birth

// GoalCalculator.ageYears feeds Mifflin-St Jeor. dateComponents(.year) floors to completed
// years, which is the intent. Passing `now` keeps these deterministic.
final class AgeFromDOBTests: XCTestCase {

    private let cal = Calendar.current
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testExactBirthdayCountsTheFullYear() {
        XCTAssertEqual(
            GoalCalculator.ageYears(fromDOB: date(1990, 6, 15), now: date(2020, 6, 15)),
            30
        )
    }

    // The day before the birthday they are still 29 — completed years only.
    func testDayBeforeBirthdayIsStillYounger() {
        XCTAssertEqual(
            GoalCalculator.ageYears(fromDOB: date(1990, 6, 15), now: date(2020, 6, 14)),
            29
        )
    }

    // A DOB under a year old is age 0 — NOT the 30 fallback (age-0 DOB was a real onboarding bug).
    func testUnderOneYearIsZeroNotFallback() {
        XCTAssertEqual(
            GoalCalculator.ageYears(fromDOB: date(2020, 1, 1), now: date(2020, 8, 1)),
            0
        )
    }

    // A leap-day birthday resolves without throwing and floors correctly.
    func testLeapDayBirthday() {
        XCTAssertEqual(
            GoalCalculator.ageYears(fromDOB: date(2000, 2, 29), now: date(2020, 3, 1)),
            20
        )
    }
}

// MARK: - HealthKit weight auto-import decision

// TodayViewModel.shouldImportHKWeight gates whether a HealthKit weight sample becomes a new
// weight_logs row. Getting it wrong produced real duplicates: back-imported old readings, a
// write→read→re-import echo of the app's own writes, and a second row when two loads raced.
// The three guards form a simple truth table, tested here in isolation.
final class HKWeightImportTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var yesterday: Date { now.addingTimeInterval(-24 * 3600) }

    private func decide(sampleDate: Date, isFromThisApp: Bool, alreadySyncedToday: Bool) -> Bool {
        TodayViewModel.shouldImportHKWeight(
            sampleDate: sampleDate,
            isFromThisApp: isFromThisApp,
            alreadySyncedToday: alreadySyncedToday,
            now: now
        )
    }

    // Today's reading, from another source, first import of the day → import it.
    func testTodaysExternalSampleImports() {
        XCTAssertTrue(decide(sampleDate: now, isFromThisApp: false, alreadySyncedToday: false))
    }

    // An older reading is never back-imported, even if everything else allows it.
    func testYesterdaysSampleIsNotImported() {
        XCTAssertFalse(decide(sampleDate: yesterday, isFromThisApp: false, alreadySyncedToday: false))
    }

    // The app's own write, read straight back, must not become a second row (echo loop).
    func testOwnWriteIsNotReimported() {
        XCTAssertFalse(decide(sampleDate: now, isFromThisApp: true, alreadySyncedToday: false))
    }

    // Once-per-day guard: a second load the same day doesn't import again.
    func testAlreadySyncedTodayBlocksSecondImport() {
        XCTAssertFalse(decide(sampleDate: now, isFromThisApp: false, alreadySyncedToday: true))
    }

    // A same-day sample counts even a minute before midnight — the guard is calendar-day, not 24h.
    func testLateNightSampleStillCountsAsToday() {
        let cal = Calendar.current
        let almostMidnight = cal.date(bySettingHour: 23, minute: 59, second: 0, of: now)!
        XCTAssertTrue(TodayViewModel.shouldImportHKWeight(
            sampleDate: almostMidnight, isFromThisApp: false, alreadySyncedToday: false, now: now
        ))
    }
}

// MARK: - Day nudge (workout-aware)

// TodayViewModel.buildNudge is the pure decision + copy behind the Today under-eating
// nudge, extracted (like shouldImportHKWeight) so this truth table needs no ViewModel,
// clock, or SwiftData.
final class DayNudgeTests: XCTestCase {

    // 2000 kcal, 150g protein — round numbers so percentages read at a glance.
    private let goal = DailyGoal(
        id: UUID(), userId: UUID(), effectiveDate: "2026-07-19",
        calories: 2000, proteinG: 150, carbsG: 200, fatG: 65, fiberG: 30, waterMlTarget: 2000
    )

    private func workout(
        _ activityType: String = "strength",
        minutes: Double = 30,
        source: WorkoutSource = .manual
    ) -> WorkoutLog {
        WorkoutLog(
            id: UUID(), userId: UUID(), loggedAt: .now, logDate: "2026-07-19",
            activityType: activityType, durationMinutes: minutes,
            activeCalories: nil, distanceMeters: nil,
            source: source, healthKitUUID: nil, startedAt: .now
        )
    }

    private func nudge(
        protein: Double, calories: Double,
        workouts: [WorkoutLog] = [], hour: Int = 18
    ) -> DayNudge? {
        TodayViewModel.buildNudge(
            goal: goal, totalProteinG: protein, totalCalories: calories,
            todaysWorkouts: workouts, hour: hour
        )
    }

    func testMorningsStayQuietEvenAfterAWorkout() {
        XCTAssertNil(nudge(protein: 0, calories: 0, workouts: [workout()], hour: 9))
        XCTAssertNotNil(nudge(protein: 0, calories: 0, workouts: [workout()], hour: 14),
                        "2pm is the existing afternoon gate")
    }

    // The workout-aware part: 75% of protein is fine on a rest day but behind on a
    // training day, because the protein floor matters more after a session.
    func testWorkoutDayRaisesTheProteinTrigger() {
        // Calories held at 70% so they can't trip the (unchanged) calorie trigger.
        let protein75 = 112.5
        XCTAssertNil(nudge(protein: protein75, calories: 1400),
                     "75% protein on a rest day: no nudge")
        XCTAssertNotNil(nudge(protein: protein75, calories: 1400, workouts: [workout()]),
                        "75% protein on a training day: nudge")
        XCTAssertNil(nudge(protein: 125, calories: 1900, workouts: [workout()]),
                     "83% protein clears even the raised trigger")
    }

    // Movement must never turn into eat-more-because-you-burned: the calorie trigger is
    // identical with and without a workout.
    func testWorkoutDoesNotChangeTheCalorieTrigger() {
        let proteinFine = 140.0
        XCTAssertNil(nudge(protein: proteinFine, calories: 1300, workouts: [workout()]),
                     "65% calories triggers on neither day type")
        XCTAssertNotNil(nudge(protein: proteinFine, calories: 1100, workouts: [workout()]))
        XCTAssertNotNil(nudge(protein: proteinFine, calories: 1100))
    }

    func testAlmostThereGuardStillApplies() {
        // 79% protein on a workout day, but only 14g and 200 kcal left — no nagging.
        let smallGoal = DailyGoal(
            id: UUID(), userId: UUID(), effectiveDate: "2026-07-19",
            calories: 1000, proteinG: 65, carbsG: 100, fatG: 35, fiberG: 20, waterMlTarget: 2000
        )
        XCTAssertNil(TodayViewModel.buildNudge(
            goal: smallGoal, totalProteinG: 51, totalCalories: 800,
            todaysWorkouts: [workout()], hour: 18
        ))
    }

    func testSingleSessionIsNamedInBodyAndPrompt() {
        let n = nudge(protein: 40, calories: 900, workouts: [workout("strength", minutes: 32)])
        XCTAssertEqual(n?.headline, "Feed the work you put in")
        XCTAssertTrue(n?.body.contains("32 minutes of strength") == true, n?.body ?? "nil")
        XCTAssertTrue(n?.prompt.contains("32 minutes of strength") == true, n?.prompt ?? "nil")
    }

    func testHealthKitSlugIsHumanizedInTheCopy() {
        let n = nudge(protein: 40, calories: 900,
                      workouts: [workout("traditionalStrengthTraining", minutes: 45, source: .healthkit)])
        XCTAssertTrue(n?.body.contains("45 minutes of traditional strength training") == true,
                      n?.body ?? "nil")
    }

    func testMultipleSessionsRollUpToCountAndMinutes() {
        let n = nudge(protein: 40, calories: 900,
                      workouts: [workout(minutes: 32), workout("walk", minutes: 30)])
        XCTAssertTrue(n?.body.contains("2 sessions (62 min)") == true, n?.body ?? "nil")
    }

    func testRestDayCopyIsUnchanged() {
        let n = nudge(protein: 40, calories: 900)
        XCTAssertEqual(n?.headline, "You've got room to finish strong")
        XCTAssertEqual(n?.cta, "Ask Pulse for dinner ideas")
    }

    // The banned-vocabulary spot check: nothing the nudge ever renders may use
    // burn/earn framing, in any variant.
    func testCopyNeverUsesBurnOrEarnFraming() {
        for n in [
            nudge(protein: 40, calories: 900),
            nudge(protein: 40, calories: 900, workouts: [workout()]),
            nudge(protein: 40, calories: 900, workouts: [workout(minutes: 20), workout(minutes: 25)]),
        ].compactMap({ $0 }) {
            for text in [n.headline, n.body, n.cta, n.prompt] {
                XCTAssertFalse(text.lowercased().contains("burn"), text)
                XCTAssertFalse(text.lowercased().contains("earn"), text)
            }
        }
    }
}

// MARK: - Body measurements

final class BodyMeasurementTests: XCTestCase {

    // Raw values are stored in body_measurement_logs.site and CHECKed by the migration —
    // renaming a case is a data migration, not a refactor. This test is the tripwire.
    func testSiteRawValuesAreAStableAPIContract() {
        XCTAssertEqual(
            MeasurementSite.allCases.map(\.rawValue),
            ["waist", "hips", "chest", "upperArm", "thigh"]
        )
    }

    // Only the waist has a HealthKit quantity type; the app must not pretend otherwise.
    func testOnlyWaistIsHealthKitBacked() {
        XCTAssertEqual(MeasurementSite.allCases.filter(\.isHealthKitBacked), [.waist])
    }

    func testLengthConversionRoundTrips() {
        let imperial = UnitSystem.imperial
        XCTAssertEqual(imperial.cmFromLength(38.0), 96.52, accuracy: 0.001)
        XCTAssertEqual(imperial.lengthInput(fromCm: 96.52), 38.0, accuracy: 0.001)
        // Metric is identity in both directions.
        XCTAssertEqual(UnitSystem.metric.cmFromLength(96.5), 96.5)
        XCTAssertEqual(UnitSystem.metric.lengthInput(fromCm: 96.5), 96.5)
    }

    func testUnknownSiteDecodesWithoutCrashing() throws {
        // A future app version may write sites this build doesn't know. The row must
        // decode (site stays a String); only siteType comes back nil.
        let json = """
        {"id":"\(UUID().uuidString)","user_id":"\(UUID().uuidString)","log_date":"2026-07-20",
         "site":"neck","value_cm":38.5,"source":"manual","healthkit_uuid":null,
         "logged_at":"2026-07-20T12:00:00Z"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(BodyMeasurementLog.self, from: json)
        XCTAssertEqual(row.site, "neck")
        XCTAssertNil(row.siteType)
    }
}

// MARK: - Body hub insights

// Rule-based, hand-written insight triggers — no generated copy. The non-shaming
// invariant: no insight ever fires on a waist increase.
final class BodyHubInsightTests: XCTestCase {

    private func insight(
        waistDelta: Double?, waistPoints: Int = 3,
        leanDelta: Double? = nil, leanBaseline: Double? = nil, leanPoints: Int = 0,
        weightDelta: Double? = nil, weightBaseline: Double? = nil, weightPoints: Int = 0
    ) -> String? {
        BodyHubViewModel.insight(
            waistDeltaCm: waistDelta, waistPoints: waistPoints,
            leanDeltaKg: leanDelta, leanBaselineKg: leanBaseline, leanPoints: leanPoints,
            weightDeltaKg: weightDelta, weightBaselineKg: weightBaseline, weightPoints: weightPoints,
            rangePhrase: "this quarter"
        )
    }

    func testWaistDownWithLeanSteadyFiresTheThesisLine() {
        let text = insight(waistDelta: -2.5, leanDelta: -0.4, leanBaseline: 57, leanPoints: 3)
        XCTAssertEqual(text, "Your waist moved this quarter while lean mass held steady.")
    }

    func testScaleFlatButWaistDownFiresTheStallReassurance() {
        let text = insight(waistDelta: -1.5, weightDelta: 0.3, weightBaseline: 84, weightPoints: 4)
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("scale held still") == true, text ?? "nil")
    }

    func testWaistIncreaseNeverGetsCommentary() {
        XCTAssertNil(insight(waistDelta: 2.5, leanDelta: 0, leanBaseline: 57, leanPoints: 3,
                             weightDelta: 0, weightBaseline: 84, weightPoints: 4),
                     "a waist increase must produce silence, not judgment")
    }

    func testSmallWaistChangeIsBelowTheTrigger() {
        XCTAssertNil(insight(waistDelta: -0.6, leanDelta: 0, leanBaseline: 57, leanPoints: 3))
    }

    func testSinglePointsNeverTrigger() {
        XCTAssertNil(insight(waistDelta: -3, waistPoints: 1, leanDelta: 0, leanBaseline: 57, leanPoints: 3))
        XCTAssertNil(insight(waistDelta: -3, leanDelta: 0, leanBaseline: 57, leanPoints: 1))
    }

    func testLeanFloorTwoPercentBand() {
        // 2% of 57 kg = 1.14 kg — the band edge.
        XCTAssertEqual(BodyHubViewModel.leanHeldSteady(deltaKg: -1.2, baselineKg: 57), false)
        XCTAssertEqual(BodyHubViewModel.leanHeldSteady(deltaKg: -1.1, baselineKg: 57), true)
        XCTAssertEqual(BodyHubViewModel.leanHeldSteady(deltaKg: 2.0, baselineKg: 57), false,
                       "gaining past the band is also not 'steady' — it just renders as a quiet delta")
        XCTAssertNil(BodyHubViewModel.leanHeldSteady(deltaKg: nil, baselineKg: 57))
    }
}

// MARK: - Maintenance offer

// The pure trigger behind "you're at your goal weight — shift to maintenance?".
final class MaintenanceOfferTests: XCTestCase {

    private func offer(
        avg: Double, goal: Double? = 72.5,
        calories: Double = 2050, tdee: Double = 2550,
        dismissedFor: Double? = nil
    ) -> Bool {
        TodayViewModel.shouldOfferMaintenance(
            avgWeightKg: avg, goalWeightKg: goal,
            currentCalories: calories, tdeeAtAvg: tdee,
            dismissedForGoalKg: dismissedFor
        )
    }

    func testWithinOnePercentOfGoalOffers() {
        XCTAssertTrue(offer(avg: 73.2))          // 0.97% above 72.5
        XCTAssertTrue(offer(avg: 71.8))          // just below
        XCTAssertFalse(offer(avg: 73.5), "1.4% above, still descending — not there yet")
    }

    func testOvershootCountsOnlyInTheDirectionOfTravel() {
        // Deficit (losing): past the goal means BELOW it.
        XCTAssertTrue(offer(avg: 70.0))
        // Surplus (gaining): past the goal means ABOVE it.
        XCTAssertTrue(offer(avg: 75.0, calories: 2800, tdee: 2550))
        XCTAssertFalse(offer(avg: 70.0, calories: 2800, tdee: 2550),
                       "below goal while gaining toward it is not arrival")
    }

    func testNoGoalOrNoAdjustmentNeverOffers() {
        XCTAssertFalse(offer(avg: 72.5, goal: nil))
        XCTAssertFalse(offer(avg: 72.5, calories: 2500, tdee: 2550),
                       "already within 100 kcal of maintenance — nothing to shift")
    }

    func testDismissalSuppressesForThatGoalOnly() {
        XCTAssertFalse(offer(avg: 72.5, dismissedFor: 72.5))
        XCTAssertTrue(offer(avg: 72.5, dismissedFor: 74.0),
                      "changing the goal re-arms the offer")
    }
}

// MARK: - Recovery coaching

final class RecoveryCoachTests: XCTestCase {
    private let userId = UUID()

    private func goal() -> DailyGoal {
        DailyGoal(
            id: UUID(), userId: userId, effectiveDate: "2026-08-26",
            calories: 2000, proteinG: 150, carbsG: 200, fatG: 67,
            fiberG: 28, waterMlTarget: 2500
        )
    }

    private func workout(startedAt: Date, minutes: Double = 45) -> WorkoutLog {
        WorkoutLog(
            id: UUID(), userId: userId, loggedAt: startedAt,
            logDate: "2026-08-26", activityType: "strength",
            durationMinutes: minutes, activeCalories: 250, distanceMeters: nil,
            source: .healthkit, healthKitUUID: UUID().uuidString, startedAt: startedAt
        )
    }

    func testRecentWorkoutCreatesExactRecoveryGap() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let result = try XCTUnwrap(RecoveryCoach.opportunity(
            workouts: [workout(startedAt: now.addingTimeInterval(-90 * 60))],
            goal: goal(), proteinToday: 112, waterTodayMl: 1800, now: now
        ))
        XCTAssertEqual(result.proteinGap, 38)
        XCTAssertEqual(result.waterGapMl, 700)
        XCTAssertEqual(result.workoutName, "Strength")
    }

    func testOldWorkoutDoesNotPretendRecoveryIsStillImmediate() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertNil(RecoveryCoach.opportunity(
            workouts: [workout(startedAt: now.addingTimeInterval(-10 * 3600))],
            goal: goal(), proteinToday: 80, waterTodayMl: 1000, now: now
        ))
    }
}

// MARK: - Talk-to-log conversational corrections

final class TalkCorrectionParserTests: XCTestCase {
    func testParsesRemoveHalfDoubleAndSetQuantity() {
        XCTAssertEqual(TalkCorrectionParser.parse("Actually, remove the cheese"), .remove(query: "cheese"))
        XCTAssertEqual(TalkCorrectionParser.parse("half the rice"), .scale(query: "rice", multiplier: 0.5))
        XCTAssertEqual(TalkCorrectionParser.parse("double chicken"), .scale(query: "chicken", multiplier: 2))
        XCTAssertEqual(TalkCorrectionParser.parse("make chicken two"), .setQuantity(query: "chicken", quantity: 2))
        XCTAssertEqual(TalkCorrectionParser.parse("make that 1.5"), .setQuantity(query: nil, quantity: 1.5))
    }

    func testUnknownCorrectionFailsClosed() {
        XCTAssertNil(TalkCorrectionParser.parse("make it healthier"))
    }
}

// MARK: - Shot-cycle planning

final class ShotCyclePlannerTests: XCTestCase {
    private func checkIn(day: Int, appetite: Int, nausea: Int = 1, energy: Int = 3) -> ShotCycleCheckIn {
        ShotCycleCheckIn(
            id: UUID(), userId: UUID(), checkinDate: "2026-08-26", cycleDay: day,
            appetite: appetite, fullness: 3, nausea: nausea, energy: energy,
            digestion: 3, note: nil, createdAt: .now
        )
    }

    func testLowAppetiteAdaptsTheFirstAction() {
        let today = checkIn(day: 2, appetite: 1)
        let plan = ShotCyclePlanner.plan(cycleDay: 2, today: today, history: [today])
        XCTAssertEqual(plan.phase, "Low-appetite window")
        XCTAssertTrue(plan.actions[0].contains("smallest protein-dense"))
    }

    func testExperienceCheckInScheduleUsesDaysOneThreeAndSix() {
        XCTAssertTrue(ShotCycleCheckInSchedule.isDue(cycleDay: 1, hasTodayCheckIn: false))
        XCTAssertTrue(ShotCycleCheckInSchedule.isDue(cycleDay: 3, hasTodayCheckIn: false))
        XCTAssertTrue(ShotCycleCheckInSchedule.isDue(cycleDay: 6, hasTodayCheckIn: false))
        XCTAssertFalse(ShotCycleCheckInSchedule.isDue(cycleDay: 0, hasTodayCheckIn: false))
        XCTAssertFalse(ShotCycleCheckInSchedule.isDue(cycleDay: 2, hasTodayCheckIn: false))
        XCTAssertFalse(ShotCycleCheckInSchedule.isDue(cycleDay: 4, hasTodayCheckIn: false))
        XCTAssertFalse(ShotCycleCheckInSchedule.isDue(cycleDay: 5, hasTodayCheckIn: false))
        XCTAssertFalse(ShotCycleCheckInSchedule.isDue(cycleDay: 7, hasTodayCheckIn: false))
    }

    func testCompletedExperienceCheckInIsNotDueAgainThatDay() {
        XCTAssertFalse(ShotCycleCheckInSchedule.isDue(cycleDay: 3, hasTodayCheckIn: true))
        XCTAssertFalse(ShotCycleCheckInSchedule.isDue(cycleDay: nil, hasTodayCheckIn: false))
    }

    func testRepeatedCycleDayLearnsPattern() {
        let history = [checkIn(day: 2, appetite: 1), checkIn(day: 2, appetite: 2)]
        let plan = ShotCyclePlanner.plan(cycleDay: 2, today: nil, history: history)
        XCTAssertEqual(plan.learnedPattern, "Your check-ins say day 2 is usually a lower-appetite day.")
    }

    func testLowAppetitePreparationRequiresRepeatedPriorPattern() {
        XCTAssertNil(LowAppetitePreparationEngine.predict(
            currentCycleDay: 1,
            history: [checkIn(day: 2, appetite: 1)]
        ))
        let prediction = LowAppetitePreparationEngine.predict(
            currentCycleDay: 1,
            history: [checkIn(day: 2, appetite: 1), checkIn(day: 2, appetite: 2)]
        )
        XCTAssertEqual(prediction?.targetCycleDay, 2)
        XCTAssertEqual(prediction?.confidence, .emerging)
    }

    func testPreparationCompletionIsScopedToThePredictionAndDay() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "LowAppetitePreparationStoreTests"))
        defaults.removePersistentDomain(forName: "LowAppetitePreparationStoreTests")
        let preparation = LowAppetitePreparation(
            targetCycleDay: 2, averageAppetite: 1.5, sampleCount: 2, confidence: .emerging
        )
        let day = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 26)))
        LowAppetitePreparationStore.markCompleted(preparation, date: day, defaults: defaults)
        XCTAssertTrue(LowAppetitePreparationStore.isCompleted(preparation, date: day, defaults: defaults))
        XCTAssertFalse(LowAppetitePreparationStore.isCompleted(
            preparation,
            date: Calendar.current.date(byAdding: .day, value: 1, to: day)!,
            defaults: defaults
        ))
    }
}

final class WeeklyRecapTests: XCTestCase {
    private let calendar = WeeklyRecapSchedule.isoCalendar(timeZone: TimeZone(identifier: "America/Los_Angeles")!)

    private func date(_ day: Int, hour: Int = 9, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    // Sep 28, 2026 is a Monday.
    func testRecapIsDueMondayThroughWednesdayOnly() {
        XCTAssertFalse(WeeklyRecapSchedule.isDue(now: date(27), lastRecapAt: nil, calendar: calendar), "Sunday is a partial week")
        XCTAssertTrue(WeeklyRecapSchedule.isDue(now: date(28, hour: 7), lastRecapAt: nil, calendar: calendar))
        XCTAssertTrue(WeeklyRecapSchedule.isDue(now: date(30), lastRecapAt: nil, calendar: calendar))
        XCTAssertFalse(WeeklyRecapSchedule.isDue(now: date(1, month: 10), lastRecapAt: nil, calendar: calendar), "Thursday is too late")
    }

    func testRecapIsOncePerWeek() {
        let thisMonday = date(28, hour: 8)
        XCTAssertFalse(WeeklyRecapSchedule.isDue(now: date(29), lastRecapAt: thisMonday, calendar: calendar))
        // A recap from last week (even last Wednesday, under six days by the old rule's
        // arithmetic on a Monday morning) doesn't block this week's.
        XCTAssertTrue(WeeklyRecapSchedule.isDue(now: date(28, hour: 6), lastRecapAt: date(23, hour: 20), calendar: calendar))
    }

    func testLastWeekIsTheCompletedMondayToSunday() {
        let interval = WeeklyRecapSchedule.lastWeek(before: date(29), calendar: calendar)
        XCTAssertEqual(interval.start, calendar.startOfDay(for: date(21)))
        XCTAssertEqual(interval.end, calendar.startOfDay(for: date(27)))
        XCTAssertEqual(interval.priorStart, calendar.startOfDay(for: date(14)))
    }

    func testFrequentFoodsKeepsOnlyRepeatsMostFrequentFirst() {
        let foods = WeeklyRecapDigest.frequentFoods([
            "Greek yogurt", "greek yogurt ", "Greek yogurt", "Protein shake", "Protein shake",
            "Salmon", "Unknown food", "Unknown food",
        ])
        XCTAssertEqual(foods, ["Greek yogurt (3×)", "Protein shake (2×)"])
    }

    func testDigestTreatsUnloggedDaysAsUnknownNotMisses() {
        let interval = WeeklyRecapSchedule.lastWeek(before: date(29), calendar: calendar)
        let summaries = (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: interval.start)!
            let logged = offset < 3
            return DailySummary(date: day, calories: logged ? 1600 : 0, proteinG: logged ? 130 : 0, carbsG: 0, fatG: 0, fiberG: 0)
        }
        let digest = WeeklyRecapDigest.build(
            interval: interval, summaries: summaries, movement: [], weightLogs: [],
            checkIns: [], foodNames: [], proteinGoal: 120, calendar: calendar
        )
        XCTAssertEqual(digest.daysLogged, 3)
        XCTAssertEqual(digest.proteinFloorDays, 3)
        XCTAssertEqual(digest.days.count, 7)
        XCTAssertNil(digest.days[5].proteinFloorHit)
        XCTAssertNil(digest.priorWeek)
    }
}

final class GLP1SkippedDoseTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private var injection: GLP1Log {
        GLP1Log(id: UUID(), userId: UUID(), injectedAt: date("2026-09-01T16:00:00Z"),
                medication: "Zepbound", doseMg: 5, site: "Left Abdomen",
                nextDueAt: date("2026-09-08T16:00:00Z"))
    }
    private func skip(_ log: GLP1Log, due: Date? = nil) -> GLP1SkippedDose {
        let scheduled = due ?? log.nextDueAt!
        return GLP1SkippedDose(id: UUID(), userId: log.userId, injectionId: log.id,
            scheduledAt: scheduled, nextReminderAt: calendar.date(byAdding: .day, value: 7, to: scheduled)!,
            createdAt: scheduled)
    }

    func testSkipAdvancesReminderWithoutChangingActualInjectionOrSite() {
        let log = injection
        let skipped = skip(log)
        let schedule = GLP1DoseSchedule(latest: log, skips: [skipped], now: date("2026-09-09T16:00:00Z"), calendar: calendar)
        XCTAssertEqual(schedule.nextDue, skipped.nextReminderAt)
        XCTAssertEqual(schedule.skippedThisWeek?.id, skipped.id)
        XCTAssertEqual(schedule.latest?.injectedAt, log.injectedAt)
        XCTAssertEqual(schedule.latest?.site, log.site)
        XCTAssertTrue(schedule.cycleInterrupted)
        XCTAssertFalse(schedule.isPastDueDay)
    }

    func testFutureSkipDoesNotInterruptActualCurrentCycle() {
        let log = injection
        let schedule = GLP1DoseSchedule(latest: log, skips: [skip(log)], now: date("2026-09-03T16:00:00Z"), calendar: calendar)
        XCTAssertNotNil(schedule.skippedThisWeek)
        XCTAssertFalse(schedule.cycleInterrupted)
    }

    func testRepeatedSkipsAndUndoResolveOnlyExplicitDecisions() {
        let log = injection
        let first = skip(log)
        let second = skip(log, due: first.nextReminderAt)
        var schedule = GLP1DoseSchedule(latest: log, skips: [second, first], now: date("2026-09-16T16:00:00Z"), calendar: calendar)
        XCTAssertEqual(schedule.nextDue, second.nextReminderAt)
        schedule = GLP1DoseSchedule(latest: log, skips: [first], now: schedule.now, calendar: calendar)
        XCTAssertEqual(schedule.nextDue, first.nextReminderAt)
        XCTAssertNil(schedule.skippedThisWeek)
        schedule = GLP1DoseSchedule(latest: log, skips: [], now: schedule.now, calendar: calendar)
        XCTAssertEqual(schedule.nextDue, log.nextDueAt)
        XCTAssertFalse(schedule.cycleInterrupted)
    }

    func testUndoEarlierSkipDoesNotSilentlySkipAnUnrecordedWeek() {
        let log = injection
        let later = skip(log, due: date("2026-09-15T16:00:00Z"))
        let schedule = GLP1DoseSchedule(latest: log, skips: [later], now: date("2026-09-16T16:00:00Z"), calendar: calendar)
        XCTAssertEqual(schedule.nextDue, log.nextDueAt)
        XCTAssertNil(schedule.skippedThisWeek)
    }

    func testNewInjectionResumesCycleAndIgnoresPriorSkips() {
        let oldLog = injection
        let newLog = injection
        let schedule = GLP1DoseSchedule(latest: newLog, skips: [skip(oldLog)])
        XCTAssertEqual(schedule.nextDue, newLog.nextDueAt)
        XCTAssertTrue(schedule.relevantSkips.isEmpty)
        XCTAssertFalse(schedule.cycleInterrupted)
    }

    func testPassingTimeDoesNotInventSkipsOrResetCycle() {
        let log = injection
        let schedule = GLP1DoseSchedule(latest: log, skips: [skip(log)], now: date("2026-10-01T16:00:00Z"), calendar: calendar)
        XCTAssertNil(schedule.skippedThisWeek)
        XCTAssertEqual(schedule.nextDue, date("2026-09-15T16:00:00Z"))
        XCTAssertTrue(schedule.cycleInterrupted)
        XCTAssertTrue(schedule.isPastDueDay)
    }

    func testDueTodayIsNotPastDueEvenAfterReminderHour() {
        let schedule = GLP1DoseSchedule(latest: injection, skips: [], now: date("2026-09-08T23:00:00Z"), calendar: calendar)
        XCTAssertFalse(schedule.isPastDueDay)
    }

    func testMissingScheduleRemainsUnknown() {
        XCTAssertNil(GLP1DoseSchedule(latest: nil, skips: []).nextDue)
        let log = GLP1Log(id: UUID(), userId: UUID(), injectedAt: .now,
            medication: "Zepbound", doseMg: 5, site: nil, nextDueAt: nil)
        XCTAssertNil(GLP1DoseSchedule(latest: log, skips: []).nextDue)
    }

    func testReminderKeepsLocalTimeAcrossDaylightSaving() {
        let log = injection
        let skipped = skip(log, due: date("2026-10-27T16:00:00Z"))
        XCTAssertEqual(skipped.nextReminderAt, date("2026-11-03T17:00:00Z"))
        XCTAssertEqual(calendar.component(.hour, from: skipped.nextReminderAt), 9)
    }
}

final class StrongWeekTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        value.firstWeekday = 1
        return value
    }
    private func week(_ start: String, ongoing: Bool = false, note: String = "Traveling") -> StrongWeek {
        .init(id: UUID(), userId: UUID(), weekStart: start, circumstances: [.travel], note: note,
              activityRestrictions: "", ongoing: ongoing, contextRevision: UUID(), outlook: nil, generatedAt: nil, updatedAt: .now)
    }
    func testLocalMondayBoundaryIgnoresLocaleFirstWeekdayAndHandlesDST() {
        XCTAssertEqual(StrongWeekWindow.key(for: date("2026-09-21T06:59:59Z"), calendar: calendar), "2026-09-14")
        XCTAssertEqual(StrongWeekWindow.key(for: date("2026-09-21T07:00:00Z"), calendar: calendar), "2026-09-21")
        XCTAssertEqual(StrongWeekWindow.key(for: date("2026-11-02T07:59:59Z"), calendar: calendar), "2026-10-26")
        XCTAssertEqual(StrongWeekWindow.key(for: date("2026-11-02T08:00:00Z"), calendar: calendar), "2026-11-02")
    }
    func testWeekKeysRemainGregorianForOtherDeviceCalendars() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        XCTAssertEqual(StrongWeekWindow.key(for: date("2026-09-16T12:00:00Z"), calendar: buddhist), "2026-09-14")
    }
    func testNothingDifferentClearsOldRestrictionsAndOngoingFlag() {
        var draft = StrongWeekDraft(circumstances: [.injury], note: "Knee", activityRestrictions: "No running", ongoing: true)
        draft.toggle(.usual)
        XCTAssertEqual(draft.circumstances, [.usual])
        XCTAssertTrue(draft.note.isEmpty)
        XCTAssertTrue(draft.activityRestrictions.isEmpty)
        XCTAssertFalse(draft.ongoing)
        draft.toggle(.travel)
        XCTAssertEqual(draft.circumstances, [.travel])
    }
    func testDraftBoundsTextAndRemovesConflictingUsualSelection() {
        let draft = StrongWeekDraft(circumstances: [.usual], note: String(repeating: "a", count: 1100), activityRestrictions: String(repeating: "b", count: 600)).normalized
        XCTAssertEqual(draft.note.count, 1000)
        XCTAssertEqual(draft.activityRestrictions.count, 500)
        XCTAssertFalse(draft.circumstances.contains(.usual))
    }
    func testTemporaryContextExpiresRatherThanLeakingIntoTheNextWeek() {
        let now = date("2026-09-23T12:00:00Z")
        let old = week("2026-09-14")
        let context = StrongWeekContext.make(current: old, previous: old, now: now)
        XCTAssertEqual(context.status, "not_provided")
        XCTAssertTrue(context.note.isEmpty)
        XCTAssertFalse(context.needsTailoredSuggestions)
    }
    func testOngoingContextRequiresConfirmationAndDoesNotCarryOldOutlook() {
        let old = week("2026-09-14", ongoing: true, note: "Injured")
        let context = StrongWeekContext.make(current: nil, previous: old, now: date("2026-09-23T12:00:00Z"))
        XCTAssertEqual(context.status, "needs_confirmation")
        XCTAssertEqual(context.note, "Injured")
        XCTAssertNil(context.outlook)
        XCTAssertTrue(context.needsTailoredSuggestions)
    }
    func testCurrentWeekReplacesOlderOngoingContext() {
        let context = StrongWeekContext.make(current: week("2026-09-21", note: "Busy"), previous: week("2026-09-14", ongoing: true, note: "Old"), now: date("2026-09-23T12:00:00Z"))
        XCTAssertEqual(context.status, "current")
        XCTAssertEqual(context.note, "Busy")
    }
    func testUnloggedDaysAreNotZeroCalorieDays() {
        let days = [
            DailySummary(date: .now, calories: 1800, proteinG: 100, carbsG: 0, fatG: 0, fiberG: 0),
            DailySummary(date: .now, calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0)
        ]
        let result = StrongWeekEvidence.nutrition(days, expectedDays: 7, target: 90)
        XCTAssertEqual(result.loggedDays, 1)
        XCTAssertEqual(result.expectedDays, 7)
        XCTAssertEqual(result.averageLoggedCalories, 1800)
        XCTAssertEqual(result.daysAtCurrentProteinTarget, 1)
        XCTAssertNil(StrongWeekEvidence.nutrition([], expectedDays: 7, target: nil).averageLoggedCalories)
    }
    func testSparseRecoveryDoesNotClaimComparableTrends() {
        let sparse = StrongWeekEvidence.comparison(metric: "sleepHours", recent: [6, 7], baseline: Array(repeating: 8, count: 10))
        XCTAssertFalse(sparse.comparisonAvailable)
        XCTAssertEqual(sparse.recentObservedDays, 2)
        let usable = StrongWeekEvidence.comparison(metric: "sleepHours", recent: [6, 7, 8], baseline: Array(repeating: 8, count: 7))
        XCTAssertTrue(usable.comparisonAvailable)
        XCTAssertEqual(usable.recentAverage, 7)
        XCTAssertNil(StrongWeekEvidence.comparison(metric: "sleepHours", recent: [.nan], baseline: []).recentAverage)
    }
    func testMissingWorkoutsRemainEmptyEvidenceNotAPlannedRestWeek() {
        let movement = StrongWeekEvidence.movement([], expectedDays: 7)
        XCTAssertEqual(movement.daysWithLoggedActivity, 0)
        XCTAssertTrue(movement.activities.isEmpty)
        XCTAssertEqual(movement.expectedDays, 7)
    }
}

final class PulsePreferenceTests: XCTestCase {
    private func week(ongoing: Bool = false) -> StrongWeek {
        .init(id: UUID(), userId: UUID(), weekStart: "2026-09-14", circumstances: [.injury], note: "Ankle injury",
              activityRestrictions: "No weight bearing", ongoing: ongoing, contextRevision: UUID(), outlook: nil,
              generatedAt: nil, updatedAt: .now, adjustments: [.simpler, .lessActivity])
    }
    func testAdjustmentPreservesInjuryAndClinicianRestrictions() {
        var draft = week().draft
        draft.adjustments = [.moreFoodIdeas, .lessActivity]
        let value = draft.normalized
        XCTAssertEqual(value.circumstances, [.injury])
        XCTAssertEqual(value.note, "Ankle injury")
        XCTAssertEqual(value.activityRestrictions, "No weight bearing")
        XCTAssertEqual(value.adjustments, [.moreFoodIdeas, .lessActivity])
    }
    func testAdjustmentExpiresEvenWhenInjuryNeedsConfirmation() {
        let now = ISO8601DateFormatter().date(from: "2026-09-23T12:00:00Z")!
        let context = StrongWeekContext.make(current: nil, previous: week(ongoing: true), now: now)
        XCTAssertEqual(context.status, "needs_confirmation")
        XCTAssertEqual(context.activityRestrictions, "No weight bearing")
        XCTAssertTrue(context.adjustments.isEmpty)
    }
    func testLessActivityPausesGenericSuggestionsWithoutInventingAnInjury() {
        var context = StrongWeekContext(weekStart: "2026-09-14", status: "current", circumstances: [], note: "", activityRestrictions: "", outlook: nil)
        context.adjustments = [WeekAdjustment.lessActivity.rawValue]
        XCTAssertTrue(context.needsTailoredSuggestions)
        XCTAssertTrue(context.circumstances.isEmpty)
    }
    func testLegacyWeekDecodesWithoutAdjustmentColumn() throws {
        let encoder = JSONEncoder()
        let record = week()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(record)) as? [String: Any])
        json.removeValue(forKey: "adjustments")
        let decoded = try JSONDecoder().decode(StrongWeek.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.adjustments)
        XCTAssertTrue(decoded.draft.adjustments.isEmpty)
    }
    func testFoodPreferencesNormalizeAndDistinguishMissingFromUnavailable() {
        let draft = FoodAccessDraft(choices: [.rarelyCook, .budgetFriendly], note: "  " + String(repeating: "a", count: 700) + "  ").normalized
        XCTAssertEqual(draft.note.count, 500)
        XCTAssertEqual(draft.choices.count, 2)
        XCTAssertEqual(FoodAccessContext.make(nil).status, "not_provided")
        XCTAssertEqual(FoodAccessContext.unavailable.status, "unavailable")
        let cleared = FoodAccessPreferences(userId: UUID(), choices: [], note: "", updatedAt: .now)
        XCTAssertEqual(FoodAccessContext.make(cleared).status, "saved")
        XCTAssertTrue(FoodAccessContext.make(cleared).choices.isEmpty)
    }
    @MainActor func testConfirmingPreviousWeekDoesNotCarryResponseAdjustments() {
        let vm = StrongWeekViewModel()
        vm.previous = week(ongoing: true)
        vm.confirmPrevious()
        XCTAssertTrue(vm.didConfirmPrevious)
        XCTAssertTrue(vm.draft.adjustments.isEmpty)
        XCTAssertEqual(vm.draft.activityRestrictions, "No weight bearing")
    }
}

@MainActor
final class StrongWeekReminderTests: XCTestCase {
    func testRepeatingRequestHasFloatingMondayEightAMSchedule() throws {
        let userId = UUID()
        let request = StrongWeekReminder.request(userId: userId)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.weekday, 2)
        XCTAssertEqual(trigger.dateComponents.hour, 8)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertNil(trigger.dateComponents.timeZone)
        XCTAssertNil(trigger.dateComponents.year)
        XCTAssertEqual(request.content.userInfo["userId"] as? String, userId.uuidString)
        XCTAssertEqual(request.content.userInfo["destination"] as? String, "strong_week")
        XCTAssertFalse(request.identifier.hasPrefix(NotificationManager.smartIdentifierPrefix))
    }
    func testMondayLocalTimeAcrossDSTAndTravelZones() throws {
        for zone in ["America/Los_Angeles", "America/New_York", "Asia/Kolkata", "Australia/Sydney"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
            for date in ["2026-03-07T12:00:00Z", "2026-10-31T12:00:00Z"] {
                let start = try XCTUnwrap(ISO8601DateFormatter().date(from: date))
                let next = try XCTUnwrap(calendar.nextDate(after: start, matching: StrongWeekReminder.components, matchingPolicy: .nextTime))
                XCTAssertEqual(calendar.component(.weekday, from: next), 2)
                XCTAssertEqual(calendar.component(.hour, from: next), 8)
                XCTAssertEqual(calendar.component(.minute, from: next), 0)
            }
        }
    }
    func testOptOutIsAccountScopedAndRoutesCannotCrossAccounts() throws {
        let suite = "StrongWeekReminderTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let user = UUID(), other = UUID()
        XCTAssertTrue(StrongWeekReminder.enabled(userId: user, defaults: defaults))
        defaults.set(false, forKey: StrongWeekReminder.preferenceKey(userId: user))
        XCTAssertFalse(StrongWeekReminder.enabled(userId: user, defaults: defaults))
        XCTAssertTrue(StrongWeekReminder.enabled(userId: other, defaults: defaults))
        StrongWeekReminder.saveRoute(userId: user, defaults: defaults)
        XCTAssertFalse(StrongWeekReminder.consumeRoute(userId: other, defaults: defaults))
        XCTAssertFalse(StrongWeekReminder.consumeRoute(userId: user, defaults: defaults))
        StrongWeekReminder.saveRoute(userId: user, defaults: defaults)
        XCTAssertTrue(StrongWeekReminder.consumeRoute(userId: user, defaults: defaults))
        XCTAssertFalse(StrongWeekReminder.consumeRoute(userId: user, defaults: defaults))
    }
}

final class StrongWeekFeedbackTests: XCTestCase {
    func testFeedbackUsesTheSameTimestampForStorageAndLookup() throws {
        let date = Date(timeIntervalSince1970: 1_789_621_234.123456)
        let feedback = StrongWeekFeedback(userId: UUID(), strongWeekId: UUID(), contextRevision: UUID(),
            generatedAt: date, outlook: .init(observation: "A busy week", foodFocus: "Familiar meals", movementFocus: "A walk"),
            rating: .notHelpful, reasons: [.tooVague, .moreFoodIdeas], updatedAt: date)
        let encoded = try PostgrestClient.Configuration.jsonEncoder.encode(feedback)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["generated_at"] as? String, date.ISO8601Format(.init(includingFractionalSeconds: true)))
        XCTAssertEqual(json["rating"] as? String, "not_helpful")
        XCTAssertEqual(json["reasons"] as? [String], ["too_vague", "more_food_ideas"])
        let decoded = try PostgrestClient.Configuration.jsonDecoder.decode(StrongWeekFeedback.self, from: encoded)
        XCTAssertEqual(decoded.outlook, feedback.outlook)
        XCTAssertEqual(decoded.strongWeekId, feedback.strongWeekId)
        XCTAssertEqual(decoded.generatedAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }
}

// MARK: - Daylight Log sheet (docs/daylight-redesign.md)

final class FoodLoggingLogicTests: XCTestCase {

    // MARK: LogTab

    func testLogTabTelemetrySourcesMatchTheirTab() {
        XCTAssertEqual(FoodLoggingViewModel.LogTab.talk.telemetrySource, .talk)
        XCTAssertEqual(FoodLoggingViewModel.LogTab.search.telemetrySource, .search)
        XCTAssertEqual(FoodLoggingViewModel.LogTab.scan.telemetrySource, .scan)
        XCTAssertEqual(FoodLoggingViewModel.LogTab.favorites.telemetrySource, .favorite)
    }

    func testLogTabsAreTalkSearchScanFavoritesInOrder() {
        XCTAssertEqual(FoodLoggingViewModel.LogTab.allCases, [.talk, .search, .scan, .favorites])
    }

    // MARK: ProteinDensity / FoodSearchMacros (Search's "Protein-dense" filter)

    func testProteinDenseAtOrAboveTenGramsPerHundredCalories() {
        // Chicken breast-like ratio: 31g protein / 165 kcal ≈ 18.8g/100kcal.
        XCTAssertTrue(ProteinDensity.isProteinDense(calories: 165, proteinG: 31))
        // Exactly at the threshold.
        XCTAssertTrue(ProteinDensity.isProteinDense(calories: 100, proteinG: 10))
    }

    func testProteinDenseFalseBelowThresholdOrWithNoCalories() {
        // White rice-like ratio: ~2.7g/100kcal.
        XCTAssertFalse(ProteinDensity.isProteinDense(calories: 130, proteinG: 2.7))
        XCTAssertFalse(ProteinDensity.isProteinDense(calories: 0, proteinG: 5))
    }

    func testFoodSearchMacrosParsesFatSecretStyleDescription() throws {
        let description = "Per 100g - Calories: 165kcal | Fat: 3.6g | Carbs: 0g | Protein: 31g"
        let macros = try XCTUnwrap(FoodSearchMacros.parse(description))
        XCTAssertEqual(macros.calories, 165)
        XCTAssertEqual(macros.proteinG, 31)
    }

    func testFoodSearchMacrosReturnsNilWhenFieldsAreMissing() {
        XCTAssertNil(FoodSearchMacros.parse("A food with no macro summary"))
    }

    // MARK: ProteinFloorCheck ("This clears your floor")

    func testClearsFloorWhenAddedProteinCrossesTheGoal() {
        XCTAssertTrue(ProteinFloorCheck.clearsFloor(currentProteinG: 112, addedProteinG: 33, goalG: 140))
    }

    func testDoesNotClearFloorWhenStillShortOfGoal() {
        XCTAssertFalse(ProteinFloorCheck.clearsFloor(currentProteinG: 60, addedProteinG: 10, goalG: 140))
    }

    func testDoesNotClearFloorWhenAlreadyAtOrOverGoal() {
        // Already there — nothing left to "clear".
        XCTAssertFalse(ProteinFloorCheck.clearsFloor(currentProteinG: 145, addedProteinG: 10, goalG: 140))
    }

    func testDoesNotClearFloorWithNoOrZeroGoal() {
        XCTAssertFalse(ProteinFloorCheck.clearsFloor(currentProteinG: 50, addedProteinG: 100, goalG: nil))
        XCTAssertFalse(ProteinFloorCheck.clearsFloor(currentProteinG: 50, addedProteinG: 100, goalG: 0))
    }

    // MARK: RecentFoodsGrouper (Favorites tab's "Recents from the last 72 hours")

    private func foodLog(
        name: String,
        hoursAgo: Double,
        foodItemId: UUID = UUID(),
        meal: Meal = .snack,
        quantity: Double = 1,
        proteinG: Double = 10,
        now: Date
    ) -> FoodLog {
        FoodLog(
            id: UUID(), userId: UUID(), loggedAt: now.addingTimeInterval(-hoursAgo * 3600),
            logDate: now.isoDateString, meal: meal, foodItemId: foodItemId, quantity: quantity,
            caloriesSnapshot: 100, proteinGSnapshot: proteinG, carbsGSnapshot: 5, fatGSnapshot: 2, fiberGSnapshot: 1,
            foodItems: .init(name: name, brand: nil, servingDesc: nil)
        )
    }

    func testRecentLogsExcludesAnythingOlderThanSeventyTwoHours() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let withinWindow = foodLog(name: "Cottage cheese", hoursAgo: 71, now: now)
        let justOutside = foodLog(name: "Old oatmeal", hoursAgo: 73, now: now)
        let recent = RecentFoodsGrouper.recentLogs(from: [withinWindow, justOutside], now: now, favoritedFoodItemIds: [])
        XCTAssertEqual(recent.map(\.displayName), ["Cottage cheese"])
    }

    func testRecentLogsHidesFavoritedFoods() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let favoritedId = UUID()
        let favorited = foodLog(name: "Yogurt bowl", hoursAgo: 2, foodItemId: favoritedId, now: now)
        let notFavorited = foodLog(name: "Turkey chili", hoursAgo: 3, now: now)
        let recent = RecentFoodsGrouper.recentLogs(from: [favorited, notFavorited], now: now, favoritedFoodItemIds: [favoritedId])
        XCTAssertEqual(recent.map(\.displayName), ["Turkey chili"])
    }

    func testRecentLogsAreSortedNewestFirst() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let older = foodLog(name: "Everything bagel", hoursAgo: 20, now: now)
        let newer = foodLog(name: "Cottage cheese", hoursAgo: 1, now: now)
        let recent = RecentFoodsGrouper.recentLogs(from: [older, newer], now: now, favoritedFoodItemIds: [])
        XCTAssertEqual(recent.map(\.displayName), ["Cottage cheese", "Everything bagel"])
    }

    func testGroupedLabelsTodayYesterdayAndWeekdayInFirstSeenOrder() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // A Wednesday at noon UTC.
        let now = calendar.date(from: DateComponents(year: 2024, month: 3, day: 20, hour: 12))!

        let today = foodLog(name: "Cottage cheese", hoursAgo: 2, now: now)
        let yesterday = foodLog(name: "Turkey chili", hoursAgo: 20, now: now)
        let monday = foodLog(name: "String cheese", hoursAgo: 50, now: now)

        let sections = RecentFoodsGrouper.grouped([today, yesterday, monday], now: now, calendar: calendar)
        XCTAssertEqual(sections.map(\.label), ["Today", "Yesterday", "Monday"])
        XCTAssertEqual(sections.map { $0.logs.map(\.displayName) }, [["Cottage cheese"], ["Turkey chili"], ["String cheese"]])
    }

    func testGroupedKeepsMultipleLogsUnderTheSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2024, month: 3, day: 20, hour: 12))!
        let first = foodLog(name: "Cottage cheese", hoursAgo: 1, now: now)
        let second = foodLog(name: "Everything bagel", hoursAgo: 3, now: now)
        let sections = RecentFoodsGrouper.grouped([first, second], now: now, calendar: calendar)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].logs.count, 2)
    }
}

// MARK: - Hold-to-confirm (Daylight Shot day)

// `HoldToConfirmProgress` is the state machine behind `HoldToConfirmButton`'s press-and-hold
// gesture (NutriPulse/Features/GLP1/HoldToConfirmButton.swift). It's kept free of SwiftUI/UIKit
// so these three race conditions — the ones that actually matter for a hold gesture — can be
// checked without driving a real gesture, animation, or timer.
final class HoldToConfirmProgressTests: XCTestCase {

    func testFreshStateIsNotHoldingOrComplete() {
        let state = HoldToConfirmProgress()
        XCTAssertFalse(state.isHolding)
        XCTAssertFalse(state.isComplete)
    }

    func testBeginHoldStartsHolding() {
        var state = HoldToConfirmProgress()
        XCTAssertTrue(state.beginHold())
        XCTAssertTrue(state.isHolding)
        XCTAssertFalse(state.isComplete)
    }

    // A full hold: begin, then the timer fires once the duration has elapsed.
    func testCompleteAfterHoldingSucceeds() {
        var state = HoldToConfirmProgress()
        state.beginHold()
        XCTAssertTrue(state.complete())
        XCTAssertTrue(state.isComplete)
        XCTAssertFalse(state.isHolding)
    }

    // Releasing early must cancel — a stale timer scheduled before the release must not still
    // confirm the dose.
    func testReleasingEarlyCancelsAndBlocksTheStaleTimer() {
        var state = HoldToConfirmProgress()
        state.beginHold()
        state.cancelHold()
        XCTAssertFalse(state.isHolding)
        XCTAssertFalse(state.isComplete)
        // The DispatchWorkItem scheduled by `beginHold` may still fire after the cancel; `complete`
        // must be a no-op in that case.
        XCTAssertFalse(state.complete())
        XCTAssertFalse(state.isComplete)
    }

    // A confirmation can only fire once, even if `complete` is somehow called twice.
    func testCompleteIsNotReentrant() {
        var state = HoldToConfirmProgress()
        state.beginHold()
        XCTAssertTrue(state.complete())
        XCTAssertFalse(state.complete())
    }

    // Calling `complete` without ever holding (e.g. a stray timer with no matching press) must
    // not confirm.
    func testCompleteWithoutHoldingDoesNothing() {
        var state = HoldToConfirmProgress()
        XCTAssertFalse(state.complete())
        XCTAssertFalse(state.isComplete)
    }

    // Once complete, a new press must not restart the hold — the caller expects exactly one
    // confirmation per instance (the view gives `HoldToConfirmButton` a fresh id to try again).
    func testBeginHoldAfterCompleteIsRejected() {
        var state = HoldToConfirmProgress()
        state.beginHold()
        state.complete()
        XCTAssertFalse(state.beginHold())
        XCTAssertFalse(state.isHolding)
    }

    // `reset` clears both flags so an instance can be reused (mainly for tests).
    func testResetClearsHoldingAndComplete() {
        var state = HoldToConfirmProgress()
        state.beginHold()
        state.complete()
        state.reset()
        XCTAssertFalse(state.isHolding)
        XCTAssertFalse(state.isComplete)
        XCTAssertTrue(state.beginHold())
    }

    // cancelHold after completion must not un-confirm a dose that already logged.
    func testCancelAfterCompleteIsIgnored() {
        var state = HoldToConfirmProgress()
        state.beginHold()
        state.complete()
        state.cancelHold()
        XCTAssertTrue(state.isComplete)
    }
}

// MARK: - Analytics questions

final class ProteinSourceAggregatorTests: XCTestCase {
    private func log(_ name: String, protein: Double, loggedAt: Date = .now) -> FoodLog {
        FoodLog(
            id: UUID(), userId: UUID(), loggedAt: loggedAt, logDate: loggedAt.isoDateString,
            meal: .breakfast, foodItemId: UUID(), quantity: 1,
            caloriesSnapshot: 200, proteinGSnapshot: protein, carbsGSnapshot: 10, fatGSnapshot: 5, fiberGSnapshot: 1,
            foodItems: FoodItemSummary(name: name, brand: nil, servingDesc: nil)
        )
    }

    func testMergesNamesCaseInsensitivelyAndTrimmed() {
        let sources = ProteinSourceAggregator.topSources(from: [
            log("Greek Yogurt", protein: 20),
            log("greek yogurt", protein: 20),
            log(" Greek Yogurt ", protein: 20),
        ])
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.name, "Greek Yogurt")
        XCTAssertEqual(sources.first?.gramsProtein, 60)
        XCTAssertEqual(sources.first?.timesLogged, 3)
        XCTAssertEqual(sources.first?.share, 1.0)
    }

    func testShareIsAgainstTheFullRangeTotalNotJustTheTopFive() {
        let sources = ProteinSourceAggregator.topSources(from: [
            log("Turkey Chili", protein: 30),
            log("Turkey Chili", protein: 30),
            log("Kale", protein: 10),
        ], limit: 5)
        XCTAssertEqual(sources.count, 2)
        XCTAssertEqual(sources[0].name, "Turkey Chili")
        XCTAssertEqual(sources[0].share, 60.0 / 70.0, accuracy: 0.0001)
        XCTAssertEqual(sources[1].share, 10.0 / 70.0, accuracy: 0.0001)
    }

    func testKeepsOnlyTheTopFiveByProtein() {
        let logs = (1...7).map { log("Food \($0)", protein: Double($0) * 10) }
        let sources = ProteinSourceAggregator.topSources(from: logs)
        XCTAssertEqual(sources.count, 5)
        XCTAssertEqual(sources.first?.name, "Food 7")
        XCTAssertEqual(sources.last?.name, "Food 3")
    }

    func testEmptyLogsProduceNoSources() {
        XCTAssertEqual(ProteinSourceAggregator.topSources(from: []), [])
        XCTAssertNil(ProteinSourceAggregator.headline(for: []))
    }

    func testHeadlineNamesTheTopTwoAndTheirCombinedShare() {
        let sources = ProteinSourceAggregator.topSources(from: [
            log("Greek Yogurt", protein: 19), log("Greek Yogurt", protein: 19),
            log("Turkey Chili", protein: 19),
            log("Kale", protein: 63),
        ])
        // Greek Yogurt 38g, Turkey Chili 19g, Kale 63g — total 120g. Top two by protein are
        // Kale (63g) and Greek Yogurt (38g): 101/120 ≈ 84%.
        let headline = ProteinSourceAggregator.headline(for: sources)
        XCTAssertEqual(headline, "Kale and Greek Yogurt gave you 84% of your protein.")
    }

    func testHeadlineWithOnlyOneSourceNamesJustThatOne() {
        let sources = ProteinSourceAggregator.topSources(from: [log("Protein Shake", protein: 25)])
        XCTAssertEqual(ProteinSourceAggregator.headline(for: sources), "Protein Shake gave you 100% of your protein.")
    }
}

final class GLP1DoseChangeDetectorTests: XCTestCase {
    private func log(_ medication: String, _ doseMg: Double, daysAgo: Int) -> GLP1Log {
        GLP1Log(
            id: UUID(), userId: UUID(), injectedAt: Date.now.addingTimeInterval(-Double(daysAgo) * 86_400),
            medication: medication, doseMg: doseMg, site: "Left Abdomen", nextDueAt: nil
        )
    }

    func testNoChangeAcrossRepeatedSameDose() {
        let logs = [log("Zepbound", 5, daysAgo: 21), log("Zepbound", 5, daysAgo: 14), log("Zepbound", 5, daysAgo: 7)]
        XCTAssertEqual(GLP1DoseChangeDetector.changes(in: logs), [])
    }

    func testFirstLogOfAMedicationIsAStartNotAChange() {
        let logs = [log("Zepbound", 5, daysAgo: 7)]
        XCTAssertEqual(GLP1DoseChangeDetector.changes(in: logs), [])
    }

    func testDetectsAnIncreaseInDose() {
        let logs = [log("Zepbound", 2.5, daysAgo: 14), log("Zepbound", 2.5, daysAgo: 7), log("Zepbound", 5, daysAgo: 0)]
        let changes = GLP1DoseChangeDetector.changes(in: logs)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.doseMg, 5)
        XCTAssertEqual(changes.first?.medication, "Zepbound")
    }

    func testTracksDosePerMedicationSoSwitchingDrugsIsNotAChange() {
        // Switching from Ozempic 2.0mg to Zepbound 5.0mg isn't a "dose change" on a shared
        // scale — they're different molecules — but a later Zepbound increase still is.
        let logs = [
            log("Ozempic", 2.0, daysAgo: 21),
            log("Zepbound", 5.0, daysAgo: 14),
            log("Zepbound", 7.5, daysAgo: 7),
        ]
        let changes = GLP1DoseChangeDetector.changes(in: logs)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.doseMg, 7.5)
    }
}

final class WeightTrendEngineTests: XCTestCase {
    private func log(_ weightKg: Double, daysAgo: Int) -> WeightLog {
        WeightLog(id: UUID(), userId: UUID(), loggedAt: Date.now.addingTimeInterval(-Double(daysAgo) * 86_400), weightKg: weightKg, source: "manual")
    }

    func testRollingAverageSmoothsATrailingWindow() {
        XCTAssertEqual(WeightTrendEngine.rollingAverage([100, 140, 120, 160], window: 3), [100, 120, 120, 140])
        XCTAssertEqual(WeightTrendEngine.rollingAverage([5, 7], window: 1), [5, 7])
        XCTAssertEqual(WeightTrendEngine.rollingAverage([], window: 3), [])
    }

    func testSmoothedSeriesSortsByDateAndSmooths() {
        let logs = [log(82, daysAgo: 0), log(80, daysAgo: 14), log(81, daysAgo: 7)]
        let series = WeightTrendEngine.smoothedSeries(from: logs, window: 2)
        XCTAssertEqual(series.map(\.date), logs.sorted { $0.loggedAt < $1.loggedAt }.map(\.loggedAt))
        XCTAssertEqual(series.map { ($0.value * 100).rounded() / 100 }, [80, 80.5, 81.5])
    }

    func testTakeawayWithNoWeighInsSaysSo() {
        XCTAssertEqual(WeightTrendEngine.takeaway(for: [], units: .metric), "No weigh-ins logged in this range yet.")
    }

    func testTakeawayWithOneWeighInSaysNotEnoughForAChange() {
        XCTAssertEqual(WeightTrendEngine.takeaway(for: [log(80, daysAgo: 0)], units: .metric),
                       "Only one weigh-in logged — not enough to show a change.")
    }

    func testTakeawayBelowMinimumAdmitsItsTooFewToCallATrend() {
        let logs = [log(82, daysAgo: 14), log(81, daysAgo: 7), log(80, daysAgo: 0)]
        let takeaway = WeightTrendEngine.takeaway(for: logs, units: .metric)
        XCTAssertTrue(takeaway.contains("too few weigh-ins to call a trend"), takeaway)
        XCTAssertTrue(takeaway.contains("down"), takeaway)
        XCTAssertTrue(takeaway.contains("3 weigh-ins"), takeaway)
    }

    func testTakeawayAtOrAboveMinimumNeverMentionsTooFew() {
        let logs = [log(84, daysAgo: 21), log(83, daysAgo: 14), log(81.5, daysAgo: 7), log(80, daysAgo: 0)]
        let takeaway = WeightTrendEngine.takeaway(for: logs, units: .metric)
        XCTAssertFalse(takeaway.contains("too few"), takeaway)
        XCTAssertTrue(takeaway.contains("down"), takeaway)
        XCTAssertTrue(takeaway.contains("4 weigh-ins"), takeaway)
    }

    func testTakeawaySaysSteadyRatherThanUpOrDownForATinyChange() {
        let logs = [log(80.0, daysAgo: 21), log(80.02, daysAgo: 14), log(79.98, daysAgo: 7), log(80.01, daysAgo: 0)]
        let takeaway = WeightTrendEngine.takeaway(for: logs, units: .metric)
        XCTAssertTrue(takeaway.contains("held steady"), takeaway)
    }

    func testTakeawayFormatsInImperialUnitsWhenSelected() {
        // 5 kg down ≈ 11.0 lbs.
        let logs = [log(90, daysAgo: 21), log(88, daysAgo: 14), log(86, daysAgo: 7), log(85, daysAgo: 0)]
        let takeaway = WeightTrendEngine.takeaway(for: logs, units: .imperial)
        XCTAssertTrue(takeaway.contains("lbs"), takeaway)
    }
}

final class ShotDayEatingTakeawayTests: XCTestCase {
    private func insight(day: Int, protein: Double?, samples: Int) -> CycleDayInsight {
        CycleDayInsight(
            cycleDay: day, sampleCount: samples, averageProteinG: protein, averageCalories: nil,
            averageWaterMl: nil, averageWorkoutMinutes: nil, averageAppetite: nil, averageEnergy: nil,
            averageNausea: nil, averageWeightKg: nil, nutritionSampleCount: samples, hydrationSampleCount: 0,
            movementSampleCount: 0, checkInSampleCount: 0, weightSampleCount: 0
        )
    }

    func testEmptyInsightsInviteMoreLogging() {
        XCTAssertEqual(ShotDayEatingTakeaway.build(insights: []), "Log a few days around your shots to see a pattern here.")
    }

    func testNamesTheStrongestProteinDayAndSampleSize() {
        let insights = [
            insight(day: 0, protein: 90, samples: 3),
            insight(day: 3, protein: 140, samples: 2),
            insight(day: 6, protein: 100, samples: 4),
        ]
        XCTAssertEqual(
            ShotDayEatingTakeaway.build(insights: insights),
            "Protein has tended to be highest around day 3 of your dose cycle, from 9 logged days."
        )
    }

    func testFallsBackToASampleCountWhenNoProteinDataExists() {
        let insights = [insight(day: 0, protein: nil, samples: 2)]
        XCTAssertEqual(ShotDayEatingTakeaway.build(insights: insights), "Based on 2 logged days across your dose cycle.")
    }
}

final class NutritionSummaryTakeawayTests: XCTestCase {
    func testNoLoggedDaysSaysSo() {
        XCTAssertEqual(
            NutritionSummaryTakeaway.build(loggedDayCount: 0, avgProtein: 0, goalProtein: 130, avgCalories: 0, goalCalories: 1600),
            "No days logged in this range yet."
        )
    }

    func testWithAGoalReportsPercentOfGoal() {
        let text = NutritionSummaryTakeaway.build(loggedDayCount: 5, avgProtein: 104, goalProtein: 130, avgCalories: 1500, goalCalories: 1600)
        XCTAssertTrue(text.contains("80% of your 130g protein goal"), text)
        XCTAssertTrue(text.contains("1500 of 1600 kcal"), text)
        XCTAssertTrue(text.contains("5 logged days"), text)
    }

    func testWithoutAGoalReportsRawAverages() {
        let text = NutritionSummaryTakeaway.build(loggedDayCount: 1, avgProtein: 90, goalProtein: nil, avgCalories: 1400, goalCalories: nil)
        XCTAssertTrue(text.contains("90g of protein a day"), text)
        XCTAssertTrue(text.contains("1400 kcal a day"), text)
        XCTAssertTrue(text.contains("1 logged day:"), text)
    }
}

final class MovementTakeawayTests: XCTestCase {
    func testNoActiveDaysSaysSo() {
        XCTAssertEqual(MovementTakeaway.build(activeDayCount: 0, totalDayCount: 7, sessions: 0, avgMinutes: 0), "No movement logged in this range yet.")
    }

    func testReportsActiveDaysSessionsAndAverage() {
        let text = MovementTakeaway.build(activeDayCount: 4, totalDayCount: 7, sessions: 5, avgMinutes: 32.6)
        XCTAssertEqual(text, "You moved on 4 of 7 days — 5 sessions, averaging 33 min on active days.")
    }
}

final class BodyFatTrendTakeawayTests: XCTestCase {
    func testNoReadingsSaysSo() {
        XCTAssertEqual(BodyFatTrendTakeaway.build(logs: []), "No body fat readings in this range yet.")
    }

    func testOneReadingIsTooEarlyForATrend() {
        XCTAssertEqual(BodyFatTrendTakeaway.build(logs: [(date: .now, pct: 24.0)]), "One reading logged — too early to see a trend.")
    }

    func testReportsTheChangeAcrossReadings() {
        let logs = [(date: Date.now.addingTimeInterval(-14 * 86_400), pct: 26.0), (date: Date.now, pct: 24.5)]
        let text = BodyFatTrendTakeaway.build(logs: logs)
        XCTAssertEqual(text, "Body fat is down 1.5% across 2 readings.")
    }
}
