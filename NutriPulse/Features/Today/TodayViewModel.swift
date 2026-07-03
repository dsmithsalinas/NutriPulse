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

    func loadData() async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }  // runs when the function exits for any reason

        do {
            // SWIFT CONCEPT — `async let` runs both requests concurrently (like Promise.all).
            // Without it, `await logsTask` would block while goals sat idle.
            async let logsTask = foodLogRepo.fetchLogs(for: selectedDate)
            async let goalTask = goalRepo.fetchGoal(for: selectedDate)
            let (logs, goal) = try await (logsTask, goalTask)
            foodLogs  = logs
            dailyGoal = goal
        } catch {
            errorMessage = error.localizedDescription
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
