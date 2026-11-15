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
    /// False while GLP-1 tracking is paused or stopped: the widget drops its dose button.
    /// Optional so snapshots saved by older builds still decode.
    var showsDose: Bool? = nil
    var nutritionUnknown: Bool? = nil
    var needsRefresh: Bool? = nil

    var remaining: Int { max(Int((proteinGoal - proteinToday).rounded()), 0) }
    var pct: Double { proteinGoal > 0 ? min(proteinToday / proteinGoal, 1) : 0 }
    var cleared: Bool { proteinGoal > 0 && proteinToday >= proteinGoal }

    static let placeholder = ProteinFloorSnapshot(proteinToday: 120, proteinGoal: 185, updatedAt: Date(timeIntervalSince1970: 0))
}

enum SharedStore {
    private static let key = "proteinFloorSnapshot"
    private static let ownerKey = "proteinFloorSnapshot.owner"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: SharedConfig.appGroup) }

    /// A fresh process restoring the same account must not erase a valid snapshot.
    /// Legacy snapshots without an owner are cleared once; never carry data across accounts.
    static func bindAccount(_ owner: UUID?, defaults supplied: UserDefaults? = nil, reload: Bool = true) {
        guard let defaults = supplied ?? defaults else { return }
        let identity = owner?.uuidString ?? "signed-out"
        guard defaults.string(forKey: ownerKey) != identity else { return }
        defaults.set(identity, forKey: ownerKey)
        write(.init(proteinToday: 0, proteinGoal: 0, updatedAt: .now, showsDose: false,
                    nutritionUnknown: true, needsRefresh: true), defaults: defaults, reload: reload)
    }

    static func save(_ snapshot: ProteinFloorSnapshot, owner: UUID,
                     defaults supplied: UserDefaults? = nil, reload: Bool = true) {
        guard let defaults = supplied ?? defaults,
              defaults.string(forKey: ownerKey) == owner.uuidString else { return }
        write(snapshot, defaults: defaults, reload: reload)
    }

    static func invalidateProtein(owner: UUID, defaults supplied: UserDefaults? = nil, reload: Bool = true) {
        guard let defaults = supplied ?? defaults,
              defaults.string(forKey: ownerKey) == owner.uuidString else { return }
        let prior = load(defaults: defaults)
        write(.init(proteinToday: 0, proteinGoal: prior?.proteinGoal ?? 0, updatedAt: .now,
                    showsDose: prior?.showsDose ?? false, nutritionUnknown: true, needsRefresh: true),
              defaults: defaults, reload: reload)
    }

    private static func write(_ snapshot: ProteinFloorSnapshot, defaults: UserDefaults, reload: Bool) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        if reload { WidgetCenter.shared.reloadTimelines(ofKind: proteinFloorWidgetKind) }
    }

    static func load(defaults supplied: UserDefaults? = nil) -> ProteinFloorSnapshot? {
        guard let defaults = supplied ?? defaults, let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProteinFloorSnapshot.self, from: data)
    }
}
