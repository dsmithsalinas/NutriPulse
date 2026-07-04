import Observation
import Foundation

// SWIFT CONCEPT — @Observable + @MainActor together: all property reads/writes and
// method calls happen on the main thread, so SwiftUI view updates are always safe.
// Think of @MainActor as a compile-time guarantee that replaces manual DispatchQueue.main.async calls.

@Observable
@MainActor
final class TodayViewModel {
    private let foodLogRepo = FoodLogRepository()
    private let goalRepo    = GoalRepository()
    private let waterRepo   = WaterRepository()

    var selectedDate: Date = .now
    var foodLogs: [FoodLog]   = []
    var dailyGoal: DailyGoal? = nil
    var isLoading             = false
    var errorMessage: String? = nil

    // SWIFT CONCEPT — computed properties (no `var` body, just `{ ... }`) are recalculated
    // every time they're read. @Observable knows which stored properties they depend on
    // and re-renders only the views that actually read these computed values.

    var logsByMeal: [Meal: [FoodLog]] {
        Dictionary(grouping: foodLogs, by: \.meal)
    }

    var totalCalories: Double { foodLogs.reduce(0) { $0 + $1.totalCalories } }
    var totalProteinG: Double { foodLogs.reduce(0) { $0 + $1.totalProteinG } }
    var totalCarbsG:   Double { foodLogs.reduce(0) { $0 + $1.totalCarbsG   } }
    var totalFiberG:   Double { foodLogs.reduce(0) { $0 + $1.totalFiberG   } }

    var isToday: Bool { selectedDate.isToday }

    // Water tracking
    var waterIntakeMl: Double = 0
    var waterGoalMl:   Double = 2000

    // HealthKit data for the selected date
    var activeCalories: Double  = 0
    var restingHeartRate: Double? = nil
    var hrv: Double?            = nil
    var sleepHours: Double?     = nil

    var netCalories: Double { totalCalories - activeCalories }
    var healthDataAvailable: Bool {
        activeCalories > 0 || restingHeartRate != nil || hrv != nil || sleepHours != nil
    }

    func loadData() async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }  // runs when the function exits for any reason

        do {
            // SWIFT CONCEPT — `async let` runs both requests concurrently (like Promise.all).
            // Without it, `await logsTask` would block while goals sat idle.
            async let logsTask  = foodLogRepo.fetchLogs(for: selectedDate)
            async let goalTask  = goalRepo.fetchGoal(for: selectedDate)
            async let waterTask = waterRepo.fetchTotal(for: selectedDate)
            let (logs, goal, water) = try await (logsTask, goalTask, waterTask)
            foodLogs      = logs
            dailyGoal     = goal
            waterIntakeMl = water
            waterGoalMl   = goal?.waterMlTarget ?? 2000
        } catch {
            errorMessage = error.localizedDescription
        }
        await loadHealthData()
    }

    func loadHealthData() async {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else { return }
        try? await hk.requestAuthorization()
        async let cal    = hk.fetchActiveCalories(for: selectedDate)
        async let hr     = hk.fetchRestingHeartRate(for: selectedDate)
        async let hrvVal = hk.fetchHRV(for: selectedDate)
        async let sleep  = hk.fetchSleepHours(for: selectedDate)
        let (calories, heartRate, heartRateVar, sleepTime) = await (cal, hr, hrvVal, sleep)
        activeCalories   = calories
        restingHeartRate = heartRate
        hrv              = heartRateVar
        sleepHours       = sleepTime
    }

    func addWater(_ ml: Double) async {
        do {
            try await waterRepo.add(ml, for: selectedDate)
            waterIntakeMl += ml
        } catch {
            errorMessage = "Couldn't log water."
        }
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    func goToNextDay() {
        guard !selectedDate.isToday else { return }  // don't navigate into the future
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    func goToToday() { selectedDate = .now }
}
