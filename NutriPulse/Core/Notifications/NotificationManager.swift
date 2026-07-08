import UserNotifications
import Foundation

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // Reminders fire at 9am local time.
    private static let reminderHour = 9

    // Every identifier this type ever schedules. Cancelling by an exhaustive list is what
    // keeps a stale "3 days overdue" notification from firing after the user finally logs.
    private static let allIdentifiers =
        ["glp1-eve", "glp1-day"] + (1...overdueFollowUpDays).map { "glp1-overdue-\($0)" }

    // Bounded, not repeating. A `repeats: true` calendar trigger would nag every morning
    // forever if the user stops GLP-1 without telling the app.
    private static let overdueFollowUpDays = 3

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

    // Cancels any previous GLP-1 reminders and schedules fresh ones for `nextDueAt`:
    // a day-before nudge, a day-of reminder, and three daily overdue follow-ups.
    func scheduleGLP1Reminders(nextDueAt: Date) async {
        guard await requestPermissionIfNeeded() else { return }

        cancelGLP1Reminders()

        let calendar = Calendar.current

        await schedule(
            identifier: "glp1-eve",
            title: "GLP-1 Injection Tomorrow",
            body: "Your weekly injection is due tomorrow. Get ready!",
            onDayOf: calendar.date(byAdding: .day, value: -1, to: nextDueAt),
            calendar: calendar
        )

        await schedule(
            identifier: "glp1-day",
            title: "GLP-1 Injection Due Today",
            body: "Today is your weekly injection day. Stay on track!",
            onDayOf: nextDueAt,
            calendar: calendar
        )

        // Miss the day-of reminder and nothing ever nudged you again — for a weekly
        // medication, that defeats the point of an adherence feature. These are cancelled
        // the moment an injection is logged (ProfileViewModel.logInjection reschedules).
        for dayOffset in 1...Self.overdueFollowUpDays {
            let plural = dayOffset == 1 ? "day" : "days"
            await schedule(
                identifier: "glp1-overdue-\(dayOffset)",
                title: "GLP-1 Injection Overdue",
                body: "Your injection is \(dayOffset) \(plural) overdue. Log it once you've taken it.",
                onDayOf: calendar.date(byAdding: .day, value: dayOffset, to: nextDueAt),
                calendar: calendar
            )
        }
    }

    func cancelGLP1Reminders() {
        center.removePendingNotificationRequests(withIdentifiers: Self.allIdentifiers)
    }

    // MARK: - Private

    // The old code guarded on the *injection's* timestamp rather than the moment the
    // notification would actually fire:
    //
    //     if let eve = cal.date(byAdding: .day, value: -1, to: nextDueAt), eve > now { ... }
    //     comps.hour = 9   // ...but the trigger fires at 09:00 that day
    //
    // An injection logged at 8pm has `eve` at 8pm too, which is comfortably in the future
    // even when 9am that morning is long gone. A fully-specified, non-repeating
    // UNCalendarNotificationTrigger whose components are in the past never fires — and
    // `center.add` returns success, so nothing surfaced the drop. Backdating an injection
    // (the sheet allows it) walked straight into this.
    //
    // Build the 9am fire date first, then guard on that.
    private func schedule(
        identifier: String,
        title: String,
        body: String,
        onDayOf day: Date?,
        calendar: Calendar
    ) async {
        guard
            let day,
            let fireDate = calendar.date(
                bySettingHour: Self.reminderHour, minute: 0, second: 0, of: day
            ),
            fireDate > .now
        else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        try? await center.add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
    }
}
