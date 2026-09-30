import Foundation

/// A goal card's win, worth a brief celebration: reaching its target for a finished period, or a
/// streak crossing one of a few round milestones.
enum GoalWinKind: Equatable {
    case completed
    case streak(days: Int)
}

/// Win detection is pure — the caller (`GoalsViewModel`) decides whether a given win has already
/// been shown, via `alreadyCelebrated`, and is the one that persists that decision (`GoalWinStore`).
enum GoalWins {
    /// Streak lengths worth calling out. Exact matches only, so the celebration fires the day a
    /// streak reaches one of these numbers, not every day afterward that it stays above it.
    static let milestoneDays: [Int] = [7, 14, 30]

    enum Keys {
        static let completed = "completed"
        static func streak(_ days: Int) -> String { "streak-\(days)" }
    }

    /// The win to celebrate right now, if any, given this goal's current status and streak and
    /// the set of win keys already shown for it.
    ///
    /// `completed` reflects the goal's live progress status (e.g. `== .met`), not a stored
    /// "was this ever met" flag, so it naturally stops firing once the goal is no longer freshly
    /// met without any extra bookkeeping here.
    static func newWin(
        completed: Bool,
        currentStreak: Int,
        alreadyCelebrated: Set<String>
    ) -> (kind: GoalWinKind, key: String)? {
        if completed, !alreadyCelebrated.contains(Keys.completed) {
            return (.completed, Keys.completed)
        }
        if milestoneDays.contains(currentStreak) {
            let key = Keys.streak(currentStreak)
            if !alreadyCelebrated.contains(key) {
                return (.streak(days: currentStreak), key)
            }
        }
        return nil
    }
}

/// Persists which wins have already been shown, so a milestone or completion celebrates once.
/// Keyed by goal id (including `ProteinFloorGoal.syntheticGoalID` for the built-in floor card),
/// then by win key (`GoalWins.Keys`).
struct GoalWinStore {
    private let defaults: UserDefaults
    private static let storageKey = "goalWins.celebrated"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func celebrated(for goalID: UUID) -> Set<String> {
        Set(allCelebrated()[goalID.uuidString] ?? [])
    }

    func markCelebrated(_ key: String, for goalID: UUID) {
        var all = allCelebrated()
        var forGoal = Set(all[goalID.uuidString] ?? [])
        forGoal.insert(key)
        all[goalID.uuidString] = Array(forGoal)
        defaults.set(all, forKey: Self.storageKey)
    }

    private func allCelebrated() -> [String: [String]] {
        (defaults.dictionary(forKey: Self.storageKey) as? [String: [String]]) ?? [:]
    }
}
