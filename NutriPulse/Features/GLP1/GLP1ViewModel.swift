import Observation
import Foundation
import UserNotifications

// Backs the GLP-1 screen: today's dose status, the protein floor, water, and injection-cycle
// context. Loads its own data so the screen works from any entry point (Today dose chip or
// Profile). The "protein floor" framing is deliberate — for a GLP-1 user, protein is a minimum
// to clear that protects muscle, not a ceiling to stay under.
@Observable
@MainActor
final class GLP1ViewModel {
    var latest: GLP1Log?      = nil
    var proteinToday: Double  = 0
    var proteinGoal: Double   = 0
    var waterMl: Double       = 0
    var waterGoalMl: Double   = 2000
    var remindersEnabled      = false
    var isLoading             = false

    private let glp1Repo = GLP1Repository()
    private let goalRepo = GoalRepository()

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        remindersEnabled = settings.authorizationStatus == .authorized
                        || settings.authorizationStatus == .provisional

        guard let userId = try? await supabase.auth.session.user.id else { return }

        async let glp1Task = glp1Repo.fetchRecentLogs(limit: 1)

        // Today's protein and water come from the local cache (instant, matches Today).
        proteinToday = (try? LocalStore.shared.fetchFoodLogs(for: .now, userId: userId))?
            .reduce(0) { $0 + $1.totalProteinG } ?? 0
        waterMl = (try? LocalStore.shared.fetchWaterTotal(for: .now, userId: userId)) ?? 0

        if let goal = try? LocalStore.shared.fetchGoal(for: .now, userId: userId) {
            proteinGoal = goal.proteinG
            waterGoalMl = goal.waterMlTarget
        } else if let goal = try? await goalRepo.fetchGoal(for: .now) {
            proteinGoal = goal.proteinG
            waterGoalMl = goal.waterMlTarget
        }

        latest = (try? await glp1Task)?.first
    }

    // MARK: Derived

    private var cal: Calendar { Calendar.current }

    var daysSinceShot: Int? {
        guard let injected = latest?.injectedAt else { return nil }
        return cal.dateComponents([.day], from: cal.startOfDay(for: injected), to: cal.startOfDay(for: .now)).day
    }

    var nextDue: Date? { latest?.nextDueAt }
    var isOverdue: Bool { nextDue.map { $0 < .now } ?? false }

    var proteinPct: Double { proteinGoal > 0 ? min(proteinToday / proteinGoal, 1) : 0 }
    var proteinCleared: Bool { proteinGoal > 0 && proteinToday >= proteinGoal }
    var proteinRemaining: Int { max(Int((proteinGoal - proteinToday).rounded()), 0) }
    var waterPct: Double { waterGoalMl > 0 ? min(waterMl / waterGoalMl, 1) : 0 }

    // "Due Saturday · in 2 days" / "Due today" / "Overdue by N days"
    var nextDoseText: String? {
        guard let due = nextDue else { return nil }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<0:  return "Overdue by \(-days) day\(-days == 1 ? "" : "s")"
        case 0:     return "Due today"
        case 1:     return "Due tomorrow"
        default:
            let df = DateFormatter(); df.dateFormat = "EEEE"
            return "\(df.string(from: due)) · in \(days) days"
        }
    }

    // Deterministic, schedule-aware guidance (no API call) — the injection cycle drives appetite,
    // and protein-first is the through-line. Framed to protect results, never to scold.
    var coachNote: String {
        guard let days = daysSinceShot else {
            return "Log an injection and Pulse can time your protein around your dose cycle."
        }
        if isOverdue {
            return "You're past your usual dose day — appetite tends to climb here. Keep protein first so it stays easy."
        }
        switch days {
        case 0:      return "Injection day. Appetite usually dips over the next day or two — get your protein in while it's easy."
        case 1...2:  return "Day \(days) after your shot — appetite's usually lowest now. Keep protein dense so you don't have to fight the volume."
        case 3...4:  return "Appetite starts returning around now. Stay ahead of your protein floor before the hunger does."
        default:     return "Appetite's usually highest right before your next dose — a good window to bank a little extra protein."
        }
    }

    // Prompt handed to Pulse when the user wants to go deeper from this screen.
    var askPulsePrompt: String {
        if let days = daysSinceShot {
            return "I'm on \(latest?.medication ?? "a GLP-1"), day \(days) after my last shot. What should I focus on eating today to protect my muscle and hit my protein?"
        }
        return "How should I eat around my GLP-1 injection cycle to protect my muscle and hit my protein?"
    }
}
