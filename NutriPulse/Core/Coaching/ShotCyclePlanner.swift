import Foundation

struct ShotCyclePlan: Equatable {
    let phase: String
    let headline: String
    let actions: [String]
    let learnedPattern: String?
}

enum ShotCycleCheckInSchedule {
    static let scheduledDays: Set<Int> = [1, 3, 6]
    static let dismissedDayKey = "shotCycleCheckInDismissedDay"

    static func isDue(cycleDay: Int?, hasTodayCheckIn: Bool) -> Bool {
        guard let cycleDay else { return false }
        return scheduledDays.contains(cycleDay) && !hasTodayCheckIn
    }
}

enum ShotCyclePlanner {
    static func plan(cycleDay: Int, today: ShotCycleCheckIn?, history: [ShotCycleCheckIn]) -> ShotCyclePlan {
        let baseline: (String, String, [String])
        switch cycleDay {
        case 0:
            baseline = ("Shot day", "Set up the easy wins", [
                "Get a protein-forward meal in while appetite is available.",
                "Keep water visible and sip steadily.",
                "Put one low-volume protein option within reach for tomorrow."
            ])
        case 1...3:
            baseline = ("Low-appetite window", "Dense beats big", [
                "Start with protein before meal volume becomes a fight.",
                "Use smaller meals more often instead of forcing a full plate.",
                "Pair every eating moment with a few sips of water."
            ])
        case 4...5:
            baseline = ("Middle of the cycle", "Hold the rhythm", [
                "Clear most of the protein floor before dinner.",
                "Return to normal meal structure as appetite comes back.",
                "Use the energy window for movement that feels good."
            ])
        default:
            baseline = ("Appetite-return window", "Stay ahead of the rebound", [
                "Lead meals with protein and fiber.",
                "Decide the next meal before hunger makes the decision.",
                "Review what worked this cycle before the next shot."
            ])
        }

        var actions = baseline.2
        if let today {
            if today.appetite <= 2 {
                actions[0] = "Appetite is low today — choose the smallest protein-dense option that feels manageable."
            }
            if today.nausea >= 4 {
                actions[1] = "Keep portions gentle and hydration steady; contact your clinician if symptoms concern you."
            }
            if today.energy <= 2 {
                actions[2] = "Keep movement easy today and protect the basics: protein, fluids, and rest."
            }
        }

        let comparable = history.filter { $0.cycleDay == cycleDay }
        let pattern: String? = if comparable.count >= 2 {
            average(\.appetite, in: comparable) <= 2.5
                ? "Your check-ins say day \(cycleDay) is usually a lower-appetite day."
                : average(\.appetite, in: comparable) >= 4
                    ? "Your appetite usually returns by day \(cycleDay)."
                    : "Day \(cycleDay) has been fairly steady across your recent cycles."
        } else {
            nil
        }

        return ShotCyclePlan(
            phase: baseline.0,
            headline: baseline.1,
            actions: actions,
            learnedPattern: pattern
        )
    }

    private static func average(_ keyPath: KeyPath<ShotCycleCheckIn, Int>, in values: [ShotCycleCheckIn]) -> Double {
        Double(values.reduce(0) { $0 + $1[keyPath: keyPath] }) / Double(values.count)
    }
}
