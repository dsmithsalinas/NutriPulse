import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let email: String
    let fullName: String?
    let dob: String?            // "YYYY-MM-DD"
    let sex: String?            // "male" | "female" | "other"
    let heightCm: Double?
    let activityLevel: String?  // "sedentary" | "light" | "moderate" | "active" | "very_active"
    let dietaryPrefs: [String]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName      = "full_name"
        case dob
        case sex
        case heightCm      = "height_cm"
        case activityLevel = "activity_level"
        case dietaryPrefs  = "dietary_prefs"
        case createdAt     = "created_at"
    }
}
