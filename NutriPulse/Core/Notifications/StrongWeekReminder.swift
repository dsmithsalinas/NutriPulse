import Foundation
import UserNotifications

// A floating local calendar trigger: no fixed date, UTC offset, or timezone.
// iOS repeats it weekly without waking the app or generating an outlook in advance.
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
    static func request(userId: UUID) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Your strong week"
        content.body = "Check in with Pulse for food, movement, and recovery ideas that fit your week."
        content.sound = .default
        content.userInfo = ["destination": "strong_week", "userId": userId.uuidString]
        return .init(identifier: identifier, content: content,
                     trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
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
