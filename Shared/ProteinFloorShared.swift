import Foundation
import WidgetKit

// Shared between the app and the widget extension (both compile this file). The app writes the
// snapshot into the App Group container on every Today refresh; the widget reads it.
enum SharedConfig {
    static let appGroup = "group.com.dustin.nutripulse"
}

let proteinFloorWidgetKind = "ProteinFloorWidget"

// Today's protein "floor" — a minimum to clear that protects muscle, not a ceiling.
struct ProteinFloorSnapshot: Codable {
    var proteinToday: Double
    var proteinGoal: Double
    var updatedAt: Date

    var remaining: Int { max(Int((proteinGoal - proteinToday).rounded()), 0) }
    var pct: Double { proteinGoal > 0 ? min(proteinToday / proteinGoal, 1) : 0 }
    var cleared: Bool { proteinGoal > 0 && proteinToday >= proteinGoal }

    static let placeholder = ProteinFloorSnapshot(proteinToday: 120, proteinGoal: 185, updatedAt: Date(timeIntervalSince1970: 0))
}

enum SharedStore {
    private static let key = "proteinFloorSnapshot"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: SharedConfig.appGroup) }

    static func save(_ snapshot: ProteinFloorSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: proteinFloorWidgetKind)
    }

    static func load() -> ProteinFloorSnapshot? {
        guard let defaults, let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProteinFloorSnapshot.self, from: data)
    }
}
