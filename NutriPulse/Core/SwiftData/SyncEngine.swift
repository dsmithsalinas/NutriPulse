import Foundation
import Network
import Observation

// Bridges LocalStore ↔ Supabase.
// Push: flushes pendingCreate/pendingDelete records to Supabase.
// Pull: fetches recent remote records and upserts them into LocalStore.
// Runs automatically on: foreground, network reconnect, and explicit syncNow() calls.
@Observable
@MainActor
final class SyncEngine {
    static let shared = SyncEngine()

    var pendingCount = 0
    var isSyncing    = false
    var isOnline     = true
    private(set) var lastSyncAt: Date? = nil

    private let monitor      = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.nutripulse.network")

    private init() {}

    func configure() {
        startNetworkMonitoring()
        refreshPendingCount()
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = online
                if wasOffline && online {
                    await self.syncNow()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func refreshPendingCount() {
        pendingCount = (try? LocalStore.shared.pendingCount()) ?? 0
    }

    func syncNow() async {
        guard !isSyncing, isOnline else { return }
        isSyncing = true
        defer {
            isSyncing = false
            refreshPendingCount()
            lastSyncAt = .now
        }

        await pushPendingFoodLogs()
        await pushPendingWaterLogs()
        await pullGoal()
        await pullRecentFoodLogs()
        await pullTodayWater()
    }

    // Push this device's own pending writes only — no pull. Call this after
    // a local mutation (log/edit/delete a food entry, add water) so the write
    // reaches the server promptly without re-fetching the goal, 7 days of
    // food logs, and today's water on every single action. The full pull
    // side of syncNow() is reserved for where it actually earns its cost:
    // app foreground and network reconnect, where other devices/sessions
    // may have written data this one doesn't have yet.
    func pushPendingChanges() async {
        guard !isSyncing, isOnline else { return }
        isSyncing = true
        defer {
            isSyncing = false
            refreshPendingCount()
        }

        await pushPendingFoodLogs()
        await pushPendingWaterLogs()
    }

    // MARK: - Push food logs

    private func pushPendingFoodLogs() async {
        if let pending = try? LocalStore.shared.pendingFoodLogs() {
            for log in pending {
                do {
                    try await supabase.from("food_logs")
                        .upsert(FoodLogInsert(from: log), onConflict: "id", ignoreDuplicates: true)
                        .execute()
                    try? LocalStore.shared.markFoodLogSynced(id: log.id)
                } catch { }
            }
        }
        // Unlike creates, this is a real UPDATE — the row already exists
        // remotely, and upsert's ignoreDuplicates would otherwise skip it.
        if let toUpdate = try? LocalStore.shared.pendingUpdateFoodLogs() {
            for log in toUpdate {
                do {
                    try await supabase.from("food_logs")
                        .update(FoodLogUpdate(meal: log.meal, quantity: log.quantity))
                        .eq("id", value: log.id)
                        .execute()
                    try? LocalStore.shared.markFoodLogSynced(id: log.id)
                } catch { }
            }
        }
        if let toDelete = try? LocalStore.shared.deletedFoodLogs() {
            for log in toDelete {
                do {
                    try await supabase.from("food_logs").delete().eq("id", value: log.id).execute()
                    try? LocalStore.shared.removeFoodLog(id: log.id)
                } catch { }
            }
        }
    }

    // MARK: - Push water logs

    private func pushPendingWaterLogs() async {
        guard let pending = try? LocalStore.shared.pendingWaterLogs() else { return }
        for log in pending {
            do {
                try await supabase.from("water_logs")
                    .upsert(WaterLogInsert(from: log), onConflict: "id", ignoreDuplicates: true)
                    .execute()
                try? LocalStore.shared.markWaterLogSynced(id: log.id)
            } catch { }
        }
    }

    // MARK: - Pull goal

    private func pullGoal() async {
        do {
            if let goal = try await GoalRepository().fetchGoal(for: .now) {
                try? LocalStore.shared.upsertGoal(goal)
            }
        } catch { }
    }

    // MARK: - Pull food logs (last 7 days)

    private func pullRecentFoodLogs() async {
        do {
            let cal = Calendar.current
            let startDate = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: .now))!
            let logs: [FoodLog] = try await supabase
                .from("food_logs")
                .select("*, food_items(name, brand, serving_desc)")
                .gte("log_date", value: startDate.isoDateString)
                .execute()
                .value
            for log in logs {
                try? LocalStore.shared.upsertFoodLog(from: log)
            }
        } catch { }
    }

    // MARK: - Pull today's water

    private func pullTodayWater() async {
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            let rows: [WaterLog] = try await supabase
                .from("water_logs")
                .select()
                .eq("log_date", value: Date.now.isoDateString)
                .execute()
                .value
            for row in rows {
                try? LocalStore.shared.upsertWaterLog(
                    id: row.id, userId: userId,
                    logDate: row.logDate, amountMl: row.amountMl, loggedAt: row.loggedAt
                )
            }
        } catch { }
    }
}

// MARK: - Encodable helpers (snake_case for Supabase)

private struct FoodLogInsert: Encodable {
    let id: UUID
    let userId: UUID
    let loggedAt: Date
    let logDate: String
    let meal: String
    let foodItemId: UUID
    let quantity: Double
    let caloriesSnapshot: Double
    let proteinGSnapshot: Double
    let carbsGSnapshot: Double
    let fatGSnapshot: Double
    let fiberGSnapshot: Double

    init(from log: SDFoodLog) {
        id               = log.id
        userId           = log.userId
        loggedAt         = log.loggedAt
        logDate          = log.logDate
        meal             = log.meal
        foodItemId       = log.foodItemId
        quantity         = log.quantity
        caloriesSnapshot = log.caloriesSnapshot
        proteinGSnapshot = log.proteinGSnapshot
        carbsGSnapshot   = log.carbsGSnapshot
        fatGSnapshot     = log.fatGSnapshot
        fiberGSnapshot   = log.fiberGSnapshot
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId           = "user_id"
        case loggedAt         = "logged_at"
        case logDate          = "log_date"
        case meal
        case foodItemId       = "food_item_id"
        case quantity
        case caloriesSnapshot = "calories_snapshot"
        case proteinGSnapshot = "protein_g_snapshot"
        case carbsGSnapshot   = "carbs_g_snapshot"
        case fatGSnapshot     = "fat_g_snapshot"
        case fiberGSnapshot   = "fiber_g_snapshot"
    }
}

// Only the fields an edit can actually change — meal and quantity. Macro
// values are a per-serving snapshot from whatever source resolved them
// (FatSecret, Claude's estimate, manual entry) and aren't user-editable.
private struct FoodLogUpdate: Encodable {
    let meal: String
    let quantity: Double
}

private struct WaterLogInsert: Encodable {
    let id: UUID
    let userId: UUID
    let loggedAt: Date
    let logDate: String
    let amountMl: Double
    let source: String

    init(from log: SDWaterLog) {
        id       = log.id
        userId   = log.userId
        loggedAt = log.loggedAt
        logDate  = log.logDate
        amountMl = log.amountMl
        source   = "manual"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId   = "user_id"
        case loggedAt = "logged_at"
        case logDate  = "log_date"
        case amountMl = "amount_ml"
        case source
    }
}
