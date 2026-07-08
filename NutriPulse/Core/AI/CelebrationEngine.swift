import Foundation

// Client-side, zero-cost "win" detection — Swift computes the facts from data
// already on hand; Claude just narrates them naturally when the user is already
// talking to it. Never a dedicated API call just to notice a win. See
// ENHANCEMENTS.md Phase 1B.
enum CelebrationEngine {
    // Once a user has logged on this many distinct days, celebration shifts from
    // "you showed up" (habit) to "you hit the target" (outcome) — reward the easy
    // win early, the real win once the habit is established.
    static let establishedThresholdDays = 7

    // `history` must be ordered ascending by date with the most recent day last.
    static func detectWins(goal: DailyGoal?, history: [DailySummary]) -> [String] {
        guard let goal, let today = history.last, today.hasData else { return [] }
        var wins: [String] = []

        // Same definition the Today screen's haptic uses — calories and carbs are ceilings,
        // protein and fiber are floors. See DailyGoal.ringsClosed.
        let allRingsClosed = goal.ringsClosed(
            calories: today.calories,
            proteinG: today.proteinG,
            carbsG:   today.carbsG,
            fiberG:   today.fiberG
        )
        if allRingsClosed {
            wins.append("Closed every ring today — calories landed in range, and protein, carbs, and fiber all hit.")
        }

        let loggedDaysInWindow = history.filter(\.hasData).count
        let isEstablished = loggedDaysInWindow >= establishedThresholdDays

        if isEstablished {
            let streak = trailingStreak(history) { $0.proteinG >= goal.proteinG }
            if streak >= 2 {
                wins.append("\(streak) days in a row hitting the protein target.")
            }
        } else {
            let streak = trailingStreak(history, matching: \.hasData)
            if streak >= 2 {
                wins.append("\(streak) days in a row showing up and logging — the habit is taking hold.")
            }
        }

        // `history` is only the last 30 days (CoachContextBuilder fetches 30), so "ever" was
        // a claim the data can't support: hit fiber in month one, lapse for 31 days, hit it
        // again, and Pulse confidently announced a first-time achievement — the prompt tells
        // Claude these are "real, already-detected accomplishments". Say what we actually know.
        let priorFiberHits = history.dropLast().filter { $0.fiberG >= goal.fiberG }.count
        if today.fiberG >= goal.fiberG, priorFiberHits == 0 {
            wins.append("First fiber-goal hit in the last 30 days.")
        }

        return wins
    }

    private static func trailingStreak(_ days: [DailySummary], matching predicate: (DailySummary) -> Bool) -> Int {
        var streak = 0
        for day in days.reversed() {
            guard predicate(day) else { break }
            streak += 1
        }
        return streak
    }
}
