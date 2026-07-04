import Foundation

// ─── DB model ─────────────────────────────────────────────────────────────────

struct BodyCompositionLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let logDate: String         // "YYYY-MM-DD"
    let weightKg: Double?
    let bodyFatPct: Double?     // stored as percent (e.g. 22.4, not 0.224)
    let bmi: Double?
    let leanBodyMassKg: Double?
    let source: String          // "manual" | "healthkit"
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, source, bmi
        case userId           = "user_id"
        case logDate          = "log_date"
        case weightKg         = "weight_kg"
        case bodyFatPct       = "body_fat_pct"
        case leanBodyMassKg   = "lean_body_mass_kg"
        case createdAt        = "created_at"
    }
}

// ─── Display model (merged HK + Supabase) ─────────────────────────────────────

struct BodyCompositionData {
    var weightKg: Double?       = nil
    var weightFromHK: Bool      = false
    var bodyFatPct: Double?     = nil   // 0–100
    var bodyFatFromHK: Bool     = false
    var bmi: Double?            = nil
    var bmiFromHK: Bool         = false
    var lbmKg: Double?          = nil
    var lbmFromHK: Bool         = false
    var latestDate: Date?       = nil

    var hasAnyData: Bool {
        weightKg != nil || bodyFatPct != nil || bmi != nil || lbmKg != nil
    }
}

// ─── RPC params ───────────────────────────────────────────────────────────────

struct UpsertBodyCompParams: Encodable {
    let pLogDate: String
    let pWeightKg: Double?
    let pBodyFatPct: Double?
    let pBmi: Double?
    let pLeanBodyMassKg: Double?
    let pSource: String

    enum CodingKeys: String, CodingKey {
        case pLogDate         = "p_log_date"
        case pWeightKg        = "p_weight_kg"
        case pBodyFatPct      = "p_body_fat_pct"
        case pBmi             = "p_bmi"
        case pLeanBodyMassKg  = "p_lean_body_mass_kg"
        case pSource          = "p_source"
    }
}
