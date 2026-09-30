import Foundation

// Pure logic behind the Favorites tab's "Recents from the last 72 hours" (docs/daylight-redesign.md).
// Kept free of LocalStore/Supabase so it's trivially unit-testable — see FootingTests.swift.
enum RecentFoodsGrouper {
    struct Section: Identifiable, Equatable {
        /// The day label doubles as the section id — unique within a single 72-hour window.
        var id: String { label }
        let label: String
        let logs: [FoodLog]
    }

    static let window: TimeInterval = 72 * 3600

    /// Logs from the last 72 hours, newest first, excluding any food already in favorites
    /// (the spec: "Recents hide foods already in favorites").
    static func recentLogs(
        from logs: [FoodLog],
        now: Date = .now,
        favoritedFoodItemIds: Set<UUID>
    ) -> [FoodLog] {
        let cutoff = now.addingTimeInterval(-window)
        return logs
            .filter { $0.loggedAt >= cutoff && $0.loggedAt <= now && !favoritedFoodItemIds.contains($0.foodItemId) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    /// Groups already-filtered, newest-first logs by calendar day: "Today", "Yesterday", then
    /// the full weekday name — in first-seen order, so the newest day leads.
    static func grouped(_ logs: [FoodLog], now: Date = .now, calendar: Calendar = .current) -> [Section] {
        var order: [String] = []
        var byLabel: [String: [FoodLog]] = [:]
        for log in logs {
            let label = dayLabel(for: log.loggedAt, now: now, calendar: calendar)
            if byLabel[label] == nil { order.append(label) }
            byLabel[label, default: []].append(log)
        }
        return order.map { Section(label: $0, logs: byLabel[$0] ?? []) }
    }

    static func dayLabel(for date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        var english = calendar
        english.locale = Locale(identifier: "en_US")
        return date.formatted(.dateTime.weekday(.wide))
    }
}
