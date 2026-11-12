import Foundation
import HealthKit
import Observation

enum NutritionMacro: String, Codable, CaseIterable, Identifiable {
    case calories, protein, carbs, fat, fiber
    var id: String { rawValue }
    var title: String { switch self {
    case .calories: "Calories"
    case .protein: "Protein"
    case .carbs: "Carbs"
    case .fat: "Fat"
    case .fiber: "Fiber"
    } }
    var identifier: HKQuantityTypeIdentifier { switch self {
    case .calories: .dietaryEnergyConsumed
    case .protein: .dietaryProtein
    case .carbs: .dietaryCarbohydrates
    case .fat: .dietaryFatTotal
    case .fiber: .dietaryFiber
    } }
    var unit: HKUnit { self == .calories ? .kilocalorie() : .gram() }
    func value(in day: DailySummary) -> Double { switch self {
    case .calories: day.calories
    case .protein: day.proteinG
    case .carbs: day.carbsG
    case .fat: day.fatG
    case .fiber: day.fiberG
    } }
}

struct NutritionSource: Codable, Hashable, Identifiable {
    let id: String
    let name: String
}

struct ImportedNutritionSample: Identifiable {
    let id: UUID
    let macro: NutritionMacro
    let date: Date
    let value: Double
    let source: NutritionSource
}

/// Pure reconciliation: exactly one source per nutrient, never add Health to meals.
/// UUIDs prevent repeated query results being counted twice. No timestamp guessing.
enum NutritionResolver {
    static func resolve(_ local: DailySummary, selections: [NutritionMacro: NutritionSource],
                        samples: [ImportedNutritionSample], calendar: Calendar = .current) -> DailySummary {
        var result = local
        for (macro, source) in selections {
            var seen = Set<UUID>()
            let matching = samples.filter {
                $0.macro == macro && $0.source.id == source.id && calendar.isDate($0.date, inSameDayAs: local.date)
                    && $0.value.isFinite && $0.value >= 0 && seen.insert($0.id).inserted
            }
            let value = matching.reduce(0) { $0 + $1.value }
            if matching.isEmpty { result.unavailableMacros.insert(macro) }
            else { result.unavailableMacros.remove(macro) }
            result.nutritionSources[macro] = source.name
            switch macro {
            case .calories: result.calories = value
            case .protein: result.proteinG = value
            case .carbs: result.carbsG = value
            case .fat: result.fatG = value
            case .fiber: result.fiberG = value
            }
        }
        return result
    }
}

