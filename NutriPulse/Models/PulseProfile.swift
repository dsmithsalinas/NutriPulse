import Foundation

// What Pulse knows about the user, and the Pulse settings (pulse_profiles; docs/daylight-redesign.md,
// step 8). Allergies are safety-relevant: only the user saves them, never Pulse on its own.

enum EatingPattern: String, Codable, CaseIterable, Identifiable {
    case vegetarian, vegan, pescatarian, halal, kosher
    case dairyFree = "dairy_free", glutenFree = "gluten_free"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .pescatarian: "Pescatarian"
        case .halal: "Halal"
        case .kosher: "Kosher"
        case .dairyFree: "Dairy-free"
        case .glutenFree: "Gluten-free"
        }
    }
}

/// Common allergens offered as one-tap chips; anything else is added as free text.
enum CommonAllergen {
    static let all = ["Peanuts", "Tree nuts", "Dairy", "Eggs", "Wheat / gluten", "Soy", "Fish", "Shellfish", "Sesame"]
}

/// The editable part: what the user has told Pulse.
struct PulsePreferences: Equatable, Codable {
    var allergies: [String] = []
    var allergyNote: String = ""
    var eatingPatterns: Set<EatingPattern> = []
    var loves: [String] = []
    var avoids: [String] = []

    /// Everything in either, for merging a queued save into what the server holds.
    func merged(with other: PulsePreferences) -> PulsePreferences {
        PulsePreferences(
            allergies: allergies + other.allergies,
            allergyNote: allergyNote.isEmpty ? other.allergyNote : allergyNote,
            eatingPatterns: eatingPatterns.union(other.eatingPatterns),
            loves: loves + other.loves,
            avoids: avoids + other.avoids
        ).normalized
    }

    var isEmpty: Bool {
        allergies.isEmpty && allergyNote.isEmpty && eatingPatterns.isEmpty && loves.isEmpty && avoids.isEmpty
    }

    /// Trimmed, de-duplicated (case-insensitive, first spelling kept), and within the database's
    /// limits: 60 characters an item, 20 allergies, 30 loves/avoids, a 300-character note.
    var normalized: PulsePreferences {
        func clean(_ items: [String], max: Int) -> [String] {
            var seen = Set<String>()
            return items.compactMap { raw in
                let item = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
                guard !item.isEmpty, seen.insert(item.lowercased()).inserted else { return nil }
                return item
            }.prefix(max).map { $0 }
        }
        return .init(
            allergies: clean(allergies, max: 20),
            allergyNote: String(allergyNote.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)),
            eatingPatterns: eatingPatterns,
            loves: clean(loves, max: 30),
            avoids: clean(avoids, max: 30)
        )
    }
}

/// A row of pulse_profiles.
struct PulseProfile: Codable, Equatable {
    let userId: UUID
    var allergies: [String]
    var allergyNote: String
    var eatingPatterns: [String]
    var loves: [String]
    var avoids: [String]
    var pulseEnabled: Bool
    var pulseOnToday: Bool
    var aiConsentAt: Date?

    enum CodingKeys: String, CodingKey {
        case allergies, loves, avoids
        case userId = "user_id", allergyNote = "allergy_note", eatingPatterns = "eating_patterns"
        case pulseEnabled = "pulse_enabled", pulseOnToday = "pulse_on_today", aiConsentAt = "ai_consent_at"
    }

    var preferences: PulsePreferences {
        .init(allergies: allergies, allergyNote: allergyNote,
              eatingPatterns: Set(eatingPatterns.compactMap(EatingPattern.init(rawValue:))),
              loves: loves, avoids: avoids)
    }
}

/// What reaches Pulse as `aboutYou` in its context (see sanitizeContext on the server).
struct AboutYouContext: Encodable, Equatable {
    let allergies: [String]
    let allergyNote: String
    let eatingPatterns: [String]
    let loves: [String]
    let avoids: [String]

    init(_ preferences: PulsePreferences) {
        allergies = preferences.allergies
        allergyNote = preferences.allergyNote
        eatingPatterns = preferences.eatingPatterns.map(\.rawValue).sorted()
        loves = preferences.loves
        avoids = preferences.avoids
    }
}

/// Something Pulse heard in chat and offers to save ("Save to what Pulse knows? Avoid: salmon").
struct PulseRememberSuggestion: Codable, Equatable, Hashable {
    enum Kind: String, Codable { case allergy, avoid, love }
    let kind: Kind
    let value: String

    var label: String {
        switch kind {
        case .allergy: "Allergy: \(value)"
        case .avoid: "Avoid: \(value)"
        case .love: "Loves: \(value)"
        }
    }
}

extension Notification.Name {
    static let pulseProfileChanged = Notification.Name("pulseProfileChanged")
}
