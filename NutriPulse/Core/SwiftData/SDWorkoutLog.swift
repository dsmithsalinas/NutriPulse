import SwiftData
import Foundation

@Model
final class SDWorkoutLog {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var logDate: String

    // Two vocabularies share this column, told apart by `source`. Manual logs use
    // ManualActivityType raw values ("walk", "strength", …). HealthKit imports keep
    // the HKWorkoutActivityType slug ("traditionalStrengthTraining", "hiking", …)
    // so nothing is flattened away at import time.
    var activityType: String
    var durationMinutes: Double
    var activeCalories: Double?
    var distanceMeters: Double?
    var source: String  // "manual" | "healthkit"

    // HKWorkout.uuid for imported rows; nil for manual. Import dedup is enforced by
    // LocalStore's fetch-before-insert guard, NOT by @Attribute(.unique) — every
    // manual row shares nil here, and a uniqueness constraint would let SwiftData
    // treat them as the same row and upsert-overwrite on insert.
    var healthKitUUID: String?

    var startedAt: Date
    var loggedAt: Date
    var syncState: String  // "pendingCreate" | "pendingDelete" | "synced"

    // Bumped on every local mutation; SyncEngine snapshots it before a push and
    // refuses to mark the row "synced" if it changed mid-flight. Same contract
    // as SDFoodLog.revision.
    var revision: Int

    init(
        id: UUID = UUID(),
        userId: UUID,
        logDate: String,
        activityType: String,
        durationMinutes: Double,
        activeCalories: Double? = nil,
        distanceMeters: Double? = nil,
        source: String,
        healthKitUUID: String? = nil,
        startedAt: Date,
        loggedAt: Date = .now,
        syncState: String = "pendingCreate",
        revision: Int = 0
    ) {
        self.id              = id
        self.userId          = userId
        self.logDate         = logDate
        self.activityType    = activityType
        self.durationMinutes = durationMinutes
        self.activeCalories  = activeCalories
        self.distanceMeters  = distanceMeters
        self.source          = source
        self.healthKitUUID   = healthKitUUID
        self.startedAt       = startedAt
        self.loggedAt        = loggedAt
        self.syncState       = syncState
        self.revision        = revision
    }

    var asWorkoutLog: WorkoutLog {
        WorkoutLog(
            id: id,
            userId: userId,
            loggedAt: loggedAt,
            logDate: logDate,
            activityType: activityType,
            durationMinutes: durationMinutes,
            activeCalories: activeCalories,
            distanceMeters: distanceMeters,
            source: WorkoutSource(rawValue: source) ?? .manual,
            healthKitUUID: healthKitUUID,
            startedAt: startedAt
        )
    }
}
