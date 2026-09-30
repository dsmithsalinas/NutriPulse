import Foundation

/// The "gentle cap" on simultaneously active goals (docs/daylight-redesign.md): past a few
/// active goals, adding more tends to make all of them stick less. This never blocks creation —
/// it just pauses Create a goal with a calm note, alongside an "Add anyway" that always works.
enum GoalCreationPolicy {
    static let suggestedActiveGoalLimit = 3

    /// Whether creating one more goal should pause for a gentle note, given how many are
    /// already active.
    static func shouldWarnBeforeAdding(activeGoalCount: Int, limit: Int = suggestedActiveGoalLimit) -> Bool {
        activeGoalCount >= limit
    }
}
