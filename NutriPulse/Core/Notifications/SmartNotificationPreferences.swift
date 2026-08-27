import Foundation

struct SmartNotificationPreferences: Equatable {
    static let workoutKey = "smartNotificationWorkoutEnabled"
    static let proteinKey = "smartNotificationProteinEnabled"
    static let appetiteKey = "smartNotificationAppetiteEnabled"
    static let mealKey = "smartNotificationMealEnabled"
    static let quietStartKey = "smartNotificationQuietStartHour"
    static let quietEndKey = "smartNotificationQuietEndHour"

    var workoutRecovery: Bool
    var proteinCloseout: Bool
    var lowAppetite: Bool
    var repeatedMeal: Bool
    var quietStartHour: Int
    var quietEndHour: Int

    static func load(defaults: UserDefaults = .standard) -> Self {
        func enabled(_ key: String) -> Bool {
            defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
        }
        return .init(
            workoutRecovery: enabled(workoutKey),
            proteinCloseout: enabled(proteinKey),
            lowAppetite: enabled(appetiteKey),
            repeatedMeal: enabled(mealKey),
            quietStartHour: defaults.object(forKey: quietStartKey) == nil ? 21 : defaults.integer(forKey: quietStartKey),
            quietEndHour: defaults.object(forKey: quietEndKey) == nil ? 7 : defaults.integer(forKey: quietEndKey)
        )
    }

    static func setEnabled(
        _ enabled: Bool,
        for kind: SmartNotificationKind,
        defaults: UserDefaults = .standard
    ) {
        let key = switch kind {
        case .workoutRecovery: workoutKey
        case .proteinCloseout: proteinKey
        case .lowAppetite: appetiteKey
        case .repeatedMeal: mealKey
        }
        defaults.set(enabled, forKey: key)
        NotificationCenter.default.post(name: .smartCoachingSettingsChanged, object: nil)
    }

    var enabledKinds: Set<SmartNotificationKind> {
        var kinds: Set<SmartNotificationKind> = []
        if workoutRecovery { kinds.insert(.workoutRecovery) }
        if proteinCloseout { kinds.insert(.proteinCloseout) }
        if lowAppetite { kinds.insert(.lowAppetite) }
        if repeatedMeal { kinds.insert(.repeatedMeal) }
        return kinds
    }

    func isQuiet(at date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        if quietStartHour == quietEndHour { return false }
        if quietStartHour > quietEndHour {
            return hour >= quietStartHour || hour < quietEndHour
        }
        return hour >= quietStartHour && hour < quietEndHour
    }
}
