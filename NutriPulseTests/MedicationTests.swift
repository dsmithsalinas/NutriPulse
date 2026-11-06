import XCTest
@testable import Footing

@MainActor
private final class MedicationTestTransport: MedicationTransport {
    var remote: MedicationRemoteRecord?
    var fail = false
    var loseResponseOnce = false
    var beforeSave: (() -> Void)?
    func fetch(owner: UUID) async throws -> MedicationRemoteRecord? {
        if fail { throw URLError(.notConnectedToInternet) }
        return remote?.user_id == owner ? remote : nil
    }
    func save(owner: UUID, document: MedicationDocument, expectedRevision: Int, writeID: UUID) async throws -> MedicationRemoteRecord {
        beforeSave?(); beforeSave = nil
        if fail { throw URLError(.notConnectedToInternet) }
        if let remote, remote.write_id == writeID { return remote }
        guard (remote?.revision ?? 0) == expectedRevision else { throw MedicationError.conflict }
        let result = MedicationRemoteRecord(user_id: owner, revision: expectedRevision + 1, write_id: writeID, document: document)
        remote = result
        if loseResponseOnce { loseResponseOnce = false; throw URLError(.networkConnectionLost) }
        return result
    }
}

@MainActor
final class MedicationTests: XCTestCase {
    private var folders: [URL] = []
    override func tearDown() {
        for folder in folders { try? FileManager.default.removeItem(at: folder) }
        folders = []
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private var start: Date { date("2026-11-06T00:00:00Z") }
    private func makeStore(transport: MedicationTestTransport? = nil) -> MedicationStore {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        folders.append(folder)
        let store = MedicationStore(folder: folder, transport: transport ?? MedicationTestTransport(), automaticallyReconcile: false)
        store.setAccount(UUID())
        return store
    }
    private func populate(_ store: MedicationStore, at now: Date) throws {
        try store.setEnabled(true, now: now)
        for name in ["Vitamin D", "Magnesium"] {
            try store.saveRoutine(name: name, amount: name == "Magnesium" ? "2 capsules" : "1 capsule",
                weekdays: Set(1...7), times: [.init(minute: 480), .init(minute: 1140)], now: now)
        }
    }
    func testSeparateAmountAndTimesCreateFourDistinctDoses() throws {
        let store = makeStore()
        let day = MedicationCalendar.calendar.startOfDay(for: start)
        try populate(store, at: day)
        let doses = store.occurrences(on: day)
        XCTAssertEqual(doses.count, 4)
        XCTAssertEqual(Set(doses.map(\.id)).count, 4)
        XCTAssertEqual(doses.filter { $0.group == "Morning" }.count, 2)
        XCTAssertEqual(doses.filter { $0.name == "Magnesium" }.map(\.amount), ["2 capsules", "2 capsules"])
        let evening = MedicationCalendar.calendar.date(byAdding: .hour, value: 20, to: day)!
        try store.record(doses[0], status: .taken, now: evening)
        XCTAssertEqual(store.occurrences(on: day).filter { $0.status == .notLogged }.count, 3)
    }
    func testDefaultOffPauseResumeAndNoBackfilledDisabledDays() throws {
        let store = makeStore(), calendar = MedicationCalendar.calendar
        let day = calendar.startOfDay(for: start)
        XCTAssertFalse(store.enabled)
        try populate(store, at: day)
        let first = store.occurrences(on: day)[0]
        try store.record(first, status: .taken, now: calendar.date(byAdding: .hour, value: 9, to: day)!)
        try store.setEnabled(false, now: calendar.date(byAdding: .hour, value: 10, to: day)!)
        XCTAssertFalse(store.enabled)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        XCTAssertTrue(store.occurrences(on: tomorrow).isEmpty)
        XCTAssertEqual(store.occurrences(on: day).first?.status, .taken)
        let resume = calendar.date(byAdding: .day, value: 2, to: day)!
        try store.setEnabled(true, now: calendar.date(byAdding: .hour, value: 12, to: resume)!)
        XCTAssertEqual(store.occurrences(on: resume).count, 2)
        XCTAssertTrue(store.occurrences(on: tomorrow).isEmpty)
    }
    func testOfflineRestartUndoAndAccountIsolation() async throws {
        let transport = MedicationTestTransport(); transport.fail = true
        let store = makeStore(transport: transport), owner = store.accountID!
        let day = MedicationCalendar.calendar.startOfDay(for: start)
        try populate(store, at: day)
        let dose = store.occurrences(on: day)[0]
        try store.record(dose, status: .skipped, now: day)
        let synced = await store.sync(); XCTAssertFalse(synced)
        let restarted = MedicationStore(folder: folders.last!, transport: transport, automaticallyReconcile: false)
        restarted.setAccount(owner)
        XCTAssertTrue(restarted.enabled)
        XCTAssertEqual(restarted.occurrences(on: day).first?.status, .skipped)
        try restarted.record(restarted.occurrences(on: day)[0], status: .notLogged, now: day)
        XCTAssertEqual(restarted.document.events.count, 2)
        restarted.setAccount(UUID()); XCTAssertFalse(restarted.enabled)
        XCTAssertTrue(restarted.occurrences(on: day).isEmpty)
        restarted.setAccount(owner)
        XCTAssertEqual(restarted.occurrences(on: day).first?.status, .notLogged)
        transport.fail = false
        let retried = await restarted.sync(); XCTAssertTrue(retried)
        XCTAssertEqual(restarted.pendingCount, 0)
    }
    func testDuplicateNotificationAndOldRevisionAfterUndoAreRejected() throws {
        let store = makeStore(), now = Date.now, calendar = MedicationCalendar.calendar
        let day = calendar.startOfDay(for: now)
        try populate(store, at: day)
        let dose = store.occurrences(on: now)[0]
        try store.record(dose, status: .taken, source: "notification", now: now)
        XCTAssertThrowsError(try store.record(dose, status: .taken, source: "notification", now: now))
        try store.record(store.occurrences(on: now)[0], status: .notLogged, now: now)
        XCTAssertThrowsError(try store.record(dose, status: .taken, source: "notification", now: now))
        try store.setEnabled(false, now: now)
        XCTAssertThrowsError(try store.record(store.occurrences(on: now)[0], status: .taken, source: "notification", now: now))
    }
    func testTomorrowEditsAndArchivePreserveOldSnapshotsAndUnloggedHistory() throws {
        let store = makeStore(), calendar = MedicationCalendar.calendar
        let day = calendar.startOfDay(for: start), tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start))!
        try populate(store, at: day)
        let old = store.document.schedules[0]
        try store.record(store.occurrences(on: day)[0], status: .taken, now: day)
        try store.saveRoutine(routineID: old.routineID, name: "Changed", amount: "3 capsules", weekdays: Set(1...7),
                              times: [.init(minute: 720)], now: calendar.date(byAdding: .hour, value: 10, to: day)!)
        XCTAssertTrue(store.occurrences(on: day).contains { $0.name == old.name && $0.amount == old.amount })
        XCTAssertTrue(store.occurrences(on: tomorrow).contains { $0.name == "Changed" && $0.amount == "3 capsules" })
        try store.archive(old.routineID, now: tomorrow)
        XCTAssertFalse(store.occurrences(on: tomorrow).contains { $0.routineID == old.routineID })
        XCTAssertTrue(store.occurrences(on: day).contains { $0.routineID == old.routineID })
    }
    func testApplyTodayDoesNotRepeatAnEveningDoseTakenEarlyAndUndoRestoresOneSlot() throws {
        let store = makeStore(), calendar = MedicationCalendar.calendar
        let day = calendar.startOfDay(for: start), noon = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: start))!
        try populate(store, at: day)
        let evening = try XCTUnwrap(store.occurrences(on: day).first { $0.name == "Vitamin D" && $0.minute == 1140 })
        let schedule = try XCTUnwrap(store.document.schedules.first { $0.routineID == evening.routineID })
        try store.record(evening, status: .taken, now: noon)
        try store.saveRoutine(routineID: schedule.routineID, name: schedule.name, amount: schedule.amount,
            weekdays: schedule.weekdays, times: schedule.times, applyToday: true, now: noon)
        let resolved = store.occurrences(on: day).filter { $0.routineID == schedule.routineID && $0.minute == 1140 }
        XCTAssertEqual(resolved.count, 1); XCTAssertEqual(resolved.first?.status, .taken)
        try store.record(resolved[0], status: .notLogged, now: noon)
        let undone = store.occurrences(on: day).filter { $0.routineID == schedule.routineID && $0.minute == 1140 }
        XCTAssertEqual(undone.count, 1); XCTAssertEqual(undone.first?.status, .notLogged)
    }
    func testCrossDeviceConflictRetainsLocalEditsAndRequiresExplicitResolution() async throws {
        let transport = MedicationTestTransport(), store = makeStore()
        let folder = folders.last!
        let a = MedicationStore(folder: folder, transport: transport, automaticallyReconcile: false)
        a.setAccount(store.accountID)
        try populate(a, at: MedicationCalendar.calendar.startOfDay(for: start))
        let firstSync = await a.sync(); XCTAssertTrue(firstSync)
        let bFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); folders.append(bFolder)
        let b = MedicationStore(folder: bFolder, transport: transport, automaticallyReconcile: false); b.setAccount(a.accountID)
        let loaded = await b.sync(refresh: true); XCTAssertTrue(loaded)
        try a.setEnabled(false, now: start.addingTimeInterval(3600))
        let aSaved = await a.sync(); XCTAssertTrue(aSaved)
        try b.saveRoutine(name: "Local vitamin", amount: "", weekdays: Set(1...7), times: [.init(minute: 600)], now: start)
        let bSaved = await b.sync(); XCTAssertFalse(bSaved)
        XCTAssertTrue(b.hasConflict)
        XCTAssertTrue(b.document.schedules.contains { $0.name == "Local vitamin" })
        XCTAssertThrowsError(try b.setEnabled(false))
        try b.resolveConflict(useThisPhone: false)
        XCTAssertFalse(b.enabled); XCTAssertFalse(b.hasConflict)
        XCTAssertFalse(b.document.schedules.contains { $0.name == "Local vitamin" })
    }
    func testMutationDuringUploadKeepsNewerPendingRevision() async throws {
        let transport = MedicationTestTransport(), store = makeStore(transport: MedicationTestTransport())
        let a = MedicationStore(folder: folders.last!, transport: transport, automaticallyReconcile: false); a.setAccount(store.accountID)
        try populate(a, at: start)
        transport.beforeSave = { try! a.setEnabled(false, now: self.start.addingTimeInterval(60)) }
        let first = await a.sync(); XCTAssertTrue(first)
        XCTAssertEqual(a.pendingCount, 1)
        let second = await a.sync(); XCTAssertTrue(second)
        XCTAssertEqual(a.pendingCount, 0); XCTAssertFalse(transport.remote!.document.enabled)
    }
    func testLostCommitResponseRetriesWithoutDuplicatingEvents() async throws {
        let transport = MedicationTestTransport(), store = makeStore(transport: MedicationTestTransport())
        let a = MedicationStore(folder: folders.last!, transport: transport, automaticallyReconcile: false)
        a.setAccount(store.accountID)
        let day = MedicationCalendar.calendar.startOfDay(for: start)
        try populate(a, at: day)
        try a.record(a.occurrences(on: day)[0], status: .taken, now: day)
        transport.loseResponseOnce = true
        let lost = await a.sync(); XCTAssertFalse(lost)
        let retried = await a.sync(); XCTAssertTrue(retried)
        XCTAssertEqual(transport.remote?.revision, 1)
        XCTAssertEqual(transport.remote?.document.events.count, 1)
        XCTAssertEqual(a.pendingCount, 0)
    }
    func testAccountSwitchDuringUploadCannotApplyOldAccountState() async throws {
        let transport = MedicationTestTransport(), store = makeStore(transport: MedicationTestTransport())
        let a = MedicationStore(folder: folders.last!, transport: transport, automaticallyReconcile: false)
        a.setAccount(store.accountID)
        try populate(a, at: start)
        let nextOwner = UUID()
        transport.beforeSave = { a.setAccount(nextOwner) }
        let result = await a.sync(); XCTAssertFalse(result)
        XCTAssertEqual(a.accountID, nextOwner); XCTAssertFalse(a.enabled)
        XCTAssertTrue(a.document.schedules.isEmpty)
    }
    func testDiskFailureDoesNotClaimActivationWasSaved() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        folders.append(parent)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let blocked = parent.appendingPathComponent("file-not-directory")
        try Data("occupied".utf8).write(to: blocked)
        let store = MedicationStore(folder: blocked, transport: MedicationTestTransport(), automaticallyReconcile: false)
        store.setAccount(UUID())
        XCTAssertThrowsError(try store.setEnabled(true))
        XCTAssertFalse(store.enabled); XCTAssertEqual(store.pendingCount, 0)
    }
    func testInvalidSchedulesAndFutureTakenTimeAreRejected() throws {
        XCTAssertFalse(MedicationCalendar.valid(name: " ", amount: "", weekdays: [1], times: [.init(minute: 480)]))
        XCTAssertFalse(MedicationCalendar.valid(name: "D", amount: "", weekdays: [], times: [.init(minute: 480)]))
        XCTAssertFalse(MedicationCalendar.valid(name: "D", amount: "", weekdays: [1], times: [.init(minute: 480), .init(minute: 480)]))
        let store = makeStore(), day = MedicationCalendar.calendar.startOfDay(for: start)
        try populate(store, at: day)
        XCTAssertThrowsError(try store.record(store.occurrences(on: day)[0], status: .taken, takenAt: day.addingTimeInterval(60), now: day))
    }
    func testCalendarExpansionHandlesDSTAndSelectedWeekdays() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let spring = date("2026-03-08T08:00:00Z"), fall = date("2026-11-01T07:00:00Z")
        let schedule = MedicationSchedule(routineID: UUID(), name: "Vitamin", amount: "", weekdays: [1],
            times: [.init(minute: 150)], startsAt: date("2026-01-01T00:00:00Z"))
        let doc = MedicationDocument(enabled: true, intervals: [.init(start: schedule.startsAt)], schedules: [schedule])
        let springDoses = doc.occurrences(on: spring, calendar: calendar)
        XCTAssertEqual(springDoses.count, 1)
        XCTAssertEqual(calendar.component(.hour, from: springDoses[0].scheduledAt), 3)
        XCTAssertEqual(doc.occurrences(on: fall, calendar: calendar).count, 1)
        XCTAssertTrue(doc.occurrences(on: calendar.date(byAdding: .day, value: 1, to: spring)!, calendar: calendar).isEmpty)
        XCTAssertEqual(MedicationCalendar.notificationBudget(otherRequestCount: 12), 52)
        XCTAssertEqual(MedicationCalendar.notificationBudget(otherRequestCount: 70), 0)
    }
}
