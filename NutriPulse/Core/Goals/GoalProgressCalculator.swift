import Foundation

enum GoalDayState: Equatable {
    case met, notMet, missing, pending
}

enum GoalProgressStatus: String, Codable {
    case met, notMet = "not_met", pending, missing
    case onTrack = "on_track", offTrack = "off_track"
    case insufficientData = "insufficient_data"
}

struct GoalDailyValue: Equatable {
    let date: Date
    let boolean: Bool?
    let number: Double?
    let displayValue: Double?
    let displayTarget: Double?

    init(
        date: Date,
        boolean: Bool,
        displayValue: Double? = nil,
        displayTarget: Double? = nil
    ) {
        self.date = date
        self.boolean = boolean
        self.number = nil
        self.displayValue = displayValue
        self.displayTarget = displayTarget
    }

    init(date: Date, number: Double) {
        self.date = date
        self.boolean = nil
        self.number = number
        self.displayValue = nil
        self.displayTarget = nil
    }
}

struct GoalProgressSummary {
    let status: GoalProgressStatus
    let value: Double?
    let target: Double?
    let measuredCount: Int
    let expectedCount: Int
    let metCount: Int
    let missedCount: Int
    let currentStreak: Int
    let days: [(Date, GoalDayState)]

    var coverage: Double {
        guard expectedCount > 0 else { return 0 }
        return Double(measuredCount) / Double(expectedCount)
    }
}

enum GoalProgressCalculator {
    static let algorithmVersion = 1

