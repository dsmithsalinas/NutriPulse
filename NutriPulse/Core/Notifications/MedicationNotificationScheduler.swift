import Foundation
import Observation
import UserNotifications

@Observable @MainActor
final class MedicationNotificationScheduler {
    static let shared = MedicationNotificationScheduler()
    static let prefix = "medication-"
    static let category = "medication-dose"
    static let takenAction = "medication-taken"
    static let skipAction = "medication-skip"
    private let center = UNUserNotificationCenter.current()
    private var reconciliation: Task<Void, Never>?
    private(set) var scheduledThrough: Date?
    private(set) var permissionDenied = false
    private(set) var schedulingFailed = false
    private(set) var capacityConstrained = false

    static var notificationCategory: UNNotificationCategory {
        UNNotificationCategory(identifier: category, actions: [
            UNNotificationAction(identifier: takenAction, title: "Mark taken", options: []),
            UNNotificationAction(identifier: skipAction, title: "Skip", options: [])
        ], intentIdentifiers: [])
    }

    /// Reserve eight requests for other Footing features; also account for all requests
    /// already owned by those features. Never remove their requests to make room.
    static func budget(otherRequestCount: Int) -> Int { MedicationCalendar.notificationBudget(otherRequestCount: otherRequestCount) }

    func reconcile() async {
        let previous = reconciliation
        let task = Task { @MainActor in
            await previous?.value
            await self.performReconcile()
        }
        reconciliation = task
        await task.value
    }

