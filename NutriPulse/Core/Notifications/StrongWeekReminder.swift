import Foundation
import UserNotifications

// Bounded to one Monday so every proactive notification consumes the shared attention
// allowance. Reconcile at launch/foreground; never queue an unbudgeted repeating trigger.
enum StrongWeekReminder {
    static let identifier = "pulse-strong-week"
    static let routeKey = "strongWeekReminderRoute"
    static func preferenceKey(userId: UUID) -> String { "strongWeekReminderEnabled-\(userId.uuidString)" }
    static func enabled(userId: UUID, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: preferenceKey(userId: userId)) as? Bool ?? true
    }
    static var components: DateComponents {
        var date = DateComponents()
        date.weekday = 2 // Sunday = 1, Monday = 2.
        date.hour = 8
        date.minute = 0
        return date
    }
    static func nextFireDate(after now: Date = .now, calendar: Calendar = .current) -> Date? {
        calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
    }
    static func request(userId: UUID, fireDate: Date? = nil) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Your strong week"
        content.body = "Check in with Pulse for food, movement, and recovery ideas that fit your week."
        content.sound = .default
        content.userInfo = ["destination": "strong_week", "userId": userId.uuidString]
        return .init(identifier: identifier, content: content,
                     trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate ?? nextFireDate()!), repeats: false))
    }
    static func saveRoute(userId: UUID, defaults: UserDefaults = .standard) {
        defaults.set(userId.uuidString, forKey: routeKey)
    }
    static func consumeRoute(userId: UUID, defaults: UserDefaults = .standard) -> Bool {
        guard let stored = defaults.string(forKey: routeKey) else { return false }
        defaults.removeObject(forKey: routeKey)
        return stored == userId.uuidString
    }
}

extension Notification.Name {
    static let strongWeekReminderOpened = Notification.Name("strongWeekReminderOpened")
}