    static func calculate(
        version: GoalVersion,
        measurement: GoalMeasurement,
        values: [GoalDailyValue],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> GoalProgressSummary {
        let goalStart = parse(version.startDate, calendar: calendar) ?? calendar.startOfDay(for: today)
        let goalEnd = version.endDate.flatMap { parse($0, calendar: calendar) }
        let window = calculationWindow(
            period: version.period, goalStart: goalStart, goalEnd: goalEnd,
            today: today, calendar: calendar
        )
        let start = window.start
        let configuredEnd = window.end
        let visibleEnd = min(configuredEnd, today)
        let scheduled = scheduledDates(
            from: start, through: visibleEnd,
            weekdays: Set(version.scheduledWeekdays), calendar: calendar
        )
        let allScheduled = scheduledDates(
            from: start, through: configuredEnd,
            weekdays: Set(version.scheduledWeekdays), calendar: calendar
        )

        let latestByDay = Dictionary(grouping: values) { calendar.startOfDay(for: $0.date) }
            .compactMapValues { rows in rows.sorted { $0.date < $1.date }.last }
        let todayStart = calendar.startOfDay(for: today)

        let states: [(Date, GoalDayState)] = scheduled.map { date in
            guard date <= todayStart else { return (date, .pending) }
            guard let value = latestByDay[date] else { return (date, .missing) }
            return (date, isMet(value, measurement: measurement) ? .met : .notMet)
        }

        let measuredValues = scheduled.compactMap { latestByDay[$0] }
        let measured = measuredValues.count
        let met = states.filter { $0.1 == .met }.count
        let missed = states.filter { $0.1 == .notMet }.count
        let aggregate = aggregateValue(measuredValues, measurement: measurement)
        let enoughCoverage = scheduled.isEmpty
            ? false
            : Double(measured) / Double(scheduled.count) >= measurement.minimumCoverage

        let status: GoalProgressStatus
        if measured == 0 {
            status = .missing
        } else if !enoughCoverage {
            status = .insufficientData
        } else if measurement.comparison == .none {
            status = .pending
        } else if version.period != .ongoing && configuredEnd <= todayStart {
            status = aggregateMeetsTarget(aggregate, measurement: measurement) ? .met : .notMet
        } else if isOnTrack(
            aggregate: aggregate,
            values: measuredValues,
            measurement: measurement,
            elapsedOpportunities: scheduled.count,
            totalOpportunities: allScheduled.count
        ) {
            status = .onTrack
        } else {
            status = .offTrack
        }

        return GoalProgressSummary(
            status: status,
            value: aggregate,
            target: measurement.targetValue,
            measuredCount: measured,
            expectedCount: scheduled.count,
            metCount: met,
            missedCount: missed,
            currentStreak: confirmedStreak(states),
            days: states
        )
    }

    private static func isMet(_ value: GoalDailyValue, measurement: GoalMeasurement) -> Bool {
        if let boolean = value.boolean { return boolean }
        guard let number = value.number else { return false }
        guard let target = measurement.targetValue else { return true }
        switch measurement.comparison {
        case .equal: return number == target
        case .atLeast, .reach, .increase: return number >= target
        case .atMost, .decrease: return number <= target
        case .none: return true
        }
    }

    private static func aggregateValue(
        _ values: [GoalDailyValue], measurement: GoalMeasurement
    ) -> Double? {
        switch measurement.aggregation {
        case .rate:
            guard !values.isEmpty else { return nil }
            return Double(values.filter { isMet($0, measurement: measurement) }.count) / Double(values.count)
        case .count:
            if values.contains(where: { $0.boolean != nil }) {
                return Double(values.filter { $0.boolean == true }.count)
            }
            return Double(values.filter { ($0.number ?? 0) > 0 }.count)
        case .sum:
            let numbers = values.compactMap(\.number)
            return numbers.isEmpty ? nil : numbers.reduce(0, +)
        case .average:
            let numbers = values.compactMap(\.number)
            return numbers.isEmpty ? nil : numbers.reduce(0, +) / Double(numbers.count)
        case .latest:
            return values.last?.number
        }
    }

    private static func aggregateMeetsTarget(
        _ value: Double?, measurement: GoalMeasurement
    ) -> Bool {
        guard let value else { return false }
        guard let target = measurement.targetValue else { return measurement.comparison == .none }
        switch measurement.comparison {
        case .equal: return value == target
        case .atLeast, .reach, .increase: return value >= target
        case .atMost, .decrease: return value <= target
        case .none: return true
        }
    }

    private static func isOnTrack(
        aggregate: Double?,
        values: [GoalDailyValue],
        measurement: GoalMeasurement,
        elapsedOpportunities: Int,
        totalOpportunities: Int
    ) -> Bool {
        guard let aggregate, let target = measurement.targetValue else { return false }
        let elapsedFraction = totalOpportunities > 0
            ? min(Double(elapsedOpportunities) / Double(totalOpportunities), 1)
            : 1

        switch measurement.kind {
        case .accumulation, .frequency:
            let targetToDate = target * elapsedFraction
            return measurement.comparison == .atMost
                ? aggregate <= targetToDate
                : aggregate >= targetToDate
        case .target:
            guard let baseline = values.compactMap(\.number).first else { return false }
            let expected = baseline + (target - baseline) * elapsedFraction
            return target >= baseline ? aggregate >= expected : aggregate <= expected
        case .habit, .average, .threshold, .subjective:
            return aggregateMeetsTarget(aggregate, measurement: measurement)
        }
    }

    // Missing data is unknown, not a failure: it is skipped when looking backward for
    // the current confirmed streak. A known miss is the only state that breaks it.
    private static func confirmedStreak(_ states: [(Date, GoalDayState)]) -> Int {
        var streak = 0
        for (_, state) in states.reversed() {
            switch state {
            case .met: streak += 1
            case .missing, .pending: continue
            case .notMet: return streak
            }
        }
        return streak
    }

    private static func scheduledDates(
        from start: Date, through end: Date, weekdays: Set<Int>, calendar: Calendar
    ) -> [Date] {
        guard start <= end else { return [] }
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let final = calendar.startOfDay(for: end)
        while cursor <= final {
            // PostgreSQL/our schema use ISO weekdays: Monday=1 ... Sunday=7.
            let appleWeekday = calendar.component(.weekday, from: cursor)
            let isoWeekday = appleWeekday == 1 ? 7 : appleWeekday - 1
            if weekdays.contains(isoWeekday) { result.append(cursor) }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return result
    }

    private static func calculationWindow(
        period: GoalPeriod,
        goalStart: Date,
        goalEnd: Date?,
        today: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let todayStart = calendar.startOfDay(for: today)
        let naturalStart: Date
        let naturalEnd: Date
        switch period {
        case .daily:
            naturalStart = todayStart
            naturalEnd = todayStart
        case .weekly:
            let interval = calendar.dateInterval(of: .weekOfYear, for: todayStart)!
            naturalStart = interval.start
            naturalEnd = calendar.date(byAdding: .day, value: -1, to: interval.end)!
        case .monthly:
            let interval = calendar.dateInterval(of: .month, for: todayStart)!
            naturalStart = interval.start
            naturalEnd = calendar.date(byAdding: .day, value: -1, to: interval.end)!
        case .annual:
            let interval = calendar.dateInterval(of: .year, for: todayStart)!
            naturalStart = interval.start
            naturalEnd = calendar.date(byAdding: .day, value: -1, to: interval.end)!
        case .custom:
            naturalStart = goalStart
            naturalEnd = goalEnd ?? todayStart
        case .ongoing:
            naturalStart = calendar.date(byAdding: .day, value: -29, to: todayStart)!
            naturalEnd = todayStart
        }

        return (
            max(goalStart, naturalStart),
            min(goalEnd ?? naturalEnd, naturalEnd)
        )
    }

    private static func parse(_ value: String, calendar: Calendar) -> Date? {
        let pieces = value.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: pieces[0], month: pieces[1], day: pieces[2]))
    }
}

enum GoalLifecycle {
    /// Goal date ranges are inclusive. A goal ending today remains active until the next
    /// local day so the user can still log or sync the final day's data.
    static func hasEnded(
        _ version: GoalVersion,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard let endDate = version.endDate.flatMap({ parse($0, calendar: calendar) }) else {
            return false
        }
        return calendar.startOfDay(for: endDate) < calendar.startOfDay(for: today)
    }

    /// Completed goals must be evaluated against their preserved historical window, not
    /// against the day the app happens to load them later.
    static func evaluationDate(
        for bundle: PersonalGoalBundle,
        fallback: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        if let endDate = bundle.version.endDate.flatMap({ parse($0, calendar: calendar) }) {
            return endDate
        }
        return bundle.goal.completedAt ?? fallback
    }

    private static func parse(_ value: String, calendar: Calendar) -> Date? {
        let pieces = value.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }
        return calendar.date(
            from: DateComponents(year: pieces[0], month: pieces[1], day: pieces[2])
        )
    }
}
