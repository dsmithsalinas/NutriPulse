import UserNotifications
import Foundation

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        // Cancel immediately on Pulse-off rather than waiting for the next natural evaluation
        // (a workout finishing, a repeated meal window, etc.) — that could be hours away, and a
        // notification presenting as Pulse shouldn't outlive the toggle. Nothing to do on
        // Pulse-on here: `scheduleSmartOpportunity`'s guard just stops blocking the next
        // evaluation: TodayView re-runs one as soon as it sees this same notification.
        NotificationCenter.default.addObserver(
            forName: .pulseProfileChanged, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                guard !PulseProfileStore.shared.pulseEnabled else { return }
                NotificationManager.shared.cancelSmartNotifications()
            }
        }
    }

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

    private var weeklyUserId: UUID?
    private var weeklyReconcile: Task<Bool, Never>?

    func setWeeklyReminderAccount(_ userId: UUID?) {
        guard weeklyUserId != userId || userId == nil else { return }
        weeklyUserId = userId
        center.removePendingNotificationRequests(withIdentifiers: [StrongWeekReminder.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [StrongWeekReminder.identifier])
    }

    // Never prompt from launch/foreground. Existing notification permission is enough;
    // users without permission can enable this explicitly from Profile.
    //
    // Serialized. Launch alone calls this three or four times at once (auth listener, tab
    // view task, didBecomeActive). The earlier version detected overlap with a revision
    // counter and answered it by removing the pending request and re-adding — but
    // Notification Center applies removals and adds asynchronously, so overlapping calls
    // could remove the request the other one had just added and leave nothing scheduled.
    // Now each call waits for the previous one, and a correct request that is already
    // pending is left alone.
    @discardableResult
    func reconcileWeeklyReminder() async -> Bool {
        let previous = weeklyReconcile
        let task = Task { @MainActor [weak self] () -> Bool in
            _ = await previous?.value
            return await self?.performWeeklyReminderReconcile() ?? false
        }
        weeklyReconcile = task
        return await task.value
    }

    private func performWeeklyReminderReconcile() async -> Bool {
        guard let userId = weeklyUserId else { return false }
        let settings = await center.notificationSettings()
        // Signed out or switched accounts while waiting: that path already cleared the request.
        guard userId == weeklyUserId else { return false }
        guard StrongWeekReminder.enabled(userId: userId),
              settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            center.removePendingNotificationRequests(withIdentifiers: [StrongWeekReminder.identifier])
            center.removeDeliveredNotifications(withIdentifiers: [StrongWeekReminder.identifier])
            return false
        }
        let pending = await center.pendingNotificationRequests()
        if pending.contains(where: {
            $0.identifier == StrongWeekReminder.identifier
                && $0.content.userInfo["userId"] as? String == userId.uuidString
        }) {
            return true
        }
        guard userId == weeklyUserId else { return false }
        do {
            try await center.add(StrongWeekReminder.request(userId: userId))
        } catch {
            return false
        }
        // An account switch landed while Notification Center accepted the request.
        if userId != weeklyUserId {
            center.removePendingNotificationRequests(withIdentifiers: [StrongWeekReminder.identifier])
            return false
        }
        return true
    }

    @discardableResult
    func setWeeklyReminderEnabled(_ enabled: Bool, userId: UUID) async -> Bool {
        guard weeklyUserId == userId else { return false }
        if enabled {
            guard await requestPermissionIfNeeded(), weeklyUserId == userId else { return false }
        }
        UserDefaults.standard.set(enabled, forKey: StrongWeekReminder.preferenceKey(userId: userId))
        let scheduled = await reconcileWeeklyReminder()
        return !enabled || scheduled
    }

    // Shot reminders fire at 9am local time.
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
        // Paused or stopped: no shot reminders at all (GLP1TrackingStore restores them on resume).
        guard GLP1TrackingStore.shared.isTracking else { cancelGLP1Reminders(); return }
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

    func hasGLP1RemindersScheduled() async -> Bool {
        await center.pendingNotificationRequests().contains { $0.identifier.hasPrefix("glp1-") }
    }

    func cancelGLP1Reminders() {
        center.removePendingNotificationRequests(withIdentifiers: Self.allIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: Self.allIdentifiers)
    }

    // Reconcile a changed schedule without turning notifications back on for someone who
    // disabled them. Used for skips, undo, history edits, and cross-device refreshes.
    func reconcileGLP1Reminders(schedule: GLP1DoseSchedule) async {
        guard GLP1TrackingStore.shared.isTracking else { cancelGLP1Reminders(); return }
        let pending = await center.pendingNotificationRequests()
        let wasEnabled = pending.contains(where: { $0.identifier.hasPrefix("glp1-") })
        cancelGLP1Reminders()
        if wasEnabled, let due = schedule.nextDue {
            await scheduleGLP1Reminders(nextDueAt: due)
        }
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
            title: "Add your usual water",
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
        // Smart coaching is presented to the user as a Pulse feature (Profile's "Pulse
        // notifications" section, the "Pulse waits for a specific next step" explainer) even
        // though its content doesn't literally say "Pulse" — so it stops the moment Pulse is
        // turned off, same as the tab and the Strong Week outlook. It doesn't touch the AI
        // provider, so consent doesn't factor in here, only the master switch.
        guard PulseProfileStore.shared.pulseEnabled else {
            cancelSmartNotifications()
            return
        }
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

        // These automatic nudges cannot interpret free-text constraints. A tailored week
        // takes their place; shot reminders and the user's notification settings are unchanged.
        guard let week = try? await StrongWeekRepository().context(), !week.needsTailoredSuggestions else {
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
