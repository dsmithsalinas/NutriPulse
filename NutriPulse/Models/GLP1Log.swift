import Foundation

struct GLP1Log: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let injectedAt: Date
    let medication: String
    let doseMg: Double
    let site: String
    let nextDueAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case injectedAt = "injected_at"
        case medication
        case doseMg     = "dose_mg"
        case site
        case nextDueAt  = "next_due_at"
    }
}

struct NewGLP1Log: Encodable {
    let userId: UUID
    let injectedAt: Date
    let medication: String
    let doseMg: Double
    let site: String
    let nextDueAt: Date

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case injectedAt = "injected_at"
        case medication
        case doseMg     = "dose_mg"
        case site
        case nextDueAt  = "next_due_at"
    }
}

// ─── Medication definitions ───────────────────────────────────────────────────

enum GLP1Medication: String, CaseIterable, Identifiable {
    case ozempic  = "Ozempic"
    case wegovy   = "Wegovy"
    case mounjaro = "Mounjaro"
    case zepbound = "Zepbound"

    var id: String { rawValue }

    var activeIngredient: String {
        switch self {
        case .ozempic, .wegovy:    return "semaglutide"
        case .mounjaro, .zepbound: return "tirzepatide"
        }
    }

    var availableDoses: [Double] {
        switch self {
        case .ozempic:             return [0.25, 0.5, 1.0, 2.0]
        case .wegovy:              return [0.25, 0.5, 1.0, 1.7, 2.4]
        case .mounjaro, .zepbound: return [2.5, 5.0, 7.5, 10.0, 12.5, 15.0]
        }
    }
}

// ─── Dose formatting ─────────────────────────────────────────────────────────

extension Double {
    // Renders a dose exactly: 12.5 → "12.5", 10.0 → "10", 0.25 → "0.25".
    // Never use "%g"-family format specifiers here — they round to significant
    // digits, so "%.2g" silently turns Mounjaro's 12.5 mg step into "12".
    var glp1DoseString: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}

// ─── Injection sites (rotation order) ────────────────────────────────────────

enum InjectionSite: String, CaseIterable, Identifiable {
    case leftAbdomen  = "Left Abdomen"
    case rightAbdomen = "Right Abdomen"
    case leftThigh    = "Left Thigh"
    case rightThigh   = "Right Thigh"
    case leftArm      = "Left Arm"
    case rightArm     = "Right Arm"

    var id: String { rawValue }
}
