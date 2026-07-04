import HealthKit
import Observation

@Observable
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private let store = HKHealthStore()

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
    }

    // MARK: - Active Calories

    func fetchActiveCalories(for date: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let (start, end) = dayInterval(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
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
    func fetchSleepHours(for date: Date) async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let nightStart = cal.date(byAdding: .hour, value: -18, to: dayStart)!
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
                let totalSeconds = samples
                    .filter { sample in
                        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
                        switch value {
                        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM: return true
                        default: return false
                        }
                    }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Body Composition (most recent sample regardless of date)

    func fetchMostRecentWeight() async -> (value: Double, date: Date)? {
        await fetchMostRecent(identifier: .bodyMass, unit: .gramUnit(with: .kilo))
    }

    func fetchMostRecentBodyFat() async -> (value: Double, date: Date)? {
        // HK stores body fat as fraction 0.0–1.0; convert to percentage
        guard let r = await fetchMostRecent(identifier: .bodyFatPercentage, unit: .percent()) else { return nil }
        return (r.value * 100, r.date)
    }

    func fetchMostRecentBMI() async -> (value: Double, date: Date)? {
        await fetchMostRecent(identifier: .bodyMassIndex, unit: .count())
    }

    func fetchMostRecentLBM() async -> (value: Double, date: Date)? {
        await fetchMostRecent(identifier: .leanBodyMass, unit: .gramUnit(with: .kilo))
    }

    private func fetchMostRecent(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> (value: Double, date: Date)? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
            }
            store.execute(query)
        }
    }

    // MARK: - Write

    func saveWeight(_ kg: Double, date: Date) async throws {
        guard isAvailable else { return }
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(sample) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
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

    private func saveQuantity(_ value: Double, unit: HKUnit, identifier: HKQuantityTypeIdentifier, date: Date) async throws {
        guard isAvailable, let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
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

    // MARK: - Helpers

    private func dayInterval(for date: Date) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }
}
