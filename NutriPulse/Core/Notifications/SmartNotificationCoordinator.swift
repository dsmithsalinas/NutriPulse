import Foundation

@MainActor
final class SmartNotificationCoordinator {
    static let shared = SmartNotificationCoordinator()
    private init() {}

    // Background-safe recovery evaluation. Everything needed for the decision is either
    // in HealthKit or Footing's local-first store; no foreground view model is required.
    func evaluateAfterWorkout(now: Date = .now) async {
        guard UserDefaults.standard.bool(forKey: NotificationManager.smartCoachingEnabledKey),
              let userId = try? await supabase.auth.session.user.id else { return }

        async let workoutTask = HealthKitManager.shared.fetchWorkouts(for: now)
        let goal: DailyGoal?
        if let local = try? LocalStore.shared.fetchGoal(for: now, userId: userId) {
            goal = local
        } else {
            goal = try? await GoalRepository().fetchGoal(for: now)
        }
        guard let goal else { return }

        let logs = (try? LocalStore.shared.fetchFoodLogs(for: now, userId: userId)) ?? []
        let protein = logs.reduce(0) { $0 + $1.totalProteinG }
        let water = (try? LocalStore.shared.fetchWaterTotal(for: now, userId: userId)) ?? 0
        guard let latest = (await workoutTask).max(by: { $0.startDate < $1.startDate }) else { return }

        let workout = WorkoutLog(
            id: UUID(uuidString: latest.uuid) ?? UUID(),
            userId: userId,
            loggedAt: latest.startDate,
            logDate: latest.startDate.isoDateString,
            activityType: latest.activitySlug,
            durationMinutes: latest.durationMinutes,
            activeCalories: latest.activeCalories,
            distanceMeters: latest.distanceMeters,
            source: .healthkit,
            healthKitUUID: latest.uuid,
            startedAt: latest.startDate
        )
        let recovery = RecoveryCoach.opportunity(
            workouts: [workout],
            goal: goal,
            proteinToday: protein,
            waterTodayMl: water,
            now: now,
            actionWindowHours: 1.5
        )
        let preferences = SmartNotificationPreferences.load()
        let opportunity = SmartNotificationEngine.bestOpportunity(
            recovery: recovery,
            proteinGap: max(Int((goal.proteinG - protein).rounded()), 0),
            calorieRoom: max(Int((goal.calories - logs.reduce(0) { $0 + $1.totalCalories }).rounded()), 0),
            rescueOptions: [],
            repeatedMeal: nil,
            enabledKinds: preferences.enabledKinds,
            quietStartHour: preferences.quietStartHour,
            quietEndHour: preferences.quietEndHour,
            now: now
        )
        await NotificationManager.shared.scheduleSmartOpportunity(opportunity)
    }
}
