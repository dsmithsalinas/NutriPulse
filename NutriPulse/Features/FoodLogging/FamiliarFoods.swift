import Foundation

/// Deduplicates foods without losing the latest portion, date or nutrition snapshot.
enum FamiliarFoods {
    static func suggestions(_ logs: [FoodLog], limit: Int = 3, now: Date = .now) -> [FoodLog] {
        let eligible = logs.filter { $0.loggedAt <= now }
        let grouped = Dictionary(grouping: eligible, by: \.foodItemId)
        return grouped.values.compactMap { $0.max(by: { $0.loggedAt < $1.loggedAt }) }
            .sorted {
                let left = grouped[$0.foodItemId]?.count ?? 0
                let right = grouped[$1.foodItemId]?.count ?? 0
                if left != right { return left > right }
                if $0.loggedAt != $1.loggedAt { return $0.loggedAt > $1.loggedAt }
                return $0.id.uuidString < $1.id.uuidString
            }.prefix(limit).map { $0 }
    }
}
