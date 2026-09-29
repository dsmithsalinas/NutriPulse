import Foundation

// Pulse's weekly summary reviews the week that just ended, Monday through Sunday. Weeks here
// are ISO weeks (Monday first) regardless of the device's locale — a US-locale Calendar would
// start the week on Sunday and put Sunday's data in the wrong week. The Monday notification
// belongs to Your Strong Week (StrongWeekReminder); this only decides when Pulse writes the
// summary once the user opens the Pulse tab.
enum WeeklyRecapSchedule {
    static let firstRecapWeekday = 2     // Calendar weekday: Sunday = 1, Monday = 2
    // A recap stays useful for the first few days of the week. Someone who doesn't open
    // Footing until Wednesday still gets last week's recap; by Thursday it's stale, and the
    // next one is only days away.
    static let lastRecapWeekday = 4      // Wednesday

    static func isoCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Start (Monday 00:00) of the week containing `date`.
    static func startOfWeek(containing date: Date, calendar: Calendar = isoCalendar()) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Whether a recap should be generated now. The old rule — "it's Sunday or Monday, and
    /// the last recap is at least six days old" — let a Sunday recap (a partial week) block
    /// Monday's, and skipped the week entirely for anyone who didn't open Pulse on those two
    /// days. Now: once per ISO week, Monday through Wednesday.
    static func isDue(now: Date, lastRecapAt: Date?, calendar: Calendar = isoCalendar()) -> Bool {
        let weekday = calendar.component(.weekday, from: now)
        // Calendar weekday numbering is fixed (Sunday = 1) even on the ISO calendar.
        guard weekday >= firstRecapWeekday, weekday <= lastRecapWeekday else { return false }
        guard let lastRecapAt else { return true }
        return lastRecapAt < startOfWeek(containing: now, calendar: calendar)
    }

    /// Monday 00:00 through Sunday (start of day) of the week before the one containing `now`,
    /// plus the start of the week before that, for a week-over-week comparison.
    static func lastWeek(before now: Date, calendar: Calendar = isoCalendar()) -> (start: Date, end: Date, priorStart: Date) {
        let thisWeek = startOfWeek(containing: now, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -7, to: thisWeek)!
        let end = calendar.date(byAdding: .day, value: -1, to: thisWeek)!
        let priorStart = calendar.date(byAdding: .day, value: -14, to: thisWeek)!
        return (start, end, priorStart)
    }
}

enum WeeklyRecapDigest {
    /// Foods the user logged more than once, most frequent first — "Greek yogurt (4×)".
    /// This is what lets Pulse suggest from their actual routine instead of generic
    /// "lean protein" advice. One-offs are left out: they aren't a pattern.
    static func frequentFoods(_ names: [String], limit: Int = 6) -> [String] {
        var counts: [String: (display: String, count: Int)] = [:]
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "Unknown food" else { continue }
            let key = trimmed.lowercased()
            counts[key, default: (trimmed, 0)].count += 1
        }
        return counts.values
            .filter { $0.count >= 2 }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.display < $1.display }
            .prefix(limit)
            .map { "\($0.display) (\($0.count)×)" }
    }

    /// Builds the `lastWeek` block Pulse writes the Monday recap from. `summaries` and
    /// `movement` may cover a wider window; only days inside [start, end] are used for the
    /// week itself and [priorStart, start) for the comparison.
    static func build(
        interval: (start: Date, end: Date, priorStart: Date),
        summaries: [DailySummary],
        movement: [DailyMovement],
        weightLogs: [WeightLog],
        checkIns: [ShotCycleCheckIn],
        foodNames: [String],
        proteinGoal: Double?,
        calendar: Calendar = WeeklyRecapSchedule.isoCalendar()
    ) -> CoachContextBundle.LastWeekContext {
        let week = summaries.filter { $0.date >= interval.start && $0.date <= interval.end }
        let prior = summaries.filter { $0.date >= interval.priorStart && $0.date < interval.start }
        let weekMovement = movement.filter { $0.date >= interval.start && $0.date <= interval.end }

        func floorHit(_ day: DailySummary) -> Bool? {
            guard let goal = proteinGoal, goal > 0, day.hasData else { return nil }
            return day.proteinG >= goal
        }
        func average(_ days: [DailySummary], _ value: (DailySummary) -> Double) -> Int? {
            let logged = days.filter(\.hasData)
            guard !logged.isEmpty else { return nil }
            return Int((logged.reduce(0) { $0 + value($1) } / Double(logged.count)).rounded())
        }

        let checkInsByDate = Dictionary(checkIns.map { ($0.checkinDate, $0) }, uniquingKeysWith: { a, _ in a })
        let movementByDate = Dictionary(weekMovement.map { ($0.date.isoDateString, $0) }, uniquingKeysWith: { a, _ in a })

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE MMM d"

        let days: [CoachContextBundle.LastWeekContext.Day] = week.map { day in
            let key = day.date.isoDateString
            let checkIn = checkInsByDate[key]
            let minutes = movementByDate[key].map { Int($0.minutes.rounded()) }
            return .init(
                day: dayFormatter.string(from: day.date),
                logged: day.hasData,
                calories: day.hasData ? Int(day.calories.rounded()) : nil,
                proteinG: day.hasData ? Int(day.proteinG.rounded()) : nil,
                proteinFloorHit: floorHit(day),
                workoutMinutes: (minutes ?? 0) > 0 ? minutes : nil,
                cycleDay: checkIn?.cycleDay,
                appetite: checkIn?.appetite
            )
        }

        let weekWeights = weightLogs
            .filter { $0.loggedAt >= interval.start && $0.loggedAt < calendar.date(byAdding: .day, value: 1, to: interval.end)! }
            .sorted { $0.loggedAt < $1.loggedAt }
        let weightChange: String? = {
            guard weekWeights.count >= 2, let first = weekWeights.first, let last = weekWeights.last else { return nil }
            let delta = last.weightKg - first.weightKg
            return "\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta)) kg across \(weekWeights.count) weigh-ins"
        }()

        let rangeFormatter = DateFormatter()
        rangeFormatter.dateFormat = "MMM d"
        let priorLogged = prior.filter(\.hasData)

        return .init(
            range: "\(rangeFormatter.string(from: interval.start)) – \(rangeFormatter.string(from: interval.end))",
            daysLogged: week.filter(\.hasData).count,
            proteinFloorDays: proteinGoal.map { _ in week.compactMap(floorHit).filter { $0 }.count },
            avgCalories: average(week, \.calories),
            avgProteinG: average(week, \.proteinG),
            workoutSessions: weekMovement.reduce(0) { $0 + $1.sessions },
            workoutMinutes: Int(weekMovement.reduce(0) { $0 + $1.minutes }.rounded()),
            weightChange: weightChange,
            frequentFoods: frequentFoods(foodNames),
            days: days,
            priorWeek: priorLogged.isEmpty ? nil : .init(
                daysLogged: priorLogged.count,
                proteinFloorDays: proteinGoal.map { _ in prior.compactMap(floorHit).filter { $0 }.count },
                avgProteinG: average(prior, \.proteinG)
            )
        )
    }
}
