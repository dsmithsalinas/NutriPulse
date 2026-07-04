import UserNotifications
import Foundation

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // Requests permission if not yet determined; returns whether notifications are allowed.
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default: return false
        }
    }

    // Cancels any previous GLP-1 reminders and schedules fresh ones for `nextDueAt`.
    // Schedules a day-before nudge at 9am and a day-of reminder at 9am.
    func scheduleGLP1Reminders(nextDueAt: Date) async {
        guard await requestPermissionIfNeeded() else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["glp1-eve", "glp1-day"])

        let cal = Calendar.current
        let now = Date.now

        // Day-before nudge
        if let eve = cal.date(byAdding: .day, value: -1, to: nextDueAt), eve > now {
            var comps = cal.dateComponents([.year, .month, .day], from: eve)
            comps.hour = 9; comps.minute = 0
            let content = UNMutableNotificationContent()
            content.title = "GLP-1 Injection Tomorrow"
            content.body  = "Your weekly injection is due tomorrow. Get ready!"
            content.sound = .default
            try? await center.add(UNNotificationRequest(
                identifier: "glp1-eve",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            ))
        }

        // Day-of reminder
        if nextDueAt > now {
            var comps = cal.dateComponents([.year, .month, .day], from: nextDueAt)
            comps.hour = 9; comps.minute = 0
            let content = UNMutableNotificationContent()
            content.title = "GLP-1 Injection Due Today"
            content.body  = "Today is your weekly injection day. Stay on track!"
            content.sound = .default
            try? await center.add(UNNotificationRequest(
                identifier: "glp1-day",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            ))
        }
    }

    func cancelGLP1Reminders() {
        center.removePendingNotificationRequests(withIdentifiers: ["glp1-eve", "glp1-day"])
    }
}
