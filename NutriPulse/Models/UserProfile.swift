import Foundation

// Partial update struct — only the fields collected during onboarding.
struct UpdateProfile: Encodable {
    let fullName: String
    let dob: String
    let sex: String
    let heightCm: Double
    let activityLevel: String

    enum CodingKeys: String, CodingKey {
        case fullName      = "full_name"
        case dob
        case sex
        case heightCm      = "height_cm"
        case activityLevel = "activity_level"
    }
}

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let email: String
    let fullName: String?
    let dob: String?            // "YYYY-MM-DD"
    let sex: String?            // "male" | "female" | "other"
    let heightCm: Double?
    let activityLevel: String?  // "sedentary" | "light" | "moderate" | "active" | "very_active"
    // "lose" | "maintain" | "gain" — nil for accounts that predate the column and haven't
    // been through onboarding or Recalculate Targets since.
    let weightGoal: String?
    let dietaryPrefs: [String]?
    let createdAt: Date
    // "active" | "paused" | "stopped" (GLP1TrackingStore). nil before the column existed.
    var glp1Tracking: String? = nil
    var glp1TrackingChangedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName      = "full_name"
        case dob
        case sex
        case heightCm      = "height_cm"
        case activityLevel = "activity_level"
        case weightGoal    = "weight_goal"
        case dietaryPrefs  = "dietary_prefs"
        case createdAt     = "created_at"
        case glp1Tracking  = "glp1_tracking"
        case glp1TrackingChangedAt = "glp1_tracking_changed_at"
    }
}
