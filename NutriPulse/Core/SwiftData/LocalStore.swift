import SwiftData
import Foundation

// Source of truth for local reads. SyncEngine populates it from Supabase;
// ViewModels write to it immediately and read from it for instant, offline-safe UI.
@MainActor
final class LocalStore {
    static let shared = LocalStore()
    private var container: ModelContainer?
    private var context: ModelContext? { container?.mainContext }

    private init() {}

    func configure(with container: ModelContainer) {
        self.container = container
    }

    // MARK: - Food Logs

    func fetchFoodLogs(for date: Date, userId: UUID) throws -> [FoodLog] {
        guard let context else { return [] }
        let dateStr = date.isoDateString
        let descriptor = FetchDescriptor<SDFoodLog>(
            predicate: #Predicate { $0.logDate == dateStr },
            sortBy: [SortDescriptor(\.loggedAt)]
        )
        return try context.fetch(descriptor)
            .filter { $0.userId == userId && $0.syncState != "pendingDelete" }
            .map(\.asFoodLog)
    }

    func insertFoodLog(
        id: UUID,
        userId: UUID,
        logDate: String,
        meal: String,
        foodItemId: UUID,
        foodItemName: String,
        quantity: Double,
        caloriesSnapshot: Double,
        proteinGSnapshot: Double,
        carbsGSnapshot: Double,
        fatGSnapshot: Double,
        fiberGSnapshot: Double
    ) throws {
        guard let context else { return }
        let log = SDFoodLog(
            id: id, userId: userId, logDate: logDate, meal: meal,
            foodItemId: foodItemId, foodItemName: foodItemName, quantity: quantity,
            caloriesSnapshot: caloriesSnapshot, proteinGSnapshot: proteinGSnapshot,
            carbsGSnapshot: carbsGSnapshot, fatGSnapshot: fatGSnapshot,
            fiberGSnapshot: fiberGSnapshot
        )
        context.insert(log)
        try context.save()
    }

