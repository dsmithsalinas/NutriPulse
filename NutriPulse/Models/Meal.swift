import Foundation

// SWIFT CONCEPT — enum with a RawValue of String means each case encodes to/from its
// string name automatically (Codable for free). CaseIterable adds an `allCases` array
// so we can loop over meals in a fixed display order without maintaining a manual list.
enum Meal: String, Codable, CaseIterable, Hashable {
    case breakfast
    case lunch
    case dinner
    case snack

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch:     "sun.max.fill"
        case .dinner:    "moon.stars.fill"
        case .snack:     "carrot.fill"
        }
    }

    // Display order for the Today view meal sections
    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch:     1
        case .dinner:    2
        case .snack:     3
        }
    }

    // Sensible default based on time of day — pre-selects the right meal in the logger
    static var current: Meal {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<11:  return .breakfast
        case 11..<15: return .lunch
        case 17..<21: return .dinner
        default:      return .snack
        }
    }
}
