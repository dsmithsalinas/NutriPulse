import Observation
import Foundation

@Observable
@MainActor
final class AnalyticsViewModel {

    enum TimeRange: Int, CaseIterable, Identifiable, Hashable {
        case week     = 7
        case twoWeeks = 14
        case month    = 30

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .week:     return "7 days"
            case .twoWeeks: return "14 days"
            case .month:    return "30 days"
            }
        }
    }

    var selectedRange: TimeRange = .week
    var summaries: [DailySummary] = []
    var weightLogs: [WeightLog]   = []
    var goalCalories: Double?     = nil
    var isLoading                 = false
    var errorMessage: String?     = nil

    private let repo     = AnalyticsRepository()
    private let goalRepo = GoalRepository()

    // Only count days where the user actually logged something
    var loggedDays: [DailySummary] { summaries.filter(\.hasData) }

    var averageCalories: Double {
        guard !loggedDays.isEmpty else { return 0 }
        return loggedDays.reduce(0) { $0 + $1.calories } / Double(loggedDays.count)
    }

    var weightChange: Double? {
        guard weightLogs.count >= 2 else { return nil }
        return weightLogs.last!.weightKg - weightLogs.first!.weightKg
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let summariesTask = repo.fetchDailySummaries(days: selectedRange.rawValue)
            async let weightTask    = repo.fetchWeightLogs(days: selectedRange.rawValue)
            async let goalTask      = goalRepo.fetchGoal(for: .now)
            let (s, w, g) = try await (summariesTask, weightTask, goalTask)
            summaries    = s
            weightLogs   = w
            goalCalories = g?.calories
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
