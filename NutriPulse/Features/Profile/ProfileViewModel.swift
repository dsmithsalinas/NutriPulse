import Observation
import Foundation
import Supabase
import UserNotifications

@Observable
@MainActor
final class ProfileViewModel {
    var profile: UserProfile?    = nil
    var goal: DailyGoal?         = nil
    var latestWeight: WeightLog? = nil
    // Latest known body-fat %, if any — feeds the Katch-McArdle BMR path when the
    // edit-stats recalc runs. nil (or junk) falls back to Mifflin inside GoalCalculator.
    var latestBodyFatPct: Double? = nil
    var glp1Logs: [GLP1Log]      = []
    var isLoading                = false
    var errorMessage: String?    = nil
    var isDeletingAccount        = false

    // Shot-day reminders
    var remindersOn              = false
    var showReminderDeniedAlert  = false

    // Sheet presentation flags
    var showEditProfile    = false
    var showEditGoals      = false
    var showLogInjection   = false
    var showSendFeedback   = false

    // Recalculate Targets — the intent-change flow. The dialog re-asks the one
    // onboarding question (lose/maintain/gain); the preview alert shows the computed
    // numbers; nothing is applied until the user accepts.
    var showRecalcAimDialog = false
    struct TargetRecalc {
        let weightGoal: WeightGoal
        let goals: CalculatedGoals
        let currentCalories: Double
    }
    var pendingTargetRecalc: TargetRecalc? = nil

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
            async let bodyCompTask = BodyCompositionRepository().fetchLatest()
            let (g, w, logs) = try await (goalTask, weightTask, glp1Task)
            goal         = g
            latestWeight = w
            glp1Logs     = logs
            latestBodyFatPct = (try? await bodyCompTask)?.bodyFatPct
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshRemindersState()
    }

    // MARK: - Shot-day reminders

    // "On" = permission granted AND glp1-* reminders actually pending, not just permission.
    func refreshRemindersState() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            remindersOn = false
            return
        }
        let pending = await center.pendingNotificationRequests()
        remindersOn = pending.contains { $0.identifier.hasPrefix("glp1-") }
    }

    // Toggle target. Reverts and flags the denied case so the view can offer Settings.
    func setReminders(_ on: Bool) async {
        if on {
            guard await NotificationManager.shared.requestPermissionIfNeeded() else {
                remindersOn = false
                showReminderDeniedAlert = true
                return
            }
            if let due = nextInjectionDue {
                await NotificationManager.shared.scheduleGLP1Reminders(nextDueAt: due)
            }
            remindersOn = true
        } else {
            NotificationManager.shared.cancelGLP1Reminders()
            remindersOn = false
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

    // `waterMlTarget` nil = keep the current target (Edit Goals has no water field, and a
    // hand-tuned macro edit shouldn't move it). Recalc paths pass their computed value —
    // previously they silently dropped it, leaving water stale while everything else moved.
    func updateGoals(calories: Double, proteinG: Double, carbsG: Double,
                     fatG: Double, fiberG: Double, waterMlTarget: Double? = nil) async throws {
        let userId = try await supabase.auth.session.user.id
        let newGoal = NewDailyGoal(
            userId:        userId,
            effectiveDate: Date.now.isoDateString,
            calories:      calories,
            proteinG:      proteinG,
            carbsG:        carbsG,
            fatG:          fatG,
            fiberG:        fiberG,
            waterMlTarget: waterMlTarget ?? goal?.waterMlTarget ?? 2000
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
        // Any deliberate goal change (recalc accept or a hand-tuned edit) re-anchors the
        // weight-drift baseline: the user just chose targets for their CURRENT body, so
        // Today's drift prompt should stay quiet until the next real change.
        if let w = latestWeight?.weightKg, w > 0 {
            UserDefaults.standard.set(w, forKey: GoalCalculator.weightBaselineKey)
        }
    }

    // MARK: - Recalculate Targets (intent change)

    // Computes fresh targets for a chosen aim from current stats + latest weight, via the
    // same calculator onboarding uses (Katch-McArdle when body fat is known). Returns nil
    // when the profile is missing something the formula needs.
    func prepareRecalc(for weightGoal: WeightGoal) {
        guard let profile,
              let sexRaw = profile.sex, let sex = BiologicalSex(rawValue: sexRaw),
              let activityRaw = profile.activityLevel,
              let activity = ActivityLevel(rawValue: activityRaw),
              let heightCm = profile.heightCm,
              let dobStr = profile.dob, let dob = Date.fromISODateString(dobStr),
              let weightKg = latestWeight?.weightKg,
              let currentCalories = goal?.calories
        else {
            errorMessage = "Add your stats and a weight entry first, then try again."
            return
        }
        let goals = GoalCalculator.goals(
            sex: sex,
            ageYears: GoalCalculator.ageYears(fromDOB: dob),
            heightCm: heightCm,
            weightKg: weightKg,
            activity: activity,
            weightGoal: weightGoal,
            bodyFatPct: latestBodyFatPct
        )
        pendingTargetRecalc = TargetRecalc(
            weightGoal: weightGoal, goals: goals, currentCalories: currentCalories
        )
    }

    // Takes the value rather than reading pendingTargetRecalc: the alert's isPresented
    // binding nils that state on dismiss, which races this Task — the same trap the
    // edit-stats recalc alert sidesteps by capturing its `presenting` parameter.
    func applyRecalc(_ pending: TargetRecalc) async {
        do {
            try await updateGoals(
                calories: pending.goals.calories,
                proteinG: pending.goals.proteinG,
                carbsG: pending.goals.carbsG,
                fatG: pending.goals.fatG,
                fiberG: pending.goals.fiberG,
                waterMlTarget: pending.goals.waterMlTarget
            )
            // The direction finally gets stored — the retarget flow's inference now has
            // ground truth, and Pulse can name the aim instead of guessing it.
            let userId = try await supabase.auth.session.user.id
            let updated: UserProfile = try await supabase
                .from("profiles")
                .update(["weight_goal": pending.weightGoal.rawValue])
                .eq("id", value: userId)
                .select()
                .single()
                .execute()
                .value
            profile = updated
        } catch {
            errorMessage = "Couldn't update your targets."
        }
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
