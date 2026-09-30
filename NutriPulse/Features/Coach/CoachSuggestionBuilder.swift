import Foundation

/// One tile in "Suggested for right now" on Pulse's start screen. Built on the device from
/// today's data — no model call until the user taps one.
struct PulseStartSuggestion: Identifiable, Equatable {
    enum Kind: Equatable {
        case proteinGap
        case shotCycle
        case mondayRecap
        case meal
        case experimentCheckIn
    }

    let kind: Kind
    /// The small line above the prompt: "28g to go", "Shot day 3", "It's Tuesday".
    let eyebrow: String
    /// What the tile says, and (except for the recap) exactly what gets sent to Pulse.
    let prompt: String

    var id: Kind { kind }
}

/// What `startSuggestions` needs to offer today's check-in for a running personal experiment.
/// `hasCheckedInToday` hides the tile once it's done, the same way the protein-gap tile hides
/// once the gap closes.
struct ExperimentCheckInPrompt: Equatable {
    let dayIndex: Int
    let totalDays: Int?
    let hasCheckedInToday: Bool
}

struct CoachSuggestionBuilder {
    /// The start screen's tiles, most specific first, two or three of them.
    /// - Parameters:
    ///   - cycleDay: days since the last shot (0 = shot day); nil with no dose history or
    ///     when the cycle is interrupted by a skipped dose.
    ///   - recapDue: `WeeklyRecapSchedule.isDue` against the last recap Pulse wrote, so the
    ///     Monday Recap tile disappears once this week's recap exists.
    static func startSuggestions(
        totalProteinG: Double,
        proteinGoalG: Double?,
        cycleDay: Int?,
        recapDue: Bool,
        now: Date,
        calendar: Calendar = .current,
        experimentCheckIn: ExperimentCheckInPrompt? = nil
    ) -> [PulseStartSuggestion] {
        var tiles: [PulseStartSuggestion] = []
        let hour = calendar.component(.hour, from: now)

        // Most actionable, most specific: a running experiment waiting on today's check-in.
        if let experimentCheckIn, !experimentCheckIn.hasCheckedInToday {
            let eyebrow = experimentCheckIn.totalDays.map { "Experiment · day \(experimentCheckIn.dayIndex) of \($0)" }
                ?? "Experiment · day \(experimentCheckIn.dayIndex)"
            tiles.append(.init(kind: .experimentCheckIn, eyebrow: eyebrow, prompt: "Log today's check-in"))
        }

        if let goal = proteinGoalG, goal > 0 {
            let gap = Int((goal - totalProteinG).rounded())
            if gap > 15 {
                tiles.append(.init(
                    kind: .proteinGap,
                    eyebrow: "\(gap)g to go",
                    prompt: "Give me an easy \(mealName(hour: hour)) to close my protein"
                ))
            }
        }

        if let cycleDay {
            tiles.append(.init(
                kind: .shotCycle,
                eyebrow: cycleDay == 0 ? "Shot day" : "Shot day \(cycleDay)",
                prompt: shotCyclePrompt(cycleDay: cycleDay)
            ))
        }

        if recapDue {
            var english = calendar
            english.locale = Locale(identifier: "en_US")
            let weekday = english.weekdaySymbols[english.component(.weekday, from: now) - 1]
            tiles.append(.init(kind: .mondayRecap, eyebrow: "It's \(weekday)", prompt: "Monday Recap"))
        }

        // Never an empty or lonely grid: pad with a meal idea for the time of day.
        if tiles.count < 2 {
            tiles.append(.init(
                kind: .meal,
                eyebrow: mealName(hour: hour).capitalized,
                prompt: mealPrompt(hour: hour)
            ))
        }

        return Array(tiles.prefix(3))
    }

    /// The fixed "Or talk about" chips: the label shown, and the fuller prompt sent.
    static let topics: [(label: String, prompt: String)] = [
        ("Meal ideas", "Give me a few meal ideas that fit my goals"),
        ("How I'm trending", "Show me how I'm trending lately"),
        ("Eating out", "Help me order well when I eat out"),
        ("Workouts & recovery", "Help me eat around my workouts and recovery"),
    ]

    private static func mealName(hour: Int) -> String {
        switch hour {
        case ..<11: return "breakfast"
        case 11..<15: return "lunch"
        case 15..<17: return "snack"
        default: return "dinner"
        }
    }

    private static func mealPrompt(hour: Int) -> String {
        switch hour {
        case ..<11: return "Give me an easy protein breakfast"
        case 11..<15: return "Give me a protein-forward lunch"
        case 15..<17: return "Give me a protein snack idea"
        default: return "Give me a dinner idea"
        }
    }

    // Appetite is usually lowest in the first few days after a shot and returns later in the
    // week, so the prompt follows the cycle rather than repeating one line all week.
    private static func shotCyclePrompt(cycleDay: Int) -> String {
        switch cycleDay {
        case 0: return "Help me plan around today's shot"
        case 1...3: return "Help me get protein in when I'm not hungry"
        default: return "Make the most of my appetite this week"
        }
    }

    // MARK: - In-conversation pills

    /// The follow-up pills above the composer once a conversation is going.
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
