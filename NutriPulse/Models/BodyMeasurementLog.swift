import Foundation

// The tape-measurement sites the check-in offers. Deliberately one value per site — no
// left/right, no upper/lower waist: those distinctions are scan-app granularity, and with
// a tape measure the placement noise is bigger than the difference they'd capture.
// Raw values are an API contract (stored in body_measurement_logs.site) — never rename.
enum MeasurementSite: String, CaseIterable, Codable, Identifiable {
    case waist
    case hips
    case chest
    case upperArm
    case thigh

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .waist:    return "Waist"
        case .hips:     return "Hips"
        case .chest:    return "Chest"
        case .upperArm: return "Upper arm"
        case .thigh:    return "Thigh"
        }
    }

    // Only the waist exists as a HealthKit quantity type (.waistCircumference);
    // the other sites are manual-only by nature, not by choice.
    var isHealthKitBacked: Bool { self == .waist }
}

// Long format — one row per site per entry — so adding sites later (calf, neck for the
// Navy body-fat estimate, even left/right variants) is a picker entry, not a migration.
struct BodyMeasurementLog: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let logDate: String         // "YYYY-MM-DD" — same no-timezone convention as everywhere
    let site: String            // MeasurementSite raw value; String so an unknown future site decodes
    let valueCm: Double         // always stored metric; UnitSystem converts for display
    let source: String          // "manual" | "healthkit"
    let healthKitUUID: String?
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case logDate       = "log_date"
        case site
        case valueCm       = "value_cm"
        case source
        case healthKitUUID = "healthkit_uuid"
        case loggedAt      = "logged_at"
    }

    var siteType: MeasurementSite? { MeasurementSite(rawValue: site) }
}

// Insert-only — id and created_at are database-generated.
struct NewBodyMeasurementLog: Encodable {
    let userId: UUID
    let logDate: String
    let site: String
    let valueCm: Double
    let source: String
    let healthKitUUID: String?
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId        = "user_id"
        case logDate       = "log_date"
        case site
        case valueCm       = "value_cm"
        case source
        case healthKitUUID = "healthkit_uuid"
        case loggedAt      = "logged_at"
    }
}
