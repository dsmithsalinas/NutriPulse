import Observation
import Foundation

// SWIFT CONCEPT — @Observable + @MainActor together: all property reads/writes and
// method calls happen on the main thread, so SwiftUI view updates are always safe.
// Think of @MainActor as a compile-time guarantee that replaces manual DispatchQueue.main.async calls.

@Observable
@MainActor
final class TodayViewModel {
    private let goalRepo     = GoalRepository()
    private let bodyCompRepo = BodyCompositionRepository()
    private let measurementRepo = BodyMeasurementRepository()
    private let foodLogRepo  = FoodLogRepository()
    private let glp1Repo     = GLP1Repository()

    // Most recent GLP-1 injection, for the dose-day chip in the header. Fetched on load; the
    // chip only surfaces on today, and only when a dose is due today or overdue.
    var latestGLP1: GLP1Log? = nil

    var selectedDate: Date = .now
    // Whether `selectedDate` is the user's "today" rather than a day they
    // deliberately navigated back to. iOS keeps suspended apps alive for days,
    // so without this the date set at init silently becomes yesterday and every
    // log written from this screen lands on the wrong day. See snapToTodayIfDayChanged().
    private var isTrackingToday = true

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
    var totalFatG:     Double { foodLogs.reduce(0) { $0 + $1.totalFatG     } }
    var totalFiberG:   Double { foodLogs.reduce(0) { $0 + $1.totalFiberG   } }

    var isToday: Bool { selectedDate.isToday }

    // Water tracking
    var waterIntakeMl: Double = 0
    var waterGoalMl:   Double = 2000

    // Body composition
    var bodyComp = BodyCompositionData()
    // Latest waist for the Body card's fourth chip (all-time latest, like the others).
    var latestWaistCm: Double? = nil

    // Workouts for the selected date — HealthKit imports and manual logs merged,
    // read from LocalStore (imports land there via loadWorkouts()).
    var workouts: [WorkoutLog] = []

    // Set by TodayView from AppState before loadData — the weight-drift check needs the
    // user's stats (sex, height, DOB, activity) to rebuild TDEEs.
    var profile: UserProfile? = nil

    // Non-nil when Today should offer new targets — either because the 7-day average
    // weight drifted from the weight the current goals were computed from (.drift), or
    // because it reached the user's goal weight and there's a deficit/surplus worth
    // ending (.maintenance). One card slot; maintenance outranks drift. Never applied
    // without the user's say-so.
    struct RetargetSuggestion {
        enum Kind { case drift, maintenance }
        let kind: Kind
        let goals: CalculatedGoals
        let currentCalories: Double
        let avgWeightKg: Double
        let baselineKg: Double
        let goalWeightKg: Double?   // set for .maintenance, for the card's copy
    }
    var retargetSuggestion: RetargetSuggestion? = nil

    private static let maintenanceDismissedGoalKey = "maintenanceOfferDismissedGoalKg"

    // The pure decision behind the maintenance offer. True when the 7-day average is at
    // the user's goal weight — within 1%, or past it in the direction their current
    // adjustment pushes — AND there is an adjustment (≥100 kcal from maintenance) worth
    // ending. A dismissal suppresses the offer for that exact goal value; changing the
    // goal re-arms it. Someone already eating at maintenance is never prompted.
    nonisolated static func shouldOfferMaintenance(
        avgWeightKg: Double,
        goalWeightKg: Double?,
        currentCalories: Double,
        tdeeAtAvg: Double,
        dismissedForGoalKg: Double?
    ) -> Bool {
        guard let goal = goalWeightKg, goal > 0, avgWeightKg > 0 else { return false }
        if let dismissed = dismissedForGoalKg, abs(dismissed - goal) < 0.05 { return false }
        let adjustment = currentCalories - tdeeAtAvg
        guard abs(adjustment) >= 100 else { return false }
        if abs(avgWeightKg - goal) <= goal * 0.01 { return true }
        // Past the goal in the direction of travel: losing → below it, gaining → above it.
        return adjustment < 0 ? avgWeightKg < goal : avgWeightKg > goal
    }

