import Foundation

struct GLP1Log: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let injectedAt: Date
    let medication: String      // e.g. "Semaglutide", "Tirzepatide"
    let doseMg: Double
    let site: String?           // injection site description
    let nextDueAt: Date?

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
