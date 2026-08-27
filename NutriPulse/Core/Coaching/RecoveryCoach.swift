import Foundation

struct RecoveryOpportunity: Equatable {
    let workoutName: String
    let durationMinutes: Int
    let proteinGap: Int
    let waterGapMl: Int
    let finishedAt: Date

    var hasGap: Bool { proteinGap > 0 || waterGapMl > 0 }
}

enum RecoveryCoach {
    // A workout remains actionable for six hours. After that, the normal day-level nudge is
    // the more honest surface; calling breakfast "post-workout recovery" after an evening
    // session would feel automated rather than attentive.
    static func opportunity(
        workouts: [WorkoutLog],
        goal: DailyGoal?,
        proteinToday: Double,
        waterTodayMl: Double,
        now: Date = .now,
        actionWindowHours: Double = 6
    ) -> RecoveryOpportunity? {
        guard let goal, let workout = workouts.max(by: { $0.startedAt < $1.startedAt }) else { return nil }
        let finished = workout.startedAt.addingTimeInterval(workout.durationMinutes * 60)
        let age = now.timeIntervalSince(finished)
        guard age >= -15 * 60, age <= actionWindowHours * 3600 else { return nil }

        return RecoveryOpportunity(
            workoutName: workout.displayName,
            durationMinutes: Int(workout.durationMinutes.rounded()),
            proteinGap: max(Int((goal.proteinG - proteinToday).rounded()), 0),
            waterGapMl: max(Int((goal.waterMlTarget - waterTodayMl).rounded()), 0),
            finishedAt: finished
        )
    }
}

struct ProteinRescueOption: Identifiable {
    let id: String
    let foods: [FavoriteQuickAdd]
    let proteinG: Int
    let calories: Int

    var title: String { foods.map(\.name).joined(separator: " + ") }
}

enum ProteinRescuePlanner {
    // Rank one- and two-food combinations by how closely they close the gap, with a modest
    // penalty for extra calories and for still falling short. Suggestions come only from
    // the user's own favorites, so every result is familiar and immediately loggable.
    static func options(
        favorites: [FavoriteQuickAdd],
        proteinGap: Int,
        calorieRoom: Int,
        limit: Int = 3
    ) -> [ProteinRescueOption] {
        let candidates = favorites.filter { $0.proteinGSnapshot * $0.quantity >= 5 }
        guard !candidates.isEmpty, proteinGap > 0 else { return [] }

        var groups = candidates.map { [$0] }
        if candidates.count > 1 {
            for left in candidates.indices {
                for right in candidates.indices where right > left {
                    groups.append([candidates[left], candidates[right]])
                }
            }
        }

        func make(_ foods: [FavoriteQuickAdd]) -> ProteinRescueOption {
            let protein = Int(foods.reduce(0) { $0 + $1.proteinGSnapshot * $1.quantity }.rounded())
            let calories = Int(foods.reduce(0) { $0 + $1.caloriesSnapshot * $1.quantity }.rounded())
            let id = foods.map { $0.foodItemId.uuidString }.sorted().joined(separator: ":")
            return ProteinRescueOption(id: id, foods: foods, proteinG: protein, calories: calories)
        }

        func score(_ option: ProteinRescueOption) -> Double {
            let shortfall = max(proteinGap - option.proteinG, 0)
            let excess = max(option.proteinG - proteinGap, 0)
            let calorieOverflow = max(option.calories - max(calorieRoom, 0), 0)
            return Double(shortfall * 5 + excess + calorieOverflow / 8 + (option.foods.count - 1) * 3)
        }

        return groups.map(make)
            .sorted { score($0) < score($1) }
            .prefix(limit)
            .map { $0 }
    }
}
