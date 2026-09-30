import Foundation
import Observation
import Supabase

/// Whether the user is currently on their GLP-1 medication as far as Footing is concerned.
enum GLP1TrackingStatus: String, Codable, CaseIterable {
    case active, paused, stopped
}

// "I've paused" / "I've stopped" (Profile → GLP-1 tracker). While not active, everything about
// the shot is turned off: the dose card, the shot cycle tile and check-ins, reminders, cycle
// insights, the widget's dose button, and what Pulse is told. Past logs are kept. Logging a
// dose (dated within the last couple of days) turns tracking back on.
//
// Stored on the account (profiles.glp1_tracking) so every device agrees, and cached on the
// device so Today and the reminders can decide at launch, before the profile loads.
@Observable
@MainActor
final class GLP1TrackingStore {
    static let shared = GLP1TrackingStore()

    private(set) var status: GLP1TrackingStatus
    private(set) var changedAt: Date?

    /// The one check every shot surface makes.
    var isTracking: Bool { status == .active }

    private let defaults: UserDefaults

    enum Key {
        static let status = "glp1.trackingStatus", changedAt = "glp1.trackingChangedAt"
        /// Whether shot reminders were on when tracking paused, so resuming puts them back
        /// (reminders are off while paused, and "were they on?" is otherwise lost).
        static let remindersBeforePause = "glp1.remindersBeforePause"
        static let all = [status, changedAt, remindersBeforePause]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        status = (defaults.string(forKey: Key.status)).flatMap(GLP1TrackingStatus.init) ?? .active
        changedAt = defaults.object(forKey: Key.changedAt) as? Date
        #if DEBUG
        // --glp1-paused: review the paused state without touching the account.
        if ProcessInfo.processInfo.arguments.contains("--glp1-paused") {
            status = .paused
            changedAt = .now
        }
        #endif
    }

    /// The server copy wins once the profile loads. A profile from before the column existed
    /// (nil) leaves the cached value alone rather than resetting it to active.
    func apply(profile: UserProfile?) {
        guard let raw = profile?.glp1Tracking, let loaded = GLP1TrackingStatus(rawValue: raw) else { return }
        guard loaded != status || profile?.glp1TrackingChangedAt != changedAt else { return }
        let wasTracking = isTracking
        status = loaded
        changedAt = profile?.glp1TrackingChangedAt
        cache()
        if wasTracking != isTracking { Task { await self.applySideEffects(wasTracking: wasTracking) } }
    }

    /// Pause, stop, or resume. Optimistic: the app changes at once; a failed save puts it back.
    func set(_ new: GLP1TrackingStatus) async throws {
        guard new != status else { return }
        let before = (status, changedAt)
        let wasTracking = isTracking
        status = new
        changedAt = .now
        cache()
        do {
            let userId = try await supabase.auth.session.user.id
            try await supabase.from("profiles")
                .update([
                    "glp1_tracking": AnyJSON.string(new.rawValue),
                    "glp1_tracking_changed_at": AnyJSON.string(Date.now.ISO8601Format()),
                ])
                .eq("id", value: userId)
                .execute()
        } catch {
            (status, changedAt) = before
            cache()
            throw error
        }
        await applySideEffects(wasTracking: wasTracking)
    }

    /// A dose was just logged. Taking a shot means tracking is back on, unless it's a
    /// backfilled entry from weeks ago, which is only history.
    func doseLogged(at injectedAt: Date) async {
        guard !isTracking, injectedAt > Date.now.addingTimeInterval(-2 * 86_400) else { return }
        try? await set(.active)
    }

    /// Sign-out: the next account starts tracking by default.
    func reset() {
        status = .active
        changedAt = nil
        Key.all.forEach(defaults.removeObject(forKey:))
    }

    // Reminders off while not tracking; back on at resume if they were on before.
    private func applySideEffects(wasTracking: Bool) async {
        let notifications = NotificationManager.shared
        if wasTracking, !isTracking {
            defaults.set(await notifications.hasGLP1RemindersScheduled(), forKey: Key.remindersBeforePause)
            notifications.cancelGLP1Reminders()
        } else if !wasTracking, isTracking {
            if defaults.bool(forKey: Key.remindersBeforePause),
               let schedule = try? await GLP1Repository().fetchDoseSchedule(), let due = schedule.nextDue {
                await notifications.scheduleGLP1Reminders(nextDueAt: due)
            }
            defaults.removeObject(forKey: Key.remindersBeforePause)
        }
        NotificationCenter.default.post(name: .glp1DoseHistoryChanged, object: nil)
    }

    private func cache() {
        defaults.set(status.rawValue, forKey: Key.status)
        defaults.set(changedAt, forKey: Key.changedAt)
    }

    #if DEBUG
    func setForPreview(_ status: GLP1TrackingStatus) {
        self.status = status
        changedAt = .now
    }
    #endif
}
