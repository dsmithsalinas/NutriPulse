import Observation
import Foundation
import Supabase

@Observable
@MainActor
final class ProfileViewModel {
    var profile: UserProfile?    = nil
    var goal: DailyGoal?         = nil
    var latestWeight: WeightLog? = nil
    var glp1Logs: [GLP1Log]      = []
    var isLoading                = false
    var errorMessage: String?    = nil
    var isDeletingAccount        = false

    // Sheet presentation flags
    var showEditProfile    = false
    var showEditGoals      = false
    var showLogInjection   = false
    var showSendFeedback   = false

    private let goalRepo = GoalRepository()
    private let glp1Repo = GLP1Repository()
    private let feedbackRepo = FeedbackRepository()
    private let accountRepo = AccountRepository()

    // MARK: - Computed

    var mostRecentInjection: GLP1Log? { glp1Logs.first }

    // A log with no next_due_at simply has no countdown, rather than breaking the screen.
    var nextInjectionDue: Date? { mostRecentInjection?.nextDueAt }

    var nextInjectionCountdown: String? {
        guard let due = nextInjectionDue else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
            from: cal.startOfDay(for: .now),
            to:   cal.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<0: return "Overdue by \(-days) day\(-days == 1 ? "" : "s")"
        case 0:    return "Due today"
        case 1:    return "Due tomorrow"
        default:   return "Due in \(days) days"
        }
    }

    var isInjectionOverdue: Bool {
        guard let due = nextInjectionDue else { return false }
        return due < .now
    }

    // Round-robin suggestion based on the last used site
    var suggestedNextSite: InjectionSite {
        let sites = InjectionSite.allCases
        guard let lastLog = glp1Logs.first,
              let lastStr = lastLog.site,
              let last = InjectionSite(rawValue: lastStr),
              let idx = sites.firstIndex(of: last)
        else { return .leftAbdomen }
        return sites[(idx + 1) % sites.count]
    }

    // MARK: - Load

    func loadData(profile: UserProfile?) async {
        self.profile = profile
        isLoading = true
        defer { isLoading = false }
        do {
            async let goalTask   = goalRepo.fetchGoal(for: .now)
            async let weightTask = fetchLatestWeight()
            async let glp1Task   = glp1Repo.fetchRecentLogs(limit: 5)
            let (g, w, logs) = try await (goalTask, weightTask, glp1Task)
            goal         = g
            latestWeight = w
            glp1Logs     = logs
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Profile update

    func updateProfile(_ update: UpdateProfile) async throws {
        let userId = try await supabase.auth.session.user.id
        let updated: UserProfile = try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value
        profile = updated
    }

    // MARK: - Weight logging

    func logWeight(_ kg: Double) async throws {
        let userId = try await supabase.auth.session.user.id
        let newLog = NewWeightLog(userId: userId, weightKg: kg)
        let saved: WeightLog = try await supabase
            .from("weight_logs")
            .insert(newLog)
            .select()
            .single()
            .execute()
            .value
        latestWeight = saved
        try? await HealthKitManager.shared.saveWeight(kg, date: .now)
    }

    // MARK: - Goals update

    func updateGoals(calories: Double, proteinG: Double, carbsG: Double,
                     fatG: Double, fiberG: Double) async throws {
        let userId = try await supabase.auth.session.user.id
        let newGoal = NewDailyGoal(
            userId:        userId,
            effectiveDate: Date.now.isoDateString,
            calories:      calories,
            proteinG:      proteinG,
            carbsG:        carbsG,
            fatG:          fatG,
            fiberG:        fiberG,
            waterMlTarget: goal?.waterMlTarget ?? 2000
        )
        // daily_goals has UNIQUE (user_id, effective_date) and effectiveDate is today, so a
        // plain INSERT threw a raw Postgres duplicate-key error straight into the alert the
        // second time a user edited their goals on the same day — and the change was lost.
        // The conflict target must be named: a bare upsert() resolves on the primary key,
        // which is a fresh uuid every call and therefore never collides.
        let saved: DailyGoal = try await supabase
            .from("daily_goals")
            .upsert(newGoal, onConflict: "user_id,effective_date")
            .select()
            .single()
            .execute()
            .value
        goal = saved
        // Today reads the goal from LocalStore first and only hits the network on a cache
        // miss — so without writing the cache here, the rings/remaining/water target keep
        // showing the OLD targets until the next foreground sync heals the cache. Mirror
        // the write TodayViewModel does on its own cache-miss fetch.
        try? LocalStore.shared.upsertGoal(saved)
    }

    // MARK: - GLP-1 logging

    func logInjection(medication: String, doseMg: Double,
                      site: String, date: Date) async throws {
        let userId  = try await supabase.auth.session.user.id
        let nextDue = Calendar.current.date(byAdding: .day, value: 7, to: date)!
        let newLog  = NewGLP1Log(
            userId:     userId,
            injectedAt: date,
            medication: medication,
            doseMg:     doseMg,
            site:       site,
            nextDueAt:  nextDue
        )
        let saved: GLP1Log = try await supabase
            .from("glp1_logs")
            .insert(newLog)
            .select()
            .single()
            .execute()
            .value
        // The sheet allows backdating, so the saved log is NOT necessarily the newest.
        // Keep glp1Logs sorted newest-first (mostRecentInjection = glp1Logs.first drives the
        // Profile card), and schedule reminders from the TRUE latest dose — rescheduling from
        // a backfilled older dose would cancel the valid upcoming reminders and replace them
        // with past-dated ones that never fire.
        glp1Logs.append(saved)
        glp1Logs.sort { $0.injectedAt > $1.injectedAt }
        if let latestDue = glp1Logs.first?.nextDueAt {
            await NotificationManager.shared.scheduleGLP1Reminders(nextDueAt: latestDue)
        }
    }

    // MARK: - Feedback

    func submitFeedback(category: FeedbackCategory, message: String) async throws {
        try await feedbackRepo.submit(category: category, message: message)
    }

    // MARK: - Account deletion

    func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await accountRepo.deleteAccount()
            try? await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func fetchLatestWeight() async throws -> WeightLog? {
        let logs: [WeightLog] = try await supabase
            .from("weight_logs")
            .select()
            .order("logged_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return logs.first
    }
}