    // HealthKit data for the selected date
    // nil = HealthKit reported nothing (no data, or read access denied — HealthKit won't
    // say which). 0 would be a claim we can't support.
    var activeCalories: Double? = nil
    var restingHeartRate: Double? = nil
    var hrv: Double?            = nil
    var sleepHours: Double?     = nil

    // Dose-day chip content. Only on today, and only when the next dose is due today or has
    // passed — the actionable states. On other days the header stays clean.
    struct DoseStatus { let text: String; let urgent: Bool }

    var doseStatus: DoseStatus? {
        guard isToday, let log = latestGLP1, let due = log.nextDueAt else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: .now),
                                      to: cal.startOfDay(for: due)).day ?? 0
        if days < 0 { return DoseStatus(text: "Dose overdue · \(log.medication)", urgent: true) }
        if days == 0 { return DoseStatus(text: "Dose day · \(log.medication)", urgent: false) }
        return nil
    }

    // Did the user log their shot today? Drives the dose-day card's celebratory "done" state,
    // which shows for the rest of the day and then falls away tomorrow.
    var injectionLoggedToday: Bool {
        guard isToday, let injected = latestGLP1?.injectedAt else { return false }
        return Calendar.current.isDateInToday(injected)
    }

    // Called the instant an injection is logged from the ritual — update the card immediately
    // (no refetch race), then reconcile the rest of the day's data.
    func registerLoggedInjection(_ log: GLP1Log) {
        latestGLP1 = log
        Task { await loadData() }
    }

    // A supportive, forward-looking nudge for the current day when the user is pacing under
    // their targets. GLP-1 suppresses appetite, so under-eating (and losing muscle) is the real
    // risk here — the framing protects results, it never scolds. Only surfaces on today, only in
    // the afternoon/evening (mornings are legitimately low), and only when genuinely behind.
    // On a day with a logged workout the copy becomes workout-aware and the protein trigger
    // reaches a little higher — see buildNudge.
    var nudge: DayNudge? {
        guard isToday, let goal = dailyGoal else { return nil }
        return Self.buildNudge(
            goal: goal,
            totalProteinG: totalProteinG,
            totalCalories: totalCalories,
            todaysWorkouts: workouts,
            hour: Calendar.current.component(.hour, from: .now)
        )
    }

    // The pure decision + copy behind the nudge, extracted (like shouldImportHKWeight) so its
    // truth table is testable without a ViewModel, a clock, or SwiftData. `hour` is injectable
    // for the same reason.
    nonisolated static func buildNudge(
        goal: DailyGoal,
        totalProteinG: Double,
        totalCalories: Double,
        todaysWorkouts: [WorkoutLog],
        hour: Int
    ) -> DayNudge? {
        guard goal.proteinG > 0 else { return nil }
        guard hour >= 14 else { return nil }

        let proteinLeft = goal.proteinG - totalProteinG
        let calorieLeft = goal.calories - totalCalories
        let proteinPct = totalProteinG / goal.proteinG
        let caloriePct = goal.calories > 0 ? totalCalories / goal.calories : 1

        // On a training day the protein floor matters more, so the nudge speaks up a
        // little earlier on the protein scale (80% vs 70%). Calories are unchanged —
        // movement never turns into an eat-more-because-you-burned framing.
        let workedOut = !todaysWorkouts.isEmpty
        let proteinTrigger = workedOut ? 0.8 : 0.7

        // Behind on the day's priority (protein) or well under on energy…
        guard proteinPct < proteinTrigger || caloriePct < 0.6 else { return nil }
        // …but not when they're basically there — no nagging over the last few grams.
        guard proteinLeft > 15 || calorieLeft > 400 else { return nil }

        let pLeft = max(Int(proteinLeft.rounded()), 0)
        let cLeft = max(Int(calorieLeft.rounded()), 0)

        guard workedOut else {
            return DayNudge(
                headline: "You've got room to finish strong",
                body: "You're pacing a little under today. A protein-forward dinner keeps your muscle protected while the medication does its part — you're about \(pLeft)g of protein and \(cLeft) calories from your goals.",
                cta: "Ask Pulse for dinner ideas",
                prompt: "I have about \(pLeft)g of protein and \(cLeft) calories left today — what should I eat to finish strong?"
            )
        }

        // Lead with the session the user actually did. Multiple sessions roll up into a
        // count + total minutes; a single session gets named.
        let totalMinutes = Int(todaysWorkouts.reduce(0) { $0 + $1.durationMinutes }.rounded())
        let sessionPhrase: String
        if todaysWorkouts.count == 1, let session = todaysWorkouts.first {
            sessionPhrase = "\(Int(session.durationMinutes.rounded())) minutes of \(session.displayName.lowercased())"
        } else {
            sessionPhrase = "\(todaysWorkouts.count) sessions (\(totalMinutes) min)"
        }

        return DayNudge(
            headline: "Feed the work you put in",
            body: "You logged \(sessionPhrase) today. Protein is how that work turns into protected muscle — you're about \(pLeft)g of protein and \(cLeft) calories from your goals.",
            cta: "Ask Pulse for a recovery dinner",
            prompt: "I did \(sessionPhrase) today and I'm about \(pLeft)g of protein and \(cLeft) calories short of my goals — what should I eat tonight to support it?"
        )
    }

    // Drives the free ring-closing celebration beat — no server round trip,
    // just today's totals against today's goal. See CelebrationEngine for the
    // richer, Coach-facing win detection (streaks, firsts).
    var allRingsClosed: Bool {
        guard let goal = dailyGoal else { return false }
        return goal.ringsClosed(
            calories: totalCalories,
            proteinG: totalProteinG,
            carbsG:   totalCarbsG,
            fiberG:   totalFiberG
        )
    }

    // True for exactly one loadData() call — the one where allRingsClosed flips
    // false → true. Computed atomically around the reload so there's no window
    // where a view's .onChange could race against an in-flight async load.
    private(set) var justClosedAllRings = false

    // Protein is the hero ring — "did I hit protein?" is the daily question — so it gets
    // its own celebration, fired the instant protein alone crosses the goal, independent
    // of the other macros. Protein is a FLOOR (met when consumed >= goal), same as ringsClosed.
    var proteinGoalHit: Bool {
        guard let goal = dailyGoal, goal.proteinG > 0 else { return false }
        return totalProteinG >= goal.proteinG
    }

    // The protein-only sibling of justClosedAllRings: true for exactly the one loadData()
    // where proteinGoalHit flips false → true, edge-detected atomically around the reload.
    private(set) var justHitProteinGoal = false

    var healthDataAvailable: Bool {
        activeCalories != nil || restingHeartRate != nil || hrv != nil || sleepHours != nil
    }

    func loadData() async {
        let wasClosed      = allRingsClosed
        let wasProteinHit  = proteinGoalHit
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        async let bodyCompTask = buildBodyCompData()
        async let glp1Task = glp1Repo.fetchRecentLogs(limit: 1)

        do {
            let userId = try await supabase.auth.session.user.id

            // Read from LocalStore — instant, works offline
            foodLogs      = (try? LocalStore.shared.fetchFoodLogs(for: selectedDate, userId: userId)) ?? []
            dailyGoal     = try? LocalStore.shared.fetchGoal(for: selectedDate, userId: userId)
            waterIntakeMl = (try? LocalStore.shared.fetchWaterTotal(for: selectedDate, userId: userId)) ?? 0
            waterGoalMl   = dailyGoal?.waterMlTarget ?? 2000

            // Cache miss on first launch — fetch goal from Supabase and store locally
            if dailyGoal == nil {
                if let goal = try? await goalRepo.fetchGoal(for: selectedDate) {
                    dailyGoal   = goal
                    waterGoalMl = goal.waterMlTarget
                    try? LocalStore.shared.upsertGoal(goal)
                }
            }

            // The sync engine only pulls the last 7 days into LocalStore, but the date
            // navigator scrolls back indefinitely. For an older day, an empty local result
            // means "never cached", not "nothing logged" — and Analytics (which queries
            // Supabase directly) would show real food for that same day. Fetch on demand and
            // cache it so the day isn't wrongly rendered as an empty "No food logged yet".
            if foodLogs.isEmpty {
                let cal = Calendar.current
                let windowStart = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: .now))!
                if selectedDate < windowStart,
                   let remote = try? await foodLogRepo.fetchLogs(for: selectedDate),
                   !remote.isEmpty {
                    foodLogs = remote
                    for log in remote { try? LocalStore.shared.upsertFoodLog(from: log) }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        justClosedAllRings = !wasClosed && allRingsClosed
        justHitProteinGoal = !wasProteinHit && proteinGoalHit

        // Feed the protein-floor widget with today's numbers (only for the current day).
        if isToday {
            SharedStore.save(ProteinFloorSnapshot(
                proteinToday: totalProteinG,
                proteinGoal: dailyGoal?.proteinG ?? 0,
                updatedAt: .now
            ))
        }

        latestGLP1 = (try? await glp1Task)?.first
        bodyComp = await bodyCompTask
        latestWaistCm = ((try? await measurementRepo.fetchLatestPerSite()) ?? [:])[.waist]?.valueCm
        await loadHealthData()
        await loadWorkouts()
        await checkWeightDrift()
        await FavoritesStore.shared.loadIfNeeded()
    }

    // MARK: - Weight-drift retarget

    // The Profile edit-stats flow only recalculates when the user edits stats by hand — but
    // weight flows in continuously from weigh-ins and HealthKit, so someone losing steadily
    // keeps targets computed for a body they no longer have. This compares the 7-day average
    // against the baseline recorded when the goals were set and OFFERS a recalc; the
    // suggestion is never applied silently.
    private func checkWeightDrift() async {
        guard isToday, let profile, let goal = dailyGoal,
              let sexRaw = profile.sex, let sex = BiologicalSex(rawValue: sexRaw),
              let activityRaw = profile.activityLevel,
              let activity = ActivityLevel(rawValue: activityRaw),
              let heightCm = profile.heightCm,
              let dobStr = profile.dob, let dob = Date.fromISODateString(dobStr)
        else { return }

        let logs = (try? await AnalyticsRepository().fetchWeightLogs(days: 7)) ?? []
        guard !logs.isEmpty else { return }
        let avgKg = logs.reduce(0) { $0 + $1.weightKg } / Double(logs.count)

        let age = GoalCalculator.ageYears(fromDOB: dob)
        let bodyFat = bodyComp.bodyFatPct
        let newTDEE = GoalCalculator.tdee(
            sex: sex, ageYears: age, heightCm: heightCm, weightKg: avgKg,
            activity: activity, bodyFatPct: bodyFat
        )
        let ud = UserDefaults.standard

        // Reached the goal weight → the offer is to END the adjustment, not carry it.
        // Outranks the drift offer: a user descending onto their goal trips both, and
        // "shift to maintenance" is the decision that moment is actually about.
        let goalWeight = ((try? await BodyGoalsRepository().fetch()) ?? nil)?.weightKgTarget
        let dismissedFor = ud.object(forKey: Self.maintenanceDismissedGoalKey) as? Double
        if Self.shouldOfferMaintenance(
            avgWeightKg: avgKg, goalWeightKg: goalWeight,
            currentCalories: goal.calories, tdeeAtAvg: newTDEE,
            dismissedForGoalKg: dismissedFor
        ) {
            let target = max(GoalCalculator.calorieFloor, newTDEE).rounded()
            let goals = GoalCalculator.macros(
                calories: target, weightKg: avgKg, heightCm: heightCm, sex: sex
            )
            retargetSuggestion = RetargetSuggestion(
                kind: .maintenance, goals: goals, currentCalories: goal.calories,
                avgWeightKg: avgKg,
                baselineKg: ud.double(forKey: GoalCalculator.weightBaselineKey),
                goalWeightKg: goalWeight
            )
            return
        }

        let baseline = ud.double(forKey: GoalCalculator.weightBaselineKey)
        guard baseline > 0 else {
            // Existing installs never recorded the weight their goals came from. Seed
            // silently from today's average; prompting starts at the next real drift.
            ud.set(avgKg, forKey: GoalCalculator.weightBaselineKey)
            return
        }
        guard GoalCalculator.weightDriftExceeds(baselineKg: baseline, recentAvgKg: avgKg) else {
            retargetSuggestion = nil
            return
        }

        // Same shape as Profile's recalc: rebuild TDEE at the baseline weight and at the
        // current average, and let retargeted() carry the user's adjustment across.
        let oldTDEE = GoalCalculator.tdee(
            sex: sex, ageYears: age, heightCm: heightCm, weightKg: baseline,
            activity: activity, bodyFatPct: bodyFat
        )
        let goals = GoalCalculator.retargeted(
            currentCalories: goal.calories, oldTDEE: oldTDEE, newTDEE: newTDEE,
            newWeightKg: avgKg, heightCm: heightCm, sex: sex
        )
        // Don't offer a recalc that barely moves the number.
        guard abs(goals.calories - goal.calories) >= 25 else { return }
        retargetSuggestion = RetargetSuggestion(
            kind: .drift, goals: goals, currentCalories: goal.calories,
            avgWeightKg: avgKg, baselineKg: baseline, goalWeightKg: nil
        )
    }

    func acceptRetarget() async {
        guard let suggestion = retargetSuggestion,
              let userId = try? await supabase.auth.session.user.id else { return }
        let newGoal = NewDailyGoal(
            userId:        userId,
            effectiveDate: Date.now.isoDateString,
            calories:      suggestion.goals.calories,
            proteinG:      suggestion.goals.proteinG,
            carbsG:        suggestion.goals.carbsG,
            fatG:          suggestion.goals.fatG,
            fiberG:        suggestion.goals.fiberG,
            waterMlTarget: suggestion.goals.waterMlTarget
        )
        do {
            // Named conflict target for the same reason as ProfileViewModel.updateGoals:
            // daily_goals is UNIQUE (user_id, effective_date) and a bare upsert resolves
            // on the always-fresh primary key.
            let saved: DailyGoal = try await supabase
                .from("daily_goals")
                .upsert(newGoal, onConflict: "user_id,effective_date")
                .select()
                .single()
                .execute()
                .value
            dailyGoal = saved
            waterGoalMl = saved.waterMlTarget
            try? LocalStore.shared.upsertGoal(saved)
            UserDefaults.standard.set(suggestion.avgWeightKg, forKey: GoalCalculator.weightBaselineKey)
            retargetSuggestion = nil
        } catch {
            errorMessage = "Couldn't update your targets."
        }
    }

    // "Keep current" means keep them for THIS body: the baseline moves to today's average,
    // so the drift card returns only after another meaningful drift — not tomorrow
    // morning. Dismissing a maintenance offer additionally remembers WHICH goal it was
    // for: that offer stays quiet until the goal itself changes.
    func dismissRetarget() {
        guard let suggestion = retargetSuggestion else { return }
        UserDefaults.standard.set(suggestion.avgWeightKg, forKey: GoalCalculator.weightBaselineKey)
        if suggestion.kind == .maintenance, let goalKg = suggestion.goalWeightKg {
            UserDefaults.standard.set(goalKg, forKey: Self.maintenanceDismissedGoalKey)
        }
        retargetSuggestion = nil
    }

    // Import-then-read: any HealthKit workout for this day that LocalStore hasn't seen
    // becomes a local row (source "healthkit", pendingCreate → syncs like any other log),
    // then the merged list is read back. The importHealthKitWorkout guard makes re-runs
    // no-ops, so calling this on every loadData() is safe.
    func loadWorkouts() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        let hk = HealthKitManager.shared
        if hk.isAvailable {
            var didImport = false
            for workout in await hk.fetchWorkouts(for: selectedDate) {
                let inserted = (try? LocalStore.shared.importHealthKitWorkout(
                    userId: userId,
                    logDate: workout.startDate.isoDateString,
                    activityType: workout.activitySlug,
                    durationMinutes: workout.durationMinutes,
                    activeCalories: workout.activeCalories,
                    distanceMeters: workout.distanceMeters,
                    healthKitUUID: workout.uuid,
                    startedAt: workout.startDate
                )) ?? false
                didImport = didImport || inserted
            }
            if didImport {
                SyncEngine.shared.refreshPendingCount()
                Task { await SyncEngine.shared.pushPendingChanges() }
            }
        }
        workouts = (try? LocalStore.shared.fetchWorkoutLogs(for: selectedDate, userId: userId)) ?? []
    }

    func addManualWorkout(
        activity: ManualActivityType,
        durationMinutes: Double,
        calories: Double?,
        distanceMeters: Double?
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        // Logging onto a past day: noon is an honest-enough anchor for a session whose
        // real start time the user never gave us.
        let startedAt = isToday
            ? Date.now
            : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        do {
            try LocalStore.shared.insertWorkoutLog(
                id: UUID(),
                userId: userId,
                logDate: selectedDate.isoDateString,
                activityType: activity.rawValue,
                durationMinutes: durationMinutes,
                activeCalories: calories,
                distanceMeters: distanceMeters,
                source: "manual",
                healthKitUUID: nil,
                startedAt: startedAt
            )
            workouts = (try? LocalStore.shared.fetchWorkoutLogs(for: selectedDate, userId: userId)) ?? workouts
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
        } catch {
            errorMessage = "Couldn't log workout."
        }
    }

    func deleteWorkout(id: UUID) async {
        do {
            try LocalStore.shared.markWorkoutLogDeleted(id: id)
            workouts.removeAll { $0.id == id }
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
        } catch {
            errorMessage = "Couldn't remove workout."
        }
    }

    private func buildBodyCompData() async -> BodyCompositionData {
        let hk = HealthKitManager.shared
        var data = BodyCompositionData()

        async let savedTask = try? bodyCompRepo.fetchLatest()
        var hkWeight: HealthKitManager.HKMeasurement? = nil
        var hkBodyFat: HealthKitManager.HKMeasurement? = nil
        var hkBMI: HealthKitManager.HKMeasurement? = nil
        var hkLBM: HealthKitManager.HKMeasurement? = nil

        if hk.isAvailable {
            async let w  = hk.fetchMostRecentWeight()
            async let bf = hk.fetchMostRecentBodyFat()
            async let b  = hk.fetchMostRecentBMI()
            async let l  = hk.fetchMostRecentLBM()
            async let wc = hk.fetchMostRecentWaist()
            (hkWeight, hkBodyFat, hkBMI, hkLBM) = await (w, bf, b, l)

            // Waist auto-import: identical contract to the weight import below — today's
            // sample, not written by this app, at most once per calendar day. The pure
            // decision function is shared; only the UserDefaults key differs.
            if let waist = await wc {
                let today = Date().isoDateString
                let alreadySynced = UserDefaults.standard.string(forKey: "lastHKWaistSyncDate") == today
                if Self.shouldImportHKWeight(sampleDate: waist.date, isFromThisApp: waist.isFromThisApp, alreadySyncedToday: alreadySynced) {
                    UserDefaults.standard.set(today, forKey: "lastHKWaistSyncDate")
                    try? await measurementRepo.insert(
                        site: .waist, valueCm: waist.value, source: "healthkit"
                    )
                }
            }
        }

        let saved = await savedTask

        // Weight: prefer HK; auto-import today's reading once per calendar day.
        if let w = hkWeight {
            data.weightKg     = w.value
            data.weightFromHK = true
            data.latestDate   = w.date

            // `!w.isFromThisApp` breaks an echo loop: log a weight in Profile, the app
            // writes it to HealthKit, then this reads it straight back and inserts a
            // *second* weight_logs row for the same value and day, tagged "healthkit".
            // Same for anything saveBodyComposition wrote with writeToHK on.
            //
            // The UserDefaults key is set BEFORE the awaits, not after. Two concurrent
            // loadData() calls (sheet dismiss + a sync-triggered reload) could otherwise
            // both pass the check before either wrote the key, and both insert.
            let today = Date().isoDateString
            let alreadySyncedToday = UserDefaults.standard.string(forKey: "lastHKWeightSyncDate") == today
            if Self.shouldImportHKWeight(sampleDate: w.date, isFromThisApp: w.isFromThisApp, alreadySyncedToday: alreadySyncedToday) {
                UserDefaults.standard.set(today, forKey: "lastHKWeightSyncDate")
                try? await bodyCompRepo.upsert(date: today, weightKg: w.value, bodyFatPct: nil, bmi: nil, leanBodyMassKg: nil, source: "healthkit")
                if let userId = try? await supabase.auth.session.user.id {
                    _ = try? await supabase.from("weight_logs")
                        .insert(NewWeightLog(userId: userId, weightKg: w.value, source: "healthkit"))
                        .execute()
                }
            }
        } else if let w = saved?.weightKg {
            data.weightKg     = w
            data.weightFromHK = false
        }

        if let bf = hkBodyFat {
            data.bodyFatPct    = bf.value
            data.bodyFatFromHK = true
        } else if let bf = saved?.bodyFatPct {
            data.bodyFatPct    = bf
        }

        if let b = hkBMI {
            data.bmi       = b.value
            data.bmiFromHK = true
        } else if let b = saved?.bmi {
            data.bmi       = b
        }

        if let l = hkLBM {
            data.lbmKg      = l.value
            data.lbmFromHK  = true
        } else if let l = saved?.leanBodyMassKg {
            data.lbmKg      = l
        }

        return data
    }

    func saveBodyComposition(
        weightKg: Double?,
        bodyFatPct: Double?,
        bmi: Double?,
        lbmKg: Double?,
        measurementsCm: [MeasurementSite: Double] = [:],
        writeToHK: Bool
    ) async {
        let today = Date().isoDateString
        do {
            try await bodyCompRepo.upsert(
                date: today,
                weightKg: weightKg,
                bodyFatPct: bodyFatPct,
                bmi: bmi,
                leanBodyMassKg: lbmKg,
                source: "manual"
            )
            for (site, valueCm) in measurementsCm {
                try? await measurementRepo.insert(site: site, valueCm: valueCm)
            }
            if let weight = weightKg, let userId = try? await supabase.auth.session.user.id {
                try await supabase.from("weight_logs")
                    .insert(NewWeightLog(userId: userId, weightKg: weight, source: "manual"))
                    .execute()
            }
            if writeToHK {
                let hk  = HealthKitManager.shared
                let now = Date()
                if let w  = weightKg   { try? await hk.saveWeight(w, date: now) }
                if let bf = bodyFatPct { try? await hk.saveBodyFat(bf, date: now) }
                if let b  = bmi        { try? await hk.saveBMI(b, date: now) }
                if let l  = lbmKg      { try? await hk.saveLeanBodyMass(l, date: now) }
            }
            bodyComp = await buildBodyCompData()
        } catch {
            errorMessage = "Could not save body composition."
        }
    }

    // Reads only. Requesting authorization here meant the system prompt fired the instant
    // Today appeared, and — because iOS shows it exactly once per type — the card's
    // "Connect Apple Health" button was then permanently a no-op. Asking now belongs to
    // the onboarding step and to an explicit tap; see requestHealthAuthorization().
    func loadHealthData() async {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else { return }
        // Scope upgrade (e.g. v2 added workouts + steps): users who already granted the
        // old scope get the incremental sheet once, automatically — the guard above about
        // not prompting on appear applies to the FIRST ask, where an uninvited sheet is
        // rude; an upgrade of a connection the user opted into is expected behavior.
        if hk.needsScopeUpgrade {
            try? await hk.requestAuthorization()
        }
        async let cal    = hk.fetchActiveCalories(for: selectedDate)
        async let hr     = hk.fetchRestingHeartRate(for: selectedDate)
        async let hrvVal = hk.fetchHRV(for: selectedDate)
        async let sleep  = hk.fetchSleepHours(for: selectedDate)
        let (calories, heartRate, heartRateVar, sleepTime) = await (cal, hr, hrvVal, sleep)
        activeCalories   = calories
        restingHeartRate = heartRate
        hrv              = heartRateVar
        sleepHours       = sleepTime
    }

    // Triggered by the card's "Connect Apple Health" row. Only meaningful before the
    // system prompt has been shown; afterwards the card sends the user to the Health app
    // instead, since iOS will never present that sheet again.
    func requestHealthAuthorization() async {
        try? await HealthKitManager.shared.requestAuthorization()
        await loadHealthData()
    }

    func addWater(_ ml: Double) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        do {
            try LocalStore.shared.insertWaterLog(
                id: UUID(), userId: userId,
                logDate: selectedDate.isoDateString, amountMl: ml
            )
            waterIntakeMl += ml
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
        } catch {
            errorMessage = "Couldn't log water."
        }
    }

    func deleteLog(id: UUID) async {
        do {
            try LocalStore.shared.markFoodLogDeleted(id: id)
            foodLogs.removeAll { $0.id == id }
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
        } catch {
            errorMessage = "Couldn't delete log."
        }
    }

    func editLog(id: UUID, meal: Meal, quantity: Double) async {
        do {
            try LocalStore.shared.updateFoodLog(id: id, meal: meal.rawValue, quantity: quantity)
            if let userId = try? await supabase.auth.session.user.id {
                foodLogs = try LocalStore.shared.fetchFoodLogs(for: selectedDate, userId: userId)
            }
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
        } catch {
            errorMessage = "Couldn't save changes."
        }
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        isTrackingToday = selectedDate.isToday
    }

    func goToNextDay() {
        guard !selectedDate.isToday else { return }  // don't navigate into the future
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        isTrackingToday = selectedDate.isToday
    }

    func goToToday() {
        selectedDate = .now
        isTrackingToday = true
    }

    // Jump to any day from the date picker — clamped so we never land in the future.
    func goTo(date: Date) {
        let cal = Calendar.current
        let picked = cal.startOfDay(for: date)
        let today = cal.startOfDay(for: .now)
        selectedDate = picked >= today ? .now : picked
        isTrackingToday = selectedDate.isToday
    }

    // Called on foreground and on the system's significant-time-change notification
    // (which fires at midnight). If the user was sitting on "today" and the calendar
    // day rolled over underneath them, move them to the real today — otherwise the
    // next thing they log gets stamped with yesterday's date. A user who deliberately
    // navigated to a past day stays where they are.
    func snapToTodayIfDayChanged() {
        guard isTrackingToday, !selectedDate.isToday else { return }
        selectedDate = .now
    }

    // The pure decision behind the HealthKit weight auto-import. Extracted so its truth
    // table can be tested without HealthKit, Supabase, or UserDefaults. Import a HK weight
    // sample as a new weight_logs row ONLY when all three hold:
    //   - the sample is from today (older readings aren't back-imported),
    //   - it wasn't written by this app (breaks the write→read→re-import echo loop), and
    //   - we haven't already imported one today (the once-per-day guard).
    // `now`/`calendar` are injectable purely for deterministic tests.
    nonisolated static func shouldImportHKWeight(
        sampleDate: Date,
        isFromThisApp: Bool,
        alreadySyncedToday: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(sampleDate, inSameDayAs: now) && !isFromThisApp && !alreadySyncedToday
    }
}
