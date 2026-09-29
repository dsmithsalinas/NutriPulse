import UserNotifications
import Foundation

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    static let smartCoachingEnabledKey = "smartCoachingNotificationsEnabled"
    static let smartSuppressedDayKey = "smartCoachingSuppressedDay"
    static let smartIdentifierPrefix = "smart-"
    static let closeProteinAction = "smart-close-protein"
    static let addWaterAction = "smart-add-water"
    static let repeatMealAction = "smart-repeat-meal"
    static let reviewMealAction = "smart-review-meal"
    static let notTodayAction = "smart-not-today"
    static let recoveryCategory = "smart-recovery"
    static let proteinCategory = "smart-protein"
    static let mealCategory = "smart-meal"
    static let appetiteCategory = "smart-appetite"

    // Monday recap. Deliberately NOT under the "smart-" prefix: it is not part of the
    // one-coaching-notification-a-day budget, and cancelSmartNotifications must not remove it.
    static let weeklyRecapEnabledKey = "weeklyRecapNotificationEnabled"
    static let weeklyRecapIdentifier = "weekly-recap"
    static let weeklyRecapKind = "weekly-recap"

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

        // Copy rules (see docs/pulse-persona.md): Pulse's voice, sentence case, no hype,
        // never "overdue" aimed at a person's medication. Deliberately discreet — these
        // sit on the LOCK SCREEN, so they never name the medication or say "injection";
        // "shot day" is clear to the user and opaque to a bystander's glance.
        await schedule(
            identifier: "glp1-eve",
            title: "Tomorrow's the day",
            body: "Your weekly dose is on the plan for tomorrow.",
            onDayOf: calendar.date(byAdding: .day, value: -1, to: nextDueAt),
            calendar: calendar
        )

        await schedule(
            identifier: "glp1-day",
            title: "Shot day",
            body: "Today's the day. Log it when it's done — I'll take it from there.",
            onDayOf: nextDueAt,
            calendar: calendar
        )

        // Miss the day-of reminder and nothing ever nudged you again — for a weekly
        // medication, that defeats the point of an adherence feature. These are cancelled
        // the moment a dose is logged (ProfileViewModel.logInjection reschedules).
        let plannedDay = nextDueAt.formatted(.dateTime.weekday(.wide))
        for dayOffset in 1...Self.overdueFollowUpDays {
            await schedule(
                identifier: "glp1-overdue-\(dayOffset)",
                title: "Whenever you're ready",
                body: "Your dose was planned for \(plannedDay). Log it once you've taken it and I'll adjust your week.",
                onDayOf: calendar.date(byAdding: .day, value: dayOffset, to: nextDueAt),
                calendar: calendar
            )
        }
    }

    func cancelGLP1Reminders() {
        center.removePendingNotificationRequests(withIdentifiers: Self.allIdentifiers)
    }

    // MARK: - Monday recap

    // On unless the user turned it off. Tied to notification permission the user already
    // granted — this never prompts on its own.
    static var weeklyRecapEnabled: Bool {
        UserDefaults.standard.object(forKey: weeklyRecapEnabledKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: weeklyRecapEnabledKey)
    }

    // Idempotent: called on every foreground, so the reminder exists whenever permission
    // does (granted later from shot-day reminders or Settings) and disappears when turned off.
    //
    // A repeating trigger is right here, unlike the GLP-1 reminders above: the recap is
    // weekly by design, has its own off switch, and the notification doesn't claim anything
    // about the user's data that could go stale. The recap itself is written when the user
    // opens Pulse (CoachViewModel.refreshAutoMessages), from that moment's data.
    func syncWeeklyRecapReminder() async {
        // Signed out: nothing to recap, and the next account shouldn't inherit a reminder.
        guard Self.weeklyRecapEnabled, (try? await supabase.auth.session) != nil else {
            cancelWeeklyRecapReminder()
            return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        // Pulse's voice, sentence case, nothing health-specific on the lock screen.
        let content = UNMutableNotificationContent()
        content.title = "Your week, in one read"
        content.body = "I looked back at last week — what worked, what got hard, and one focus for this one."
        content.sound = .default
        content.userInfo = ["kind": Self.weeklyRecapKind]

        var components = DateComponents()
        components.weekday = WeeklyRecapSchedule.notificationWeekday
        components.hour = WeeklyRecapSchedule.notificationHour
        components.minute = 0
        // Same identifier replaces any existing request, so repeated syncs don't stack.
        try? await center.add(UNNotificationRequest(
            identifier: Self.weeklyRecapIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        ))
    }

    // Toggle target. Turning it on may prompt for permission (the user asked for it);
    // returns false if permission was denied so the view can offer Settings.
    @discardableResult
    func setWeeklyRecapEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            guard await requestPermissionIfNeeded() else { return false }
        }
        UserDefaults.standard.set(enabled, forKey: Self.weeklyRecapEnabledKey)
        await syncWeeklyRecapReminder()
        return true
    }

    func cancelWeeklyRecapReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyRecapIdentifier])
    }

    // MARK: - Smart coaching notifications

    func registerSmartCategories() {
        let closeProtein = UNNotificationAction(
            identifier: Self.closeProteinAction,
            title: "Close the gap",
            options: [.foreground]
        )
        let addWater = UNNotificationAction(
            identifier: Self.addWaterAction,
            title: "Add 250 ml",
            options: [.foreground]
        )
        let repeatMeal = UNNotificationAction(
            identifier: Self.repeatMealAction,
            title: "Log again",
            options: [.foreground]
        )
        let reviewMeal = UNNotificationAction(
            identifier: Self.reviewMealAction,
            title: "Review first",
            options: [.foreground]
        )
        let notToday = UNNotificationAction(
            identifier: Self.notTodayAction,
            title: "Not today",
            options: []
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.recoveryCategory,
                actions: [closeProtein, addWater, notToday],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Self.proteinCategory,
                actions: [closeProtein, notToday],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Self.mealCategory,
                actions: [repeatMeal, reviewMeal, notToday],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Self.appetiteCategory,
                actions: [notToday],
                intentIdentifiers: []
            ),
        ])
    }

    @discardableResult
    func setSmartCoachingEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            guard await requestPermissionIfNeeded() else { return false }
            UserDefaults.standard.set(true, forKey: Self.smartCoachingEnabledKey)
            NotificationCenter.default.post(name: .smartCoachingSettingsChanged, object: nil)
            return true
        }
        UserDefaults.standard.set(false, forKey: Self.smartCoachingEnabledKey)
        cancelSmartNotifications()
        NotificationCenter.default.post(name: .smartCoachingSettingsChanged, object: nil)
        return true
    }

    func scheduleSmartOpportunity(_ opportunity: SmartNotificationOpportunity?) async {
        guard UserDefaults.standard.bool(forKey: Self.smartCoachingEnabledKey) else {
            cancelSmartNotifications()
            return
        }
        guard UserDefaults.standard.string(forKey: Self.smartSuppressedDayKey) != Date.now.isoDateString else {
            cancelSmartNotifications()
            return
        }
        guard let opportunity else {
            cancelSmartNotifications()
            return
        }

        let preferences = SmartNotificationPreferences.load()
        guard preferences.enabledKinds.contains(opportunity.kind),
              !preferences.isQuiet(at: opportunity.fireDate) else {
            cancelSmartNotifications()
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let dayPrefix = "\(Self.smartIdentifierPrefix)\(Date.now.isoDateString)-"
        let delivered = await center.deliveredNotifications()
        // Strict coaching budget: once one smart notification reached Notification Center
        // today, every later candidate stays in the app. Shot reminders are separate.
        guard !delivered.contains(where: { $0.request.identifier.hasPrefix(dayPrefix) }) else {
            cancelSmartNotifications()
            return
        }

        let pending = await center.pendingNotificationRequests()
        let existing = pending.first { $0.identifier.hasPrefix(Self.smartIdentifierPrefix) }
        let existingPriority = existing?.content.userInfo["priority"] as? Int ?? -1
        if existingPriority >= opportunity.priority { return }
        let replacedIDs = pending.filter { $0.identifier.hasPrefix(Self.smartIdentifierPrefix) }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: replacedIDs)

        let content = UNMutableNotificationContent()
        content.title = opportunity.title
        content.body = opportunity.body
        content.sound = .default
        content.userInfo = [
            "kind": opportunity.kind.rawValue,
            "priority": opportunity.priority,
            "sourceDate": opportunity.sourceDate ?? "",
            "meal": opportunity.meal?.rawValue ?? "",
        ]
        switch opportunity.kind {
        case .workoutRecovery: content.categoryIdentifier = Self.recoveryCategory
        case .proteinCloseout: content.categoryIdentifier = Self.proteinCategory
        case .lowAppetite: content.categoryIdentifier = Self.appetiteCategory
        case .repeatedMeal: content.categoryIdentifier = Self.mealCategory
        }

        let interval = max(opportunity.fireDate.timeIntervalSinceNow, 1)
        let identifier = "\(dayPrefix)\(opportunity.kind.rawValue)"
        do {
            try await center.add(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            ))
            SmartNotificationHistoryStore.remove(ids: replacedIDs)
            SmartNotificationHistoryStore.upsert(.init(
                id: identifier,
                kind: opportunity.kind,
                title: opportunity.title,
                body: opportunity.body,
                rationale: opportunity.rationale,
                scheduledAt: .now,
                fireDate: opportunity.fireDate,
                feedback: nil,
                status: .scheduled
            ))
        } catch { }
    }

    func cancelSmartNotifications() {
        Task { @MainActor in
            let requests = await center.pendingNotificationRequests()
            let ids = requests.filter { $0.identifier.hasPrefix(Self.smartIdentifierPrefix) }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
            SmartNotificationHistoryStore.remove(ids: ids)
        }
    }

    // iOS does not wake the app merely to say a background notification was delivered.
    // Reconcile against Notification Center whenever history is opened/Footing resumes,
    // and never infer delivery just because a fire date passed.
    func reconcileSmartNotificationHistory() async {
        let pendingIDs = Set(await center.pendingNotificationRequests().map(\.identifier))
        let deliveredIDs = Set(await center.deliveredNotifications().map { $0.request.identifier })
        for entry in SmartNotificationHistoryStore.load() {
            if deliveredIDs.contains(entry.id), entry.status == .scheduled {
                SmartNotificationHistoryStore.setStatus(.delivered, for: entry.id)
            } else if pendingIDs.contains(entry.id), entry.status != .scheduled {
                SmartNotificationHistoryStore.setStatus(.scheduled, for: entry.id)
            }
        }
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

// A tap on the Monday recap opens Pulse. Stored rather than handled directly because the tap
// can arrive before the tab view exists (cold launch); MainTabView consumes it on appear, on
// foreground, and on the notification posted here for the already-running case.
enum PulseRouteStore {
    private static let key = "pendingOpenPulse"

    static func requestOpen() {
        UserDefaults.standard.set(true, forKey: key)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openPulseRequested, object: nil)
        }
    }

    static func consume() -> Bool {
        guard UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.removeObject(forKey: key)
        return true
    }
}

extension Notification.Name {
    static let openPulseRequested = Notification.Name("openPulseRequested")
}
