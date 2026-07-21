import Foundation

// One row per user; every field optional — a user can set just a lean-mass floor and
// nothing else. No dates by design: targets say where, never by-when.
struct BodyGoals: Codable {
    let userId: UUID
    let weightKgTarget: Double?
    let bodyFatPctTarget: Double?
    // A FLOOR, not a target: the happy state is staying at or above it. Mirrors how
    // protein and fiber work everywhere else in the app.
    let leanMassKgFloor: Double?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId           = "user_id"
        case weightKgTarget   = "weight_kg_target"
        case bodyFatPctTarget = "body_fat_pct_target"
        case leanMassKgFloor  = "lean_mass_kg_floor"
        case updatedAt        = "updated_at"
    }

    var isEmpty: Bool {
        weightKgTarget == nil && bodyFatPctTarget == nil && leanMassKgFloor == nil
    }
}

struct UpsertBodyGoals: Encodable {
    let userId: UUID
    let weightKgTarget: Double?
    let bodyFatPctTarget: Double?
    let leanMassKgFloor: Double?

    enum CodingKeys: String, CodingKey {
        case userId           = "user_id"
        case weightKgTarget   = "weight_kg_target"
        case bodyFatPctTarget = "body_fat_pct_target"
        case leanMassKgFloor  = "lean_mass_kg_floor"
    }
}