/// Health values remain in memory on this device. Only per-account source preferences
/// are persisted. Full range rereads reconcile edits/deletions without append-only imports.
@Observable @MainActor
final class NutritionImportStore {
    static let shared = NutritionImportStore()
    private(set) var selections: [NutritionMacro: NutritionSource] = [:]
    private(set) var availableSources: [NutritionMacro: [NutritionSource]] = [:]
    private(set) var samples: [ImportedNutritionSample] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var revision = 0
    private(set) var owner: UUID?
    private var generation = UUID()
    private let health = HKHealthStore()
    private let defaults: UserDefaults
    private let allowsHealthQueries: Bool
    private var observers: [HKObserverQuery] = []
    private var pendingReads = 0
    private(set) var preview = false
    private var fixtureSamples: [ImportedNutritionSample] = []
    var isEnabled: Bool { !selections.isEmpty }
    init(defaults: UserDefaults = .standard, allowsHealthQueries: Bool = true) { self.defaults = defaults; self.allowsHealthQueries = allowsHealthQueries }
    private func key(_ owner: UUID) -> String { "nutritionSources.v1.\(owner.uuidString)" }
    func setAccount(_ id: UUID?) {
        guard owner != id else { return }
        observers.forEach { health.stop($0) }; observers = []
        generation = UUID(); owner = id; samples = []; availableSources = [:]; errorMessage = nil
        if allowsHealthQueries { invalidateWidget() }
        selections = id.flatMap { defaults.data(forKey: key($0)) }
            .flatMap { try? JSONDecoder().decode([NutritionMacro: NutritionSource].self, from: $0) } ?? [:]
        revision += 1
        startObserving()
    }
    func select(_ source: NutritionSource?, for macro: NutritionMacro) {
        guard owner != nil || preview else { return }
        selections[macro] = source
        if !preview, let owner, let data = try? JSONEncoder().encode(selections) { defaults.set(data, forKey: key(owner)) }
        generation = UUID(); revision += 1
        if preview { samples = fixtureSamples; return }
        if macro == .protein && allowsHealthQueries { invalidateWidget() }
        startObserving()
        Task { await refresh(from: .now, through: .now) }
    }
    func sourceName(for macro: NutritionMacro) -> String { selections[macro]?.name ?? "Footing" }
    func resolved(_ local: DailySummary) -> DailySummary {
        NutritionResolver.resolve(local, selections: selections, samples: samples)
    }
    func requestAccess() async {
        guard allowsHealthQueries, !preview, owner != nil, HKHealthStore.isHealthDataAvailable() else { return }
        do {
            let types = Set(NutritionMacro.allCases.map { HKObjectType.quantityType(forIdentifier: $0.identifier)! })
            try await health.requestAuthorization(toShare: [], read: types)
            await discoverSources()
        } catch { errorMessage = "Couldn’t request nutrition access. Try again or review Footing’s permissions in Health." }
    }
    func discoverSources() async {
        let start = Calendar.current.date(byAdding: .day, value: -89, to: .now)!
        await refresh(from: start, through: .now, discover: true)
    }
    func refresh(from start: Date, through end: Date, discover: Bool = false) async {
        guard allowsHealthQueries, !preview, owner != nil, HKHealthStore.isHealthDataAvailable(), discover || isEnabled else { return }
        let token = generation
        let calendar = Calendar.current
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
        pendingReads += 1; isLoading = true
        defer { pendingReads -= 1; isLoading = pendingReads > 0 }
        var fetched: [ImportedNutritionSample] = []
        do {
            for macro in NutritionMacro.allCases where discover || selections[macro] != nil {
                fetched += try await read(macro, from: lower, to: upper)
            }
            guard token == generation, !Task.isCancelled else { return }
            samples.removeAll { $0.date >= lower && $0.date < upper }
            samples += fetched
            if discover {
                availableSources = Dictionary(uniqueKeysWithValues: NutritionMacro.allCases.map { macro in
                    (macro, Dictionary(grouping: fetched.filter { $0.macro == macro }.map(\.source), by: \.id).values.compactMap(\.first).sorted { $0.name < $1.name })
                })
            }
            errorMessage = nil
        } catch {
            guard token == generation else { return }
            // Do not continue displaying an old value as current after a failed reread.
            samples.removeAll { $0.date >= lower && $0.date < upper }
            errorMessage = "Nutrition couldn’t refresh. Imported values are unavailable; Footing totals won’t be substituted."
        }
    }
    private func read(_ macro: NutritionMacro, from start: Date, to end: Date) async throws -> [ImportedNutritionSample] {
        let type = HKQuantityType.quantityType(forIdentifier: macro.identifier)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                let ownBundle = Bundle.main.bundleIdentifier
                let values = (results as? [HKQuantitySample] ?? []).compactMap { sample -> ImportedNutritionSample? in
                    let source = sample.sourceRevision.source
                    guard source.bundleIdentifier != ownBundle, sample.startDate >= start, sample.startDate < end else { return nil }
                    return .init(id: sample.uuid, macro: macro, date: sample.startDate,
                                 value: sample.quantity.doubleValue(for: macro.unit),
                                 source: .init(id: source.bundleIdentifier, name: source.name))
                }
                continuation.resume(returning: values)
            }
            health.execute(query)
        }
    }
    private func invalidateWidget() {
        SharedStore.save(.init(proteinToday: 0, proteinGoal: 0, updatedAt: .now, showsDose: false, nutritionUnknown: true))
    }
    private func startObserving() {
        if !isEnabled { observers.forEach { health.stop($0) }; observers = []; samples = []; return }
        guard allowsHealthQueries, !preview, owner != nil, isEnabled, observers.isEmpty, HKHealthStore.isHealthDataAvailable() else { return }
        for macro in NutritionMacro.allCases {
            let query = HKObserverQuery(sampleType: HKQuantityType.quantityType(forIdentifier: macro.identifier)!, predicate: nil) { [weak self] _, done, _ in
                Task { @MainActor in
                    // Clear stale values immediately; consumers reread their displayed range.
                    self?.generation = UUID()
                    self?.samples = []; self?.revision += 1
                    done()
                }
            }
            observers.append(query); health.execute(query)
        }
    }
    #if DEBUG
    func loadPreview() {
        guard !preview else { return }
        preview = true; selections = [.carbs: .init(id: "demo.diabetes", name: "Diabetes tracker")]
        let source = selections[.carbs]!
        availableSources = [.carbs: [source], .protein: [.init(id: "demo.food", name: "Food tracker")]]
        samples = ProcessInfo.processInfo.arguments.contains("--nutrition-missing-preview") ? [] : [.init(id: UUID(), macro: .carbs, date: .now, value: 142, source: source)]
        fixtureSamples = samples
    }
    #endif
}
