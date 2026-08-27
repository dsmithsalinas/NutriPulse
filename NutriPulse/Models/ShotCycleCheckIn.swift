import Foundation

// A deliberately small, non-medical snapshot of how a GLP-1 day feels. Values use a
// five-point scale so check-in takes seconds and trends remain comparable over time.
struct ShotCycleCheckIn: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let checkinDate: String
    let cycleDay: Int
    let appetite: Int
    let fullness: Int
    let nausea: Int
    let energy: Int
    let digestion: Int
    let note: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case checkinDate = "checkin_date"
        case cycleDay = "cycle_day"
        case appetite, fullness, nausea, energy, digestion, note
        case createdAt = "created_at"
    }
}

struct NewShotCycleCheckIn: Encodable {
    let userId: UUID
    let checkinDate: String
    let cycleDay: Int
    let appetite: Int
    let fullness: Int
    let nausea: Int
    let energy: Int
    let digestion: Int
    let note: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case checkinDate = "checkin_date"
        case cycleDay = "cycle_day"
        case appetite, fullness, nausea, energy, digestion, note
    }
}

struct ShotCycleCheckInDraft: Equatable {
    var appetite = 3
    var fullness = 3
    var nausea = 1
    var energy = 3
    var digestion = 3
    var note = ""
}
