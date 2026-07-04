import Observation
import Foundation

// SWIFT CONCEPT — @Observable + @MainActor together: all property reads/writes and
// method calls happen on the main thread, so SwiftUI view updates are always safe.
// Think of @MainActor as a compile-time guarantee that replaces manual DispatchQueue.main.async calls.

@Observable
@MainActor
final class TodayViewModel {
    private let foodLogRepo  = FoodLogRepository()
    private let goalRepo     = GoalRepository()
    private let waterRepo    = WaterRepository()
    private let bodyCompRepo = BodyCompositionRepository()

    var selectedDate: Date = .now
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
    var totalFiberG:   Double { foodLogs.reduce(0) { $0 + $1.totalFiberG   } }

    var isToday: Bool { selectedDate.isToday }

    // Water tracking
    var waterIntakeMl: Double = 0
    var waterGoalMl:   Double = 2000

    // Body composition
    var bodyComp = BodyCompositionData()

    // HealthKit data for the selected date
    var activeCalories: Double  = 0
    var restingHeartRate: Double? = nil
    var hrv: Double?            = nil
    var sleepHours: Double?     = nil

    var netCalories: Double { totalCalories - activeCalories }
    var healthDataAvailable: Bool {
        activeCalories > 0 || restingHeartRate != nil || hrv != nil || sleepHours != nil
    }

    func loadData() async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        async let bodyCompTask = buildBodyCompData()

        do {
            async let logsTask  = foodLogRepo.fetchLogs(for: selectedDate)
            async let goalTask  = goalRepo.fetchGoal(for: selectedDate)
            async let waterTask = waterRepo.fetchTotal(for: selectedDate)
            let (logs, goal, water) = try await (logsTask, goalTask, waterTask)
            foodLogs      = logs
            dailyGoal     = goal
            waterIntakeMl = water
            waterGoalMl   = goal?.waterMlTarget ?? 2000
        } catch {
            errorMessage = error.localizedDescription
        }

        bodyComp = await bodyCompTask
        await loadHealthData()
        await FavoritesStore.shared.loadIfNeeded()
    }

    private func buildBodyCompData() async -> BodyCompositionData {
        let hk = HealthKitManager.shared
        var data = BodyCompositionData()

        async let savedTask = try? bodyCompRepo.fetchLatest()
        var hkWeight: (value: Double, date: Date)? = nil
        var hkBodyFat: (value: Double, date: Date)? = nil
        var hkBMI: (value: Double, date: Date)? = nil
        var hkLBM: (value: Double, date: Date)? = nil

        if hk.isAvailable {
            async let w  = hk.fetchMostRecentWeight()
            async let bf = hk.fetchMostRecentBodyFat()
            async let b  = hk.fetchMostRecentBMI()
            async let l  = hk.fetchMostRecentLBM()
            (hkWeight, hkBodyFat, hkBMI, hkLBM) = await (w, bf, b, l)
        }

        let saved = await savedTask

        // Weight: prefer HK; auto-sync today's reading once per calendar day
        if let w = hkWeight {
            data.weightKg     = w.value
            data.weightFromHK = true
            data.latestDate   = w.date
            if Calendar.current.isDateInToday(w.date) {
                let today = Date().isoDateString
                if UserDefaults.standard.string(forKey: "lastHKWeightSyncDate") != today {
                    try? await bodyCompRepo.upsert(date: today, weightKg: w.value, bodyFatPct: nil, bmi: nil, leanBodyMassKg: nil, source: "healthkit")
                    if let userId = try? await supabase.auth.session.user.id {
                        try? await supabase.from("weight_logs")
                            .insert(NewWeightLog(userId: userId, weightKg: w.value, source: "healthkit"))
                            .execute()
                    }
                    UserDefaults.standard.set(today, forKey: "lastHKWeightSyncDate")
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

    func loadHealthData() async {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else { return }
        try? await hk.requestAuthorization()
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

    func addWater(_ ml: Double) async {
        do {
            try await waterRepo.add(ml, for: selectedDate)
            waterIntakeMl += ml
        } catch {
            errorMessage = "Couldn't log water."
        }
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    func goToNextDay() {
        guard !selectedDate.isToday else { return }  // don't navigate into the future
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    func goToToday() { selectedDate = .now }
}
