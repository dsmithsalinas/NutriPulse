import XCTest
import UserNotifications
@testable import Footing

/// Opt-in live check against disposable accounts provisioned under /private/tmp.
/// Never signs a personal user out or writes medication data for an existing account.
@MainActor
final class MedicationHostedTests: XCTestCase {
    struct User: Decodable { var userId: UUID; var email: String; var password: String }
    struct Fixture: Decodable { var projectRef: String; var native: User; var other: User; var ui: User }

    func testHostedOfflineLoggingCASIsolationAndPause() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/footing-medications-e2e")
        let url = root.appendingPathComponent("ios-credentials.json")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("Requires disposable medication fixtures") }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        guard fixture.projectRef == "dcabdzuhuixlcgwavtsc", Config.supabaseURL.contains(fixture.projectRef),
              fixture.native.email.hasPrefix("footing-medications-e2e-"), fixture.other.email.hasPrefix("footing-medications-e2e-")
        else { XCTFail("Invalid fixture"); return }
        if let session = try? await supabase.auth.session, ![fixture.native.userId, fixture.other.userId].contains(session.user.id) {
            throw XCTSkip("Never replace a personal session")
        }
        let folder = root.appendingPathComponent("native-cache")
        defer { try? FileManager.default.removeItem(at: folder) }
        do {
            _ = try await supabase.auth.signIn(email: fixture.native.email, password: fixture.native.password)
            let store = MedicationStore(folder: folder, automaticallyReconcile: false)
            store.setAccount(fixture.native.userId)
            let day = MedicationCalendar.calendar.startOfDay(for: .now)
            try store.setEnabled(true, now: day)
            for name in ["Vitamin D", "Magnesium"] {
                try store.saveRoutine(name: name, amount: name == "Magnesium" ? "2 capsules" : "1 capsule",
                    weekdays: Set(1...7), times: [.init(minute: 480), .init(minute: 1140)], now: day)
            }
            let rows = store.occurrences(on: day); XCTAssertEqual(rows.count, 4)
            try store.record(rows[0], status: .taken)
            try store.record(rows[1], status: .skipped)
            let restarted = MedicationStore(folder: folder, automaticallyReconcile: false)
            restarted.setAccount(fixture.native.userId)
            XCTAssertEqual(restarted.document.events.count, 2)
            let uploaded = await restarted.sync(); XCTAssertTrue(uploaded)
            let fetched = try await RemoteMedicationTransport().fetch(owner: fixture.native.userId)
            let cloud = try XCTUnwrap(fetched)
            XCTAssertEqual(cloud.document.events.count, 2)
            XCTAssertEqual(cloud.document.occurrences(on: day).count, 4)
            XCTAssertEqual(cloud.document.schedules.first?.times.count, 2)
            // A new device decodes the hosted ISO dates and rebuilds the same occurrences.
            let otherDevice = MedicationStore(folder: root.appendingPathComponent("second-cache"), automaticallyReconcile: false)
            otherDevice.setAccount(fixture.native.userId)
            let downloaded = await otherDevice.sync(refresh: true); XCTAssertTrue(downloaded)
            XCTAssertEqual(otherDevice.occurrences(on: day).map(\.id), restarted.occurrences(on: day).map(\.id))
            let correction = restarted.occurrences(on: day)[0]
            try restarted.record(correction, status: .notLogged, source: "history")
            let undoSaved = await restarted.sync(); XCTAssertTrue(undoSaved)
            // A stale device cannot overwrite the undo with a feature-setting write.
            try otherDevice.setEnabled(false)
            let conflictSaved = await otherDevice.sync(); XCTAssertFalse(conflictSaved); XCTAssertTrue(otherDevice.hasConflict)
            try otherDevice.resolveConflict(useThisPhone: false)
            XCTAssertEqual(otherDevice.occurrences(on: day)[0].status, .notLogged)
            try restarted.setEnabled(false)
            let paused = await restarted.sync(); XCTAssertTrue(paused)
            let pausedFetched = try await RemoteMedicationTransport().fetch(owner: fixture.native.userId)
            let pausedCloud = try XCTUnwrap(pausedFetched)
            XCTAssertFalse(pausedCloud.document.enabled); XCTAssertEqual(pausedCloud.document.events.count, 3)
            _ = try await supabase.auth.signIn(email: fixture.other.email, password: fixture.other.password)
            let hidden: [MedicationRemoteRecord] = try await supabase.from("medication_tracking").select()
                .eq("user_id", value: fixture.native.userId).execute().value
            XCTAssertTrue(hidden.isEmpty)
            let report: [String: Any] = ["offlineRestart":true, "hostedRoundTrip":true, "fourDoses":true,
                "undoSynced":true, "staleDeviceConflict":true, "trackingOffPreservedHistory":true, "otherAccountIsolated":true]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys])
                .write(to: root.appendingPathComponent("native-results.json"), options: .atomic)
            try await supabase.auth.signOut()
            try? FileManager.default.removeItem(at: root.appendingPathComponent("second-cache"))
        } catch { try? await supabase.auth.signOut(); throw error }
    }

    func testMedicationCategoryPreservesSmartCategories() async {
        NotificationManager.shared.registerSmartCategories()
        let categories = await UNUserNotificationCenter.current().notificationCategories()
        XCTAssertTrue(categories.contains { $0.identifier == MedicationNotificationScheduler.category })
        XCTAssertTrue(categories.contains { $0.identifier == NotificationManager.recoveryCategory })
        let medication = categories.first { $0.identifier == MedicationNotificationScheduler.category }
        XCTAssertEqual(medication?.actions.first?.identifier, MedicationNotificationScheduler.takenAction)
        XCTAssertFalse(medication?.actions.first?.options.contains(.foreground) ?? true)
    }

    func testNotificationActionReachedCloudAndMasterSwitchCancelsPendingRequests() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/footing-medications-e2e")
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("ui-passed").path),
              FileManager.default.fileExists(atPath: root.appendingPathComponent("ios-credentials.json").path) else {
            throw XCTSkip("Run the disposable UI notification flow first")
        }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: root.appendingPathComponent("ios-credentials.json")))
        guard fixture.projectRef == "dcabdzuhuixlcgwavtsc", Config.supabaseURL.contains(fixture.projectRef),
              fixture.ui.email.hasPrefix("footing-medications-e2e-") else { XCTFail("Invalid fixture"); return }
        if let session = try? await supabase.auth.session, session.user.id != fixture.ui.userId { throw XCTSkip("Never replace a personal session") }
        do {
            _ = try await supabase.auth.signIn(email: fixture.ui.email, password: fixture.ui.password)
            let fetched = try await RemoteMedicationTransport().fetch(owner: fixture.ui.userId)
            let cloud = try XCTUnwrap(fetched)
            XCTAssertTrue(cloud.document.events.contains { $0.source == "notification" && $0.occurrence.name == "Notification vitamin" && $0.occurrence.status == .taken })
            let store = MedicationStore.shared; store.setAccount(fixture.ui.userId)
            let loaded = await store.sync(refresh: true); XCTAssertTrue(loaded)
            let scheduler = MedicationNotificationScheduler.shared, center = UNUserNotificationCenter.current()
            await scheduler.reconcile()
            let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(MedicationNotificationScheduler.prefix) }
            XCTAssertFalse(pending.isEmpty)
            XCTAssertLessThanOrEqual(pending.count, 56)
            XCTAssertTrue(pending.allSatisfy { $0.content.categoryIdentifier == MedicationNotificationScheduler.category })
            let eventCount = store.document.events.count
            try store.setEnabled(false)
            await scheduler.reconcile()
            let cancelled = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(MedicationNotificationScheduler.prefix) }
            XCTAssertTrue(cancelled.isEmpty)
            XCTAssertEqual(store.document.events.count, eventCount)
            try store.setEnabled(true)
            await scheduler.reconcile()
            let restored = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(MedicationNotificationScheduler.prefix) }
            XCTAssertFalse(restored.isEmpty)
            let synced = await store.sync(); XCTAssertTrue(synced)
            try JSONSerialization.data(withJSONObject: ["actionReachedCloud":true,"pendingBeforeOff":pending.count,
                "pendingWhileOff":cancelled.count,"pendingAfterOn":restored.count,"historyPreserved":true], options: [.prettyPrinted,.sortedKeys])
                .write(to: root.appendingPathComponent("notification-results.json"), options: .atomic)
            try await supabase.auth.signOut(scope: .local)
        } catch { try? await supabase.auth.signOut(scope: .local); throw error }
    }
}
