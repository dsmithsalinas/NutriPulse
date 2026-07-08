import XCTest
import SwiftData
@testable import NutriPulse

final class NutriPulseTests: XCTestCase {
    func testMealSortOrder() {
        let meals = Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(meals, [.breakfast, .lunch, .dinner, .snack])
    }

    func testFoodLogTotals() {
        let log = FoodLog(
            id: UUID(),
            userId: UUID(),
            loggedAt: Date(),
            logDate: "2024-03-15",
            meal: .breakfast,
            foodItemId: UUID(),
            quantity: 2.0,
            caloriesSnapshot: 100,
            proteinGSnapshot: 10,
            carbsGSnapshot: 15,
            fatGSnapshot: 3,
            fiberGSnapshot: 2,
            foodItems: nil
        )
        XCTAssertEqual(log.totalCalories, 200)
        XCTAssertEqual(log.totalProteinG, 20)
        XCTAssertEqual(log.totalFiberG, 4)
    }

    func testDateISOString() {
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(date.isoDateString, "2024-03-15")
    }
}

// MARK: - GLP-1 dose formatting

final class GLP1DoseFormattingTests: XCTestCase {

    // The regression: "%.2g" means two *significant digits*, so Mounjaro's real
    // 12.5 mg titration step rendered as "12 mg" in the dose picker and chart axis.
    func testHalfMilligramDoseIsNotTruncated() {
        XCTAssertEqual(String(format: "%.2g", 12.5), "12", "precondition: this is the old, wrong behavior")
        XCTAssertNotEqual((12.5).glp1DoseString, "12")
    }

    // Locale-independent correctness check: every dose the app offers must survive
    // a render → parse round trip.
    func testEveryAvailableDoseRoundTrips() throws {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current

        for medication in GLP1Medication.allCases {
            for dose in medication.availableDoses {
                let rendered = dose.glp1DoseString
                let parsed = try XCTUnwrap(
                    formatter.number(from: rendered)?.doubleValue,
                    "\(medication.rawValue): '\(rendered)' is not parseable as a number"
                )
                XCTAssertEqual(
                    parsed, dose, accuracy: 0.0001,
                    "\(medication.rawValue) dose \(dose) mg rendered as '\(rendered)'"
                )
            }
        }
    }

    func testWholeDosesDropTheFraction() {
        XCTAssertEqual((10.0).glp1DoseString, "10")
        XCTAssertEqual((5.0).glp1DoseString, "5")
    }
}

// MARK: - Decimal text input

final class DecimalInputTests: XCTestCase {

    private let us = Locale(identifier: "en_US")
    private let de = Locale(identifier: "de_DE")

    // The core of the manual-entry bug: what the user types must reach the model
    // immediately, on every keystroke, with no focus change.
    func testParsesPlainInput() {
        XCTAssertEqual(DecimalInput.value(from: "250", locale: us), 250)
        XCTAssertEqual(DecimalInput.value(from: "12.5", locale: us), 12.5)
        XCTAssertEqual(DecimalInput.value(from: "", locale: us), 0)
    }

    // Mid-typing state: "1." must already parse, or the field fights the user.
    func testParsesTrailingSeparator() {
        XCTAssertEqual(DecimalInput.value(from: "1.", locale: us), 1)
        XCTAssertEqual(DecimalInput.value(from: "1,", locale: de), 1)
    }

    // German/French/Spanish keypads emit a comma. Double("75,5") is nil.
    func testCommaDecimalLocale() {
        XCTAssertEqual(DecimalInput.sanitize("75,5", locale: de), "75,5")
        XCTAssertEqual(DecimalInput.value(from: "75,5", locale: de), 75.5)
    }

    // A period typed on a comma keypad (and vice versa) normalizes to the locale's.
    func testSeparatorNormalization() {
        XCTAssertEqual(DecimalInput.sanitize("75.5", locale: de), "75,5")
        XCTAssertEqual(DecimalInput.sanitize("75,5", locale: us), "75.5")
    }

    // .decimalPad has no minus key, but paste bypasses the keyboard. A negative macro
    // corrupts every daily total that sums it.
    func testStripsNegativeSign() {
        XCTAssertEqual(DecimalInput.sanitize("-50", locale: us), "50")
        XCTAssertEqual(DecimalInput.value(from: DecimalInput.sanitize("-50", locale: us), locale: us), 50)
    }

    func testStripsJunkAndExtraSeparators() {
        XCTAssertEqual(DecimalInput.sanitize("1.2.3", locale: us), "1.23")
        XCTAssertEqual(DecimalInput.sanitize("12abc3", locale: us), "123")
        XCTAssertEqual(DecimalInput.sanitize("½", locale: us), "", "vulgar fractions are isNumber but not a value")
    }

    // Round trip: rendering must not emit grouping separators, or the next keystroke
    // re-reads "1,000" as a decimal.
    func testTextRoundTripsWithoutGrouping() {
        XCTAssertEqual(DecimalInput.text(from: 1000, locale: us), "1000")
        XCTAssertEqual(DecimalInput.text(from: 0, locale: us), "", "zero shows the placeholder instead")
        XCTAssertEqual(DecimalInput.value(from: DecimalInput.text(from: 12.5, locale: de), locale: de), 12.5)
    }
}

// MARK: - LocalStore sync-state transitions
//
// These pin the compare-and-set behaviour that keeps a push from clobbering an
// edit or delete the user made while the request was in flight.

@MainActor
final class LocalStoreSyncStateTests: XCTestCase {

