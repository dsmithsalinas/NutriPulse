import Foundation

struct CoachSuggestionBuilder {
    static func suggestions(
        hasFoodLogs: Bool,
        totalProteinG: Double,
        proteinGoalG: Double?,
        hasWorkout: Bool,
        hour: Int,
        excluding excluded: String? = nil
    ) -> [String] {
        let mealSuggestion: String
        switch hour {
        case ..<11:
            mealSuggestion = "Give me an easy protein breakfast"
        case 11..<15:
            mealSuggestion = "Give me a protein-forward lunch"
        default:
            mealSuggestion = "Give me a dinner idea"
        }

        let proteinGap = proteinGoalG.map { $0 - totalProteinG }
        let isBehindOnProtein = proteinGap.map { $0 > 15 } ?? false

        let candidates: [String]
        if hasWorkout && isBehindOnProtein {
            candidates = [
                "Plan my recovery meal",
                "Check today's protein",
                mealSuggestion,
                "Review my week",
                "Help me plan tomorrow",
            ]
        } else if !hasFoodLogs {
            candidates = [
                "Help me plan today",
                mealSuggestion,
                "Review my goals",
                "Explain my protein target",
                "Show me my weekly pattern",
            ]
        } else if isBehindOnProtein {
            candidates = [
                "Help me close my protein gap",
                mealSuggestion,
                "Review my week",
                "Explain my protein target",
                "Help me plan tomorrow",
            ]
        } else if proteinGap != nil {
            candidates = [
                "Review today's progress",
                "What should I focus on tomorrow",
                "Show me my weekly pattern",
                "Help me plan tomorrow",
                "Review my goals",
            ]
        } else {
            candidates = [
                "Check today's progress",
                "Help with my next meal",
                "Review my week",
                "Explain my protein target",
                "Help me plan tomorrow",
            ]
        }

        return candidates.filter { $0 != excluded }.prefix(3).map { $0 }
    }
}
