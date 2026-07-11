import HealthKit
import Observation

@Observable
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    // Device capability ONLY — true on every iPhone, whatever the user granted. This was
    // being used as "Apple Health is connected", so onboarding showed a green
    // "Apple Health connected" checkmark and Profile showed "Connected" even for a user
    // who had just denied every permission.
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let didRequestKey = "healthKitAuthorizationRequested"

    // HealthKit never reveals whether *read* access was granted — denied reads simply
    // return no samples, indistinguishable from "no data". Write access it does reveal.
    // So the honest question isn't "are we connected" but "have we asked yet", and that's
    // what drives the UI: not-asked → offer to connect; asked-but-empty → point at the
    // Health app rather than claiming a connection or reporting a confident zero.
    //
    // Stored rather than computed from UserDefaults so @Observable tracks it: a user who
    // taps Connect and then denies everything produces no other state change, and a
    // computed property would leave the dead "Connect" button on screen.
    private(set) var hasRequestedAuthorization: Bool

    // Best available proxy for "the user granted us something". Read-only grants report
    // false here, which is why it gates only the onboarding/profile copy — never whether
    // we bother querying.
    var isSharingAuthorized: Bool {
        writeTypes.contains { store.authorizationStatus(for: $0) == .sharingAuthorized }
    }

    private let store = HKHealthStore()

    private init() {
        // Assign before touching `store` / `writeTypes`: reading them inside a closure
        // captures self, which isn't legal until every stored property is initialized.
        hasRequestedAuthorization = UserDefaults.standard.bool(forKey: Self.didRequestKey)
        if !hasRequestedAuthorization {
            // Installed before this flag existed: a decided share status proves we asked.
            hasRequestedAuthorization = writeTypes.contains {
                store.authorizationStatus(for: $0) != .notDetermined
            }
        }
    }

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
        HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!,
        HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
        HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
    ]

    private let writeTypes: Set<HKSampleType> = [
        HKSampleType.quantityType(forIdentifier: .bodyMass)!,
        HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!,
        HKSampleType.quantityType(forIdentifier: .bodyMassIndex)!,
        HKSampleType.quantityType(forIdentifier: .leanBodyMass)!,
        HKSampleType.quantityType(forIdentifier: .dietaryWater)!,
    ]

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        // iOS presents the permission sheet exactly once per type. Record that we've been
        // through it, so the UI can stop offering a "Connect" button that does nothing.
        UserDefaults.standard.set(true, forKey: Self.didRequestKey)
        hasRequestedAuthorization = true
    }

    #if DEBUG
    // Dev-only: seed ~2 weeks of demo Apple Health data (active energy, resting HR, HRV, sleep,
    // steps) on this simulator/device so the "Today's signals" card and the coach's health context
    // have something to show in demos. HealthKit data is device-local, so this affects only the
    // device it's run on and is never compiled into release builds.
    func seedDemoHealthData() async {
        guard isAvailable else { return }
        let active  = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let resting = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let hrv     = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let steps   = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let sleep   = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        // One prompt that grants everything a demo needs: WRITE for the types we seed here
        // (so store.save succeeds) PLUS the app's normal read+write set (so Today's signals
        // and the coach can actually read the samples back). Without the read grant the
        // seeded samples are invisible — HealthKit returns nothing for un-authorized reads.
        let seedShareTypes = writeTypes.union([active, resting, hrv, steps, sleep])
        try? await store.requestAuthorization(toShare: seedShareTypes, read: readTypes)
        // Flip the app to "connected" so Profile/onboarding stop offering a dead Connect
        // button and Today starts querying — same state a real Connect tap would leave.
        UserDefaults.standard.set(true, forKey: Self.didRequestKey)
        hasRequestedAuthorization = true

        let cal = Calendar.current
        let bpm = HKUnit.count().unitDivided(by: .minute())
        var samples: [HKSample] = []

        for d in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: -d, to: .now),
                  let morning = cal.date(bySettingHour: 7, minute: 0, second: 0, of: day),
                  let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day),
                  let night = cal.date(bySettingHour: 21, minute: 0, second: 0, of: day)
            else { continue }

            let activeKcal = 420.0 + Double((d * 37) % 260)            // 420…680 kcal
            samples.append(HKQuantitySample(type: active, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: activeKcal), start: morning, end: noon))

            let stepCount = 7200.0 + Double((d * 611) % 5200)          // 7.2k…12.4k
            samples.append(HKQuantitySample(type: steps, quantity: HKQuantity(unit: .count(), doubleValue: stepCount), start: morning, end: night))

            let rhr = 56.0 + Double((d * 3) % 9)                       // 56…64 bpm
            samples.append(HKQuantitySample(type: resting, quantity: HKQuantity(unit: bpm, doubleValue: rhr), start: morning, end: morning))

            for h in [3, 6] {
                guard let t = cal.date(bySettingHour: h, minute: 0, second: 0, of: day) else { continue }
                let ms = 34.0 + Double((d * 5 + h) % 26)               // 34…60 ms
                samples.append(HKQuantitySample(type: hrv, quantity: HKQuantity(unit: .secondUnit(with: .milli), doubleValue: ms), start: t, end: t))
            }

            if let prev = cal.date(byAdding: .day, value: -1, to: day),
               let sleepStart = cal.date(bySettingHour: 23, minute: 0, second: 0, of: prev) {
                let sleepEnd = sleepStart.addingTimeInterval((6.5 * 60 + Double((d * 17) % 90)) * 60)  // 6.5…8h
                samples.append(HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, start: sleepStart, end: sleepEnd))
            }
        }
        try? await store.save(samples)
    }
    #endif

    // MARK: - Active Calories

    // Returns nil when HealthKit has nothing to report — which includes the case where the
    // user denied read access, since HealthKit deliberately makes those indistinguishable.
    // Coalescing to 0 here made the Today card state "0 kcal" as though it were a measured
    // fact, and it was the only fetcher that didn't return an optional.
    func fetchActiveCalories(for date: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        let (start, end) = dayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .kilocalorie()))
            }
            store.execute(query)
        }
    }

    // MARK: - Resting Heart Rate

    func fetchRestingHeartRate(for date: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let (start, end) = dayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let bpm = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    // MARK: - HRV

    func fetchHRV(for date: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let (start, end) = dayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let ms = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: ms)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep

    // Returns hours slept during the night leading into `date` (6pm prior evening → 10am morning).
    //
    // `dayStart` is midnight, so 6pm the previous evening is midnight − 6 hours. The old
    // `-18` landed on 6 AM of the *previous day*, opening a 28-hour window: with
    // .strictStartDate, every sleep-stage segment starting after 6am yesterday counted —
    // the tail of the night before last (Apple Watch routinely writes stages starting
    // 6–8am) plus all of yesterday's naps. Typically inflated a Watch user's night by
    // an hour or more.
    func fetchSleepHours(for date: Date) async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let nightStart = cal.date(byAdding: .hour, value:  -6, to: dayStart)!
        let nightEnd   = cal.date(byAdding: .hour, value:  10, to: dayStart)!
        let predicate = HKQuery.predicateForSamples(withStart: nightStart, end: nightEnd, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepIntervals = samples
                    .filter { sample in
                        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
                        switch value {
                        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM: return true
                        default: return false
                        }
                    }
                    .map { (start: $0.startDate, end: $0.endDate) }
                // Merge overlaps rather than summing every sample: Apple Watch and a sleep
                // app (AutoSleep, Oura, Whoop) each write their own asleep samples for the
                // same night, so a plain sum double-counts and can report ~14h for a 7h night.
                let totalSeconds = Self.mergedDuration(of: asleepIntervals)
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }
            self.store.execute(query)
        }
    }

    // Total time covered by a set of (possibly overlapping) [start, end) intervals, counting
    // any overlapping stretch once. Sort by start, then sweep, extending the current run
    // while the next interval starts before the run ends.
    nonisolated static func mergedDuration(of intervals: [(start: Date, end: Date)]) -> TimeInterval {
        let sorted = intervals.filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        guard let first = sorted.first else { return 0 }
        var total: TimeInterval = 0
        var runStart = first.start
        var runEnd   = first.end
        for interval in sorted.dropFirst() {
            if interval.start > runEnd {
                total += runEnd.timeIntervalSince(runStart)
                runStart = interval.start
                runEnd   = interval.end
            } else if interval.end > runEnd {
                runEnd = interval.end
            }
        }
        total += runEnd.timeIntervalSince(runStart)
        return total
    }

    // MARK: - Body Composition (most recent sample regardless of date)

    // `isFromThisApp` exists to break an echo loop. The app writes a weigh-in to
    // HealthKit, then reads "the most recent HealthKit weight" back and auto-imports it as
    // a *new* weight_logs row — its own write, laundered into a second row for the same
    // day. Callers display these samples but must not re-import them.
    struct HKMeasurement {
        let value: Double
        let date: Date
        let isFromThisApp: Bool
    }

    func fetchMostRecentWeight() async -> HKMeasurement? {
        await fetchMostRecent(identifier: .bodyMass, unit: .gramUnit(with: .kilo))
    }

    func fetchMostRecentBodyFat() async -> HKMeasurement? {
        // HK stores body fat as fraction 0.0–1.0; convert to percentage
        guard let r = await fetchMostRecent(identifier: .bodyFatPercentage, unit: .percent()) else { return nil }
        return HKMeasurement(value: r.value * 100, date: r.date, isFromThisApp: r.isFromThisApp)
    }

    func fetchMostRecentBMI() async -> HKMeasurement? {
        await fetchMostRecent(identifier: .bodyMassIndex, unit: .count())
    }

    func fetchMostRecentLBM() async -> HKMeasurement? {
        await fetchMostRecent(identifier: .leanBodyMass, unit: .gramUnit(with: .kilo))
    }

    private func fetchMostRecent(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> HKMeasurement? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let ownBundleId = Bundle.main.bundleIdentifier
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: HKMeasurement(
                    value: sample.quantity.doubleValue(for: unit),
                    date: sample.endDate,
                    isFromThisApp: sample.sourceRevision.source.bundleIdentifier == ownBundleId
                ))
            }
            store.execute(query)
        }
    }

    // MARK: - Write

    func saveWeight(_ kg: Double, date: Date) async throws {
        try await saveQuantity(kg, unit: .gramUnit(with: .kilo), identifier: .bodyMass, date: date)
    }

    func saveBodyFat(_ pct: Double, date: Date) async throws {
        // Convert display percent → HK fraction before writing
        try await saveQuantity(pct / 100, unit: .percent(), identifier: .bodyFatPercentage, date: date)
    }

    func saveBMI(_ bmi: Double, date: Date) async throws {
        try await saveQuantity(bmi, unit: .count(), identifier: .bodyMassIndex, date: date)
    }

    func saveLeanBodyMass(_ kg: Double, date: Date) async throws {
        try await saveQuantity(kg, unit: .gramUnit(with: .kilo), identifier: .leanBodyMass, date: date)
    }

    // Replaces this app's sample for that day rather than appending another. The body
    // composition sheet pre-fills all four fields, so correcting one typo re-wrote all
    // four as brand-new `.now`-stamped samples — fix a value three times and Apple Health
    // shows three weights, three body fats, three BMIs and three lean-body-masses for the
    // same day. Nothing ever deleted the app's earlier samples.
    //
    // Only ever deletes samples this app authored (HKSource.default()); a user's Withings
    // scale or manual Health entry is never touched.
    private func saveQuantity(_ value: Double, unit: HKUnit, identifier: HKQuantityTypeIdentifier, date: Date) async throws {
        guard isAvailable, let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }

        await deleteOwnSamples(of: type, on: date)

        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: unit, doubleValue: value),
            start: date, end: date
        )
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            store.save(sample) { _, error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    private func deleteOwnSamples(of type: HKQuantityType, on date: Date) async {
        let (start, end) = dayInterval(for: date)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: end),
            HKQuery.predicateForObjects(from: HKSource.default()),
        ])
        // A "no objects matched" error is the normal first-write case, not a failure.
        _ = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            store.deleteObjects(of: type, predicate: predicate) { _, _, error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    // MARK: - Helpers

    private func dayInterval(for date: Date) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }
}