    func markFoodLogDeleted(id: UUID) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        guard let log = try context.fetch(descriptor).first else { return }
        if log.syncState == "pendingCreate" {
            context.delete(log)
        } else {
            log.syncState = "pendingDelete"
        }
        try context.save()
    }

    func pendingFoodLogs() throws -> [SDFoodLog] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<SDFoodLog>(
            predicate: #Predicate { $0.syncState == "pendingCreate" }
        )
        return try context.fetch(descriptor)
    }

    func deletedFoodLogs() throws -> [SDFoodLog] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<SDFoodLog>(
            predicate: #Predicate { $0.syncState == "pendingDelete" }
        )
        return try context.fetch(descriptor)
    }

    func markFoodLogSynced(id: UUID) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        guard let log = try context.fetch(descriptor).first else { return }
        log.syncState = "synced"
        try context.save()
    }

    func removeFoodLog(id: UUID) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        guard let log = try context.fetch(descriptor).first else { return }
        context.delete(log)
        try context.save()
    }

    func upsertFoodLog(from remote: FoodLog) throws {
        guard let context else { return }
        let id = remote.id
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            // Don't overwrite records with local pending changes
            guard existing.syncState == "synced" else { return }
            existing.quantity          = remote.quantity
            existing.caloriesSnapshot  = remote.caloriesSnapshot
            existing.proteinGSnapshot  = remote.proteinGSnapshot
            existing.carbsGSnapshot    = remote.carbsGSnapshot
            existing.fatGSnapshot      = remote.fatGSnapshot
            existing.fiberGSnapshot    = remote.fiberGSnapshot
            existing.foodItemName      = remote.foodItems?.name ?? existing.foodItemName
        } else {
            let log = SDFoodLog(
                id: remote.id, userId: remote.userId,
                logDate: remote.logDate, meal: remote.meal.rawValue,
                foodItemId: remote.foodItemId,
                foodItemName: remote.foodItems?.name ?? "Unknown",
                quantity: remote.quantity,
                caloriesSnapshot: remote.caloriesSnapshot,
                proteinGSnapshot: remote.proteinGSnapshot,
                carbsGSnapshot: remote.carbsGSnapshot,
                fatGSnapshot: remote.fatGSnapshot,
                fiberGSnapshot: remote.fiberGSnapshot,
                loggedAt: remote.loggedAt,
                syncState: "synced"
            )
            context.insert(log)
        }
        try context.save()
    }

    // MARK: - Water Logs

    func fetchWaterTotal(for date: Date, userId: UUID) throws -> Double {
        guard let context else { return 0 }
        let dateStr = date.isoDateString
        let descriptor = FetchDescriptor<SDWaterLog>(
            predicate: #Predicate { $0.logDate == dateStr }
        )
        return try context.fetch(descriptor)
            .filter { $0.userId == userId && $0.syncState != "pendingDelete" }
            .reduce(0) { $0 + $1.amountMl }
    }

    func insertWaterLog(id: UUID, userId: UUID, logDate: String, amountMl: Double) throws {
        guard let context else { return }
        let log = SDWaterLog(id: id, userId: userId, logDate: logDate, amountMl: amountMl)
        context.insert(log)
        try context.save()
    }

    func pendingWaterLogs() throws -> [SDWaterLog] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<SDWaterLog>(
            predicate: #Predicate { $0.syncState == "pendingCreate" }
        )
        return try context.fetch(descriptor)
    }

    func markWaterLogSynced(id: UUID) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDWaterLog>(predicate: #Predicate { $0.id == id })
        guard let log = try context.fetch(descriptor).first else { return }
        log.syncState = "synced"
        try context.save()
    }

    func upsertWaterLog(id: UUID, userId: UUID, logDate: String, amountMl: Double, loggedAt: Date) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDWaterLog>(predicate: #Predicate { $0.id == id })
        guard (try? context.fetch(descriptor).first) == nil else { return }
        let log = SDWaterLog(id: id, userId: userId, logDate: logDate, amountMl: amountMl,
                             loggedAt: loggedAt, syncState: "synced")
        context.insert(log)
        try context.save()
    }

    // MARK: - Daily Goals

    func fetchGoal(for date: Date) throws -> DailyGoal? {
        guard let context else { return nil }
        let dateStr = date.isoDateString
        let descriptor = FetchDescriptor<SDDailyGoal>(
            sortBy: [SortDescriptor(\.effectiveDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
            .first { $0.effectiveDate <= dateStr }?
            .asDailyGoal
    }

    func upsertGoal(_ goal: DailyGoal) throws {
        guard let context else { return }
        let id = goal.id
        let descriptor = FetchDescriptor<SDDailyGoal>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.effectiveDate = goal.effectiveDate
            existing.calories      = goal.calories
            existing.proteinG      = goal.proteinG
            existing.carbsG        = goal.carbsG
            existing.fatG          = goal.fatG
            existing.fiberG        = goal.fiberG
            existing.waterMlTarget = goal.waterMlTarget
        } else {
            let sdGoal = SDDailyGoal(
                id: goal.id, effectiveDate: goal.effectiveDate,
                calories: goal.calories, proteinG: goal.proteinG,
                carbsG: goal.carbsG, fatG: goal.fatG,
                fiberG: goal.fiberG, waterMlTarget: goal.waterMlTarget
            )
            context.insert(sdGoal)
        }
        try context.save()
    }

    // MARK: - Pending count

    func pendingCount() throws -> Int {
        guard let context else { return 0 }
        let foodCreate = try context.fetchCount(FetchDescriptor<SDFoodLog>(
            predicate: #Predicate { $0.syncState == "pendingCreate" }
        ))
        let foodDelete = try context.fetchCount(FetchDescriptor<SDFoodLog>(
            predicate: #Predicate { $0.syncState == "pendingDelete" }
        ))
        let waterCreate = try context.fetchCount(FetchDescriptor<SDWaterLog>(
            predicate: #Predicate { $0.syncState == "pendingCreate" }
        ))
        return foodCreate + foodDelete + waterCreate
    }
}
