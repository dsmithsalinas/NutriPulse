import Foundation

/// The protein floor as a built-in Goals card. Every account has a protein floor
/// (`DailyGoal.proteinG`), so Goals should never present as completely empty, even before
/// anyone creates a goal of their own. This is computed fresh from local daily summaries and
/// the currently effective protein target each time Goals loads — it is never written to the
/// goals tables, and it can't be edited or deleted from Goals ("Change your floor in Profile ›
/// Daily targets" instead).
enum ProteinFloorGoal {
    /// A stable, synthetic id for the floor "goal" — used to key win-celebration state
    /// (`GoalWinStore`), since this card has no row of its own to carry a real goal id.
    static let syntheticGoalID = UUID(uuidString: "00000000-0000-0000-0000-00000000F100")!

    /// How many trailing days (including today) the grid, streak, and "logged days" count look
    /// back across.
    static let windowDays = 14

    struct DaySummary: Equatable {
        let date: Date
        let state: GoalDayState
    }

    struct Summary: Equatable {
        let floorTarget: Double
        /// Oldest to newest, always `windowDays` entries ending on `today`.
        let days: [DaySummary]
        let currentStreak: Int
        let loggedDays: Int
        let totalDays: Int
        let todayProteinG: Double
        let todayMet: Bool

        var loggedDaysLabel: String { "\(loggedDays) of \(totalDays) logged days" }

        var todayProgress: Double {
            guard floorTarget > 0 else { return 0 }
            return min(todayProteinG / floorTarget, 1)
        }

        /// "Ng to go", or "Floor cleared" once today's log meets or passes the floor.
        var todayCaption: String {
            let remaining = (floorTarget - todayProteinG).rounded(.up)
            guard remaining > 0 else { return "Floor cleared" }
            return "\(Int(remaining))g to go"
        }
    }

    /// Builds the last `windowDays` days from `summaries`, honest about what wasn't logged: a
    /// day with no usable summary reads as "no data", never as a missed day.
    ///
    /// Returns `nil` when there's no effective protein target yet — the built-in card has
    /// nothing to compute against, and the caller should simply not show it.
    static func summary(
        from summaries: [DailySummary],
        floorTarget: Double?,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Summary? {
        guard let floorTarget, floorTarget > 0 else { return nil }

        let todayStart = calendar.startOfDay(for: today)
        let latestByDay = Dictionary(grouping: summaries) { calendar.startOfDay(for: $0.date) }
            .compactMapValues { rows in rows.last }

        let days: [DaySummary] = (0..<windowDays).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - (windowDays - 1), to: todayStart)!
            guard let day = latestByDay[date], day.hasData else {
                return DaySummary(date: date, state: .missing)
            }
            return DaySummary(date: date, state: day.proteinG >= floorTarget ? .met : .notMet)
        }

        let loggedDays = days.filter { $0.state != .missing }.count
        let todaySummary = latestByDay[todayStart]
        let todayProteinG = (todaySummary?.hasData == true) ? todaySummary!.proteinG : 0

        return Summary(
            floorTarget: floorTarget,
            days: days,
            currentStreak: confirmedStreak(days),
            loggedDays: loggedDays,
            totalDays: days.count,
            todayProteinG: todayProteinG,
            todayMet: todayProteinG >= floorTarget
        )
    }

    // Same rule as GoalProgressCalculator's streak: missing data is unknown, not a failure, so
    // it's skipped looking backward from today. A confirmed miss is what breaks the streak.
    private static func confirmedStreak(_ days: [DaySummary]) -> Int {
        var streak = 0
        for day in days.reversed() {
            switch day.state {
            case .met: streak += 1
            case .missing, .pending: continue
            case .notMet: return streak
            }
        }
        return streak
    }
}