    private var container: ModelContainer!
    private let userId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([SDFoodLog.self, SDWaterLog.self, SDDailyGoal.self])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        LocalStore.shared.configure(with: container)
    }

    // MARK: Helpers

    @discardableResult
    private func insertLog(quantity: Double = 1.0) throws -> UUID {
        let id = UUID()
        try LocalStore.shared.insertFoodLog(
            id: id, userId: userId, logDate: "2026-07-07", meal: "lunch",
            foodItemId: UUID(), foodItemName: "Rice", quantity: quantity,
            caloriesSnapshot: 100, proteinGSnapshot: 2,
            carbsGSnapshot: 20, fatGSnapshot: 1, fiberGSnapshot: 1
        )
        return id
    }

    private func row(_ id: UUID) throws -> SDFoodLog? {
        let descriptor = FetchDescriptor<SDFoodLog>(predicate: #Predicate { $0.id == id })
        return try container.mainContext.fetch(descriptor).first
    }

    // MARK: Create

    func testCleanCreatePushMarksSynced() throws {
        let id = try insertLog()
        let pushed = try XCTUnwrap(row(id)).revision

        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: pushed)

        XCTAssertEqual(try XCTUnwrap(row(id)).syncState, "synced")
    }

    // Edit lands while the create is in flight: the remote row now exists, so the
    // newer values need a real UPDATE. Marking it "synced" here silently discarded
    // the edit, and the next pull overwrote local state with the stale server value.
    func testEditDuringInFlightCreateBecomesPendingUpdate() throws {
        let id = try insertLog(quantity: 1.0)
        let pushedRevision = try XCTUnwrap(row(id)).revision  // push captures this...

        try LocalStore.shared.updateFoodLog(id: id, meal: "dinner", quantity: 2.5)  // ...user edits mid-flight

        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: pushedRevision)

        let log = try XCTUnwrap(row(id))
        XCTAssertEqual(log.syncState, "pendingUpdate")
        XCTAssertEqual(log.quantity, 2.5)
    }

    // Delete lands while the create is in flight. The tombstone must survive, or the
    // entry the user just deleted comes back on the next pull.
    func testDeleteDuringInFlightCreateKeepsTombstone() throws {
        let id = try insertLog()
        let pushedRevision = try XCTUnwrap(row(id)).revision

        try LocalStore.shared.markFoodLogDeleted(id: id)

        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: pushedRevision)

        XCTAssertEqual(try XCTUnwrap(row(id)).syncState, "pendingDelete")
        XCTAssertTrue(try LocalStore.shared.fetchFoodLogs(for: dateFor("2026-07-07"), userId: userId).isEmpty)
    }

    // Deleting an unsynced row must tombstone, not hard-delete: its create may
    // already have reached the server.
    func testDeletingPendingCreateTombstonesRatherThanDropping() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogDeleted(id: id)
        XCTAssertNotNil(try row(id), "row was hard-deleted; the server copy would be orphaned")
        XCTAssertEqual(try XCTUnwrap(row(id)).syncState, "pendingDelete")
    }

    // MARK: Update

    func testEditDuringInFlightUpdateStaysPending() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)

        try LocalStore.shared.updateFoodLog(id: id, meal: "dinner", quantity: 2.0)
        let pushedRevision = try XCTUnwrap(row(id)).revision   // push captures this...
        try LocalStore.shared.updateFoodLog(id: id, meal: "dinner", quantity: 3.0)  // ...user edits again

        try LocalStore.shared.markFoodLogUpdated(id: id, pushedRevision: pushedRevision)

        let log = try XCTUnwrap(row(id))
        XCTAssertEqual(log.syncState, "pendingUpdate", "the newer quantity still needs pushing")
        XCTAssertEqual(log.quantity, 3.0)
    }

    func testCleanUpdatePushMarksSynced() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)
        try LocalStore.shared.updateFoodLog(id: id, meal: "dinner", quantity: 2.0)

        try LocalStore.shared.markFoodLogUpdated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)

        XCTAssertEqual(try XCTUnwrap(row(id)).syncState, "synced")
    }

    // MARK: Delete

    func testDeleteCompletionOnlyRemovesTombstonedRows() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)

        try LocalStore.shared.removeFoodLogAfterDelete(id: id)   // row is "synced", not tombstoned

        XCTAssertNotNil(try row(id), "a synced row must not be removed by a delete completion")

        try LocalStore.shared.markFoodLogDeleted(id: id)
        try LocalStore.shared.removeFoodLogAfterDelete(id: id)
        XCTAssertNil(try row(id))
    }

    // MARK: Goal ownership

    // The cross-account leak: SDDailyGoal had no owner, so the next user to sign in
    // on this device read the previous user's calorie and macro targets.
    func testGoalIsScopedToItsOwner() throws {
        let otherUser = UUID()
        try LocalStore.shared.upsertGoal(goal(for: userId, calories: 1800))

        XCTAssertEqual(try LocalStore.shared.fetchGoal(for: .now, userId: userId)?.calories, 1800)
        XCTAssertNil(try LocalStore.shared.fetchGoal(for: .now, userId: otherUser))
    }

    func testWipeAllClearsCachedRows() throws {
        let id = try insertLog()
        try LocalStore.shared.upsertGoal(goal(for: userId, calories: 1800))

        try LocalStore.shared.wipeAll()

        XCTAssertNil(try row(id))
        XCTAssertNil(try LocalStore.shared.fetchGoal(for: .now, userId: userId))
    }

    // MARK: Fixtures

    private func goal(for userId: UUID, calories: Double) -> DailyGoal {
        DailyGoal(
            id: UUID(), userId: userId,
            effectiveDate: Date.now.isoDateString,
            calories: calories, proteinG: 150, carbsG: 180,
            fatG: 60, fiberG: 30, waterMlTarget: 2000
        )
    }

    private func dateFor(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.date(from: iso)!
    }
}