    private func performReconcile() async {
        let store = MedicationStore.shared
        let owner = store.accountID, revision = store.cache.writeID
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        guard store.accountID == owner, store.cache.writeID == revision else { return }
        let ourPending = pending.filter { $0.identifier.hasPrefix(Self.prefix) }
        scheduledThrough = nil; schedulingFailed = false; capacityConstrained = false
        permissionDenied = settings.authorizationStatus == .denied
        let delivered = await center.deliveredNotifications()
        guard store.accountID == owner, store.cache.writeID == revision else { return }
        let obsoleteDelivered = delivered.filter { notification in
            guard notification.request.identifier.hasPrefix(Self.prefix) else { return false }
            let info = notification.request.content.userInfo
            guard store.enabled, !store.hasConflict,
                  info["userId"] as? String == owner?.uuidString,
                  let id = info["occurrenceId"] as? String,
                  let rawDay = info["localDay"] as? String, let day = Date.fromISODateString(rawDay),
                  let dose = store.occurrences(on: day).first(where: { $0.id == id }),
                  dose.status == .notLogged,
                  reminderEnabled(dose.routineID, owner: owner) else { return true }
            return false
        }
        center.removeDeliveredNotifications(withIdentifiers: obsoleteDelivered.map { $0.request.identifier })
        guard let owner, store.enabled, !store.hasConflict,
              settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            center.removePendingNotificationRequests(withIdentifiers: ourPending.map(\.identifier))
            return
        }
        let now = Date.now, calendar = MedicationCalendar.calendar
        var candidates: [MedicationOccurrence] = []
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            candidates += store.occurrences(on: day).filter {
                $0.status == .notLogged && $0.scheduledAt > now && reminderEnabled($0.routineID, owner: owner)
            }
        }
        candidates.sort { $0.scheduledAt < $1.scheduledAt }
        let capacity = Self.budget(otherRequestCount: pending.count - ourPending.count)
        let selected = Array(candidates.prefix(capacity))
        capacityConstrained = selected.count < candidates.count
        let desiredIDs = Set(selected.map { Self.prefix + owner.uuidString + "-" + $0.id })
        center.removePendingNotificationRequests(withIdentifiers: ourPending.filter { !desiredIDs.contains($0.identifier) }.map(\.identifier))
        let existing = Dictionary(uniqueKeysWithValues: ourPending.map { ($0.identifier, $0) })
        var added: [String] = []
        for dose in selected {
            guard store.accountID == owner, store.cache.writeID == revision, store.enabled else { break }
            let content = UNMutableNotificationContent()
            content.title = "Time for \(dose.name)"
            content.body = dose.amount.isEmpty ? "Mark this dose taken when you’re ready." : "\(dose.amount) · Mark taken when you’re ready."
            content.sound = .default; content.categoryIdentifier = Self.category
            content.userInfo = ["userId": owner.uuidString, "occurrenceId": dose.id,
                                "localDay": dose.localDay, "revision": dose.revision.uuidString]
            let id = Self.prefix + owner.uuidString + "-" + dose.id
            if let request = existing[id],
               request.content.userInfo["revision"] as? String == dose.revision.uuidString,
               let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let fire = trigger.nextTriggerDate(), abs(fire.timeIntervalSince(dose.scheduledAt)) < 1 {
                scheduledThrough = dose.scheduledAt
                continue
            }
            // Absolute date components retain this occurrence's identity. A significant
            // clock/time-zone change regenerates future requests from local wall-clock times.
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dose.scheduledAt)
            components.timeZone = calendar.timeZone
            do {
                try await center.add(UNNotificationRequest(identifier: id, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
                added.append(id)
                if store.accountID == owner, store.cache.writeID == revision { scheduledThrough = dose.scheduledAt }
            } catch { schedulingFailed = true; break }
        }
        if store.accountID != owner || store.cache.writeID != revision || !store.enabled {
            center.removePendingNotificationRequests(withIdentifiers: added)
            scheduledThrough = nil
        }
    }

    private static func preferenceKey(_ routine: UUID, _ owner: UUID) -> String {
        "medicationReminder.\(owner.uuidString).\(routine.uuidString)"
    }
    func reminderEnabled(_ routine: UUID, owner: UUID?) -> Bool {
        guard let owner else { return false }
        // Per-device notification permission/preferences never propagate to another phone.
        return UserDefaults.standard.bool(forKey: Self.preferenceKey(routine, owner))
    }
    func setReminder(_ enabled: Bool, routine: UUID, owner: UUID) {
        UserDefaults.standard.set(enabled, forKey: Self.preferenceKey(routine, owner))
        Task { await reconcile() }
    }
    func purgePreferences(owner: UUID) {
        let prefix = "medicationReminder.\(owner.uuidString)."
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func handle(_ response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let rawOwner = info["userId"] as? String, let owner = UUID(uuidString: rawOwner),
              let rawDay = info["localDay"] as? String, let day = Date.fromISODateString(rawDay),
              let occurrenceID = info["occurrenceId"] as? String else { return }
        // Auth restoration may still be in progress on a cold launch. Save a route for
        // review instead of trusting a notification payload as account authorization.
        guard supabase.auth.currentSession?.user.id == owner else {
            MedicationNotificationRoute.save(owner: owner, day: rawDay, occurrenceID: occurrenceID,
                needsReview: response.actionIdentifier != UNNotificationDefaultActionIdentifier)
            return
        }
        let store = MedicationStore.shared
        store.setAccount(owner)
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            MedicationNotificationRoute.save(owner: owner, day: rawDay, occurrenceID: occurrenceID)
            return
        }
        guard response.actionIdentifier == Self.takenAction || response.actionIdentifier == Self.skipAction else { return }
        do {
            guard let dose = store.occurrences(on: day).first(where: { $0.id == occurrenceID }),
                  reminderEnabled(dose.routineID, owner: owner),
                  info["revision"] as? String == dose.revision.uuidString else { throw MedicationError.stale }
            try store.record(dose, status: response.actionIdentifier == Self.takenAction ? .taken : .skipped, source: "notification")
            center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
            // Saving is durable before any network work. Do not keep the OS action alive
            // waiting on authentication refresh or an unavailable connection.
        } catch {
            MedicationNotificationRoute.save(owner: owner, day: rawDay, occurrenceID: occurrenceID, needsReview: true)
        }
    }
}

enum MedicationNotificationRoute {
    private static let key = "medicationNotificationRoute"
    struct Route: Codable, Identifiable {
        var owner: UUID; var day: String; var occurrenceID: String?; var needsReview: Bool
        var id: String { owner.uuidString + day }
    }
    static func save(owner: UUID, day: String, occurrenceID: String? = nil, needsReview: Bool = false) {
        guard let data = try? JSONEncoder().encode(Route(owner: owner, day: day, occurrenceID: occurrenceID, needsReview: needsReview)) else { return }
        UserDefaults.standard.set(data, forKey: key)
        NotificationCenter.default.post(name: .medicationNotificationOpened, object: nil)
    }
    static func consume(owner: UUID) -> Route? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let route = try? JSONDecoder().decode(Route.self, from: data) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return route.owner == owner ? route : nil
    }
    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
