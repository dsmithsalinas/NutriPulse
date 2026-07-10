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

    // HealthKit data for the selected date
    // nil = HealthKit reported nothing (no data, or read access denied — HealthKit won't
    // say which). 0 would be a claim we can't support.
    var activeCalories: Double? = nil
    var restingHeartRate: Double? = nil
    var hrv: Double?            = nil
    var sleepHours: Double?     = nil

    var netCalories: Double { totalCalories - (activeCalories ?? 0) }

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

    // A supportive, forward-looking nudge for the current day when the user is pacing under
    // their targets. GLP-1 suppresses appetite, so under-eating (and losing muscle) is the real
    // risk here — the framing protects results, it never scolds. Only surfaces on today, only in
    // the afternoon/evening (mornings are legitimately low), and only when genuinely behind.
    var nudge: DayNudge? {
        guard isToday, let goal = dailyGoal, goal.proteinG > 0 else { return nil }
        guard Calendar.current.component(.hour, from: .now) >= 14 else { return nil }

        let proteinLeft = goal.proteinG - totalProteinG
        let calorieLeft = goal.calories - totalCalories
        let proteinPct = totalProteinG / goal.proteinG
        let caloriePct = goal.calories > 0 ? totalCalories / goal.calories : 1

        // Behind on the day's priority (protein) or well under on energy…
        guard proteinPct < 0.7 || caloriePct < 0.6 else { return nil }
        // …but not when they're basically there — no nagging over the last few grams.
        guard proteinLeft > 15 || calorieLeft > 400 else { return nil }

        let pLeft = max(Int(proteinLeft.rounded()), 0)
        let cLeft = max(Int(calorieLeft.rounded()), 0)
        return DayNudge(
            headline: "You've got room to finish strong",
            body: "You're pacing a little under today. A protein-forward dinner keeps your muscle protected while the medication does its part — you're about \(pLeft)g of protein and \(cLeft) calories from your goals.",
            cta: "Ask Pulse for dinner ideas",
            prompt: "I have about \(pLeft)g of protein and \(cLeft) calories left today — what should I eat to finish strong?"
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

    var healthDataAvailable: Bool {
        activeCalories != nil || restingHeartRate != nil || hrv != nil || sleepHours != nil
    }

    func loadData() async {
        let wasClosed = allRingsClosed
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

        latestGLP1 = (try? await glp1Task)?.first
        bodyComp = await bodyCompTask
        await loadHealthData()
        await FavoritesStore.shared.loadIfNeeded()
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
            (hkWeight, hkBodyFat, hkBMI, hkLBM) = await (w, bf, b, l)
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
            if Calendar.current.isDateInToday(w.date), !w.isFromThisApp, !alreadySyncedToday {
                UserDefaults.standard.set(today, forKey: "lastHKWeightSyncDate")
                try? await bodyCompRepo.upsert(date: today, weightKg: w.value, bodyFatPct: nil, bmi: nil, leanBodyMassKg: nil, source: "healthkit")
                if let userId = try? await supabase.auth.session.user.id {
                    try? await supabase.from("weight_logs")
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
}
