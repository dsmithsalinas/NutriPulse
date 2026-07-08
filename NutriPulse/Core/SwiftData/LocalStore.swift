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

    // Always tombstone, never hard-delete. A pendingCreate row may have its create
    // request in flight right now — dropping it locally would leave the server row
    // orphaned, and the next pull would faithfully resurrect the entry the user
    // just deleted. A DELETE against a row that was never created is a harmless
    // no-op, so tombstoning is safe in both directions.
    func markFoodLogDeleted(id: UUID) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        guard let log = try context.fetch(descriptor).first else { return }
        log.syncState = "pendingDelete"
        log.revision += 1
        try context.save()
    }

    // Editing an unsynced row keeps it pendingCreate — it hasn't reached the server
    // yet, so there's nothing to "update" there, only to create with the new values.
    // Anything already synced needs a real push, since SyncEngine's create path
    // upserts with ignoreDuplicates (skips existing rows rather than updating them).
    // The revision bump is what lets an in-flight push detect that it raced this edit.
    func updateFoodLog(id: UUID, meal: String, quantity: Double) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        guard let log = try context.fetch(descriptor).first else { return }
        log.meal = meal
        log.quantity = quantity
        log.revision += 1
        if log.syncState == "synced" {
            log.syncState = "pendingUpdate"
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

    func pendingUpdateFoodLogs() throws -> [SDFoodLog] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<SDFoodLog>(
            predicate: #Predicate { $0.syncState == "pendingUpdate" }
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

    // ── Push completion (compare-and-set) ────────────────────────────────────
    // Each of these runs *after* a network round trip, during which the user may
    // have edited or deleted the row. They only commit the "synced" transition if
    // the row is still in the state the push assumed. Unconditionally writing
    // "synced" here is what used to resurrect deleted logs and revert live edits.

    func markFoodLogCreated(id: UUID, pushedRevision: Int) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        guard let log = try context.fetch(descriptor).first else { return }
        // Deleted mid-flight → leave the tombstone alone; the delete push handles it.
        guard log.syncState == "pendingCreate" else { return }
        if log.revision == pushedRevision {
            log.syncState = "synced"
        } else {
            // Edited mid-flight. The remote row exists now, so the newer values need
            // a real UPDATE — another ignoreDuplicates upsert would silently skip them.
            log.syncState = "pendingUpdate"
        }
        try context.save()
    }

    func markFoodLogUpdated(id: UUID, pushedRevision: Int) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        guard let log = try context.fetch(descriptor).first else { return }
        // Changed again or deleted mid-flight → keep the pending state so it pushes again.
        guard log.syncState == "pendingUpdate", log.revision == pushedRevision else { return }
        log.syncState = "synced"
        try context.save()
    }

    func removeFoodLogAfterDelete(id: UUID) throws {
        guard let context else { return }
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        guard let log = try context.fetch(descriptor).first else { return }
        guard log.syncState == "pendingDelete" else { return }
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

    // Filtering by userId matters even though this is "just a cache": goals are the
    // one cached entity with no natural per-user scoping in the UI, so an unowned
    // row would silently supply another account's calorie targets.
    func fetchGoal(for date: Date, userId: UUID) throws -> DailyGoal? {
        guard let context else { return nil }
        let dateStr = date.isoDateString
        let descriptor = FetchDescriptor<SDDailyGoal>(
            sortBy: [SortDescriptor(\.effectiveDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
            .first { $0.userId == userId && $0.effectiveDate <= dateStr }?
            .asDailyGoal
    }

    func upsertGoal(_ goal: DailyGoal) throws {
        guard let context else { return }
        let id = goal.id
        let descriptor = FetchDescriptor<SDDailyGoal>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.userId        = goal.userId
            existing.effectiveDate = goal.effectiveDate
            existing.calories      = goal.calories
            existing.proteinG      = goal.proteinG
            existing.carbsG        = goal.carbsG
            existing.fatG          = goal.fatG
            existing.fiberG        = goal.fiberG
            existing.waterMlTarget = goal.waterMlTarget
        } else {
            let sdGoal = SDDailyGoal(
                id: goal.id, userId: goal.userId, effectiveDate: goal.effectiveDate,
                calories: goal.calories, proteinG: goal.proteinG,
                carbsG: goal.carbsG, fatG: goal.fatG,
                fiberG: goal.fiberG, waterMlTarget: goal.waterMlTarget
            )
            context.insert(sdGoal)
        }
        try context.save()
    }

    // MARK: - Sign-out / account deletion

    // Wipes every cached row. Called on sign-out (which covers account deletion, since
    // that signs out too). Three things go wrong without it:
    //   1. The next account on this device reads the previous user's cached goals.
    //   2. The previous user's unsynced rows get pushed under the new user's JWT,
    //      are rejected by RLS, and stick at "pending" forever, inflating the badge.
    //   3. "Delete Account" promises the data is gone while it sits in plaintext
    //      SQLite on the device.
    func wipeAll() throws {
        guard let context else { return }
        try context.delete(model: SDFoodLog.self)
        try context.delete(model: SDWaterLog.self)
        try context.delete(model: SDDailyGoal.self)
        try context.save()
    }

    // MARK: - Pending count

    func pendingCount() throws -> Int {
        guard let context else { return 0 }
        let foodCreate = try context.fetchCount(FetchDescriptor<SDFoodLog>(
            predicate: #Predicate { $0.syncState == "pendingCreate" }
        ))
        let foodUpdate = try context.fetchCount(FetchDescriptor<SDFoodLog>(
            predicate: #Predicate { $0.syncState == "pendingUpdate" }
        ))
        let foodDelete = try context.fetchCount(FetchDescriptor<SDFoodLog>(
            predicate: #Predicate { $0.syncState == "pendingDelete" }
        ))
        let waterCreate = try context.fetchCount(FetchDescriptor<SDWaterLog>(
            predicate: #Predicate { $0.syncState == "pendingCreate" }
        ))
        return foodCreate + foodUpdate + foodDelete + waterCreate
    }
}
