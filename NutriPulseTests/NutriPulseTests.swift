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

// MARK: - Barcode normalization

final class BarcodeNormalizerTests: XCTestCase {

    // The scanner accepts .upce but forwarded the compressed code verbatim; FatSecret's
    // find_id_for_barcode wants a GTIN-13, so every small-package product came back
    // "Barcode Not Found" even when FatSecret had it.
    func testExpandsUPCEToUPCA() {
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("04252614"), "042100005264")
    }

    func testUPCEBecomesThirteenDigits() {
        XCTAssertEqual(BarcodeNormalizer.gtin13(value: "04252614", symbology: .upce), "0042100005264")
    }

    // Each trailing digit selects a different zero-reinsertion rule.
    func testEveryUPCECompressionRule() {
        // last digit 0-2: M1 M2 [last] 0000 M3 M4 M5
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("01278906")?.prefix(11), "01200000789")
        // last digit 3: M1 M2 M3 00000 M4 M5
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("01234531")?.prefix(11), "01230000045")
        // last digit 4: M1 M2 M3 M4 00000 M5
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("01234541")?.prefix(11), "01234000005")
        // last digit 5-9: M1..M5 0000 [last]
        XCTAssertEqual(BarcodeNormalizer.expandUPCE("05673894")?.prefix(11), "05673800009")
    }

    // EAN-8 and UPC-E are both eight digits — only the symbology distinguishes them, so an
    // EAN-8 must be zero-padded, never expanded as if it were a compressed UPC-A.
    func testEAN8IsPaddedNotExpanded() {
        XCTAssertEqual(BarcodeNormalizer.gtin13(value: "04252614", symbology: .ean8), "0000004252614")
    }

    func testEAN13PassesThroughAndUPCAIsPadded() {
        XCTAssertEqual(BarcodeNormalizer.gtin13(value: "5000112637922", symbology: .ean13), "5000112637922")
        XCTAssertEqual(BarcodeNormalizer.gtin13(value: "042100005264", symbology: .ean13), "0042100005264")
    }

    func testRejectsGarbage() {
        XCTAssertNil(BarcodeNormalizer.gtin13(value: "abc", symbology: .other))
        XCTAssertNil(BarcodeNormalizer.gtin13(value: "12345678901234", symbology: .other), "longer than GTIN-13")
        XCTAssertNil(BarcodeNormalizer.expandUPCE("12345"), "too short for UPC-E")
        XCTAssertNil(BarcodeNormalizer.expandUPCE("92345678"), "number system must be 0 or 1")
    }

    func testCheckDigit() {
        XCTAssertEqual(BarcodeNormalizer.upcCheckDigit("04210000526"), "4")
    }
}

// MARK: - Date → ISO day string

final class ISODateStringTests: XCTestCase {

    private let newYork = TimeZone(identifier: "America/New_York")!
    private let tokyo   = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: iso)!
    }

    // The whole point: the day depends on the zone you ask in. The old cached
    // DateFormatter froze TimeZone.current at first use, so after a timezone change the
    // app kept writing log_date in the old zone while isToday had already moved.
    func testDayDependsOnTimeZone() {
        let instant = date("2024-03-16T03:30:00Z")   // Mar 15, 11:30pm EDT / Mar 16, 12:30pm JST
        XCTAssertEqual(instant.isoDateString(in: newYork), "2024-03-15")
        XCTAssertEqual(instant.isoDateString(in: tokyo),   "2024-03-16")
    }

    func testZeroPadsMonthAndDay() {
        XCTAssertEqual(date("2024-01-05T12:00:00Z").isoDateString(in: .gmt), "2024-01-05")
    }

    // Zero-padded ISO strings are compared lexicographically in LocalStore.fetchGoal and
    // pruneDeletedFoodLogs. That only holds if every component is fixed-width.
    func testLexicographicOrderingMatchesChronology() {
        let earlier = date("2024-09-30T12:00:00Z").isoDateString(in: .gmt)
        let later   = date("2024-10-01T12:00:00Z").isoDateString(in: .gmt)
        XCTAssertTrue(earlier < later)
        XCTAssertEqual(earlier, "2024-09-30")
        XCTAssertEqual(later,   "2024-10-01")
    }

    // Anything that parses a log_date must read it back in the zone it was written in. The
    // body-fat chart parsed it as UTC midnight and plotted a day earlier than the calories and
    // weight charts built from the same log.
    func testISODateStringRoundTripsInTheSameZone() throws {
        for zone in [newYork, tokyo, TimeZone.gmt] {
            let original = try XCTUnwrap(Date.fromISODateString("2026-07-06", in: zone))
            XCTAssertEqual(original.isoDateString(in: zone), "2026-07-06")
        }
    }

    func testParsingAsUTCWouldShiftTheDayWestOfUTC() throws {
        // The old code did `logDate + "T00:00:00Z"`.
        let asUTC = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-06T00:00:00Z"))
        XCTAssertEqual(asUTC.isoDateString(in: newYork), "2026-07-05", "this is the bug")

        let parsedLocally = try XCTUnwrap(Date.fromISODateString("2026-07-06", in: newYork))
        XCTAssertEqual(parsedLocally.isoDateString(in: newYork), "2026-07-06", "this is the fix")
    }

    func testRejectsMalformedDateStrings() {
        XCTAssertNil(Date.fromISODateString("not-a-date"))
        XCTAssertNil(Date.fromISODateString("2026-07"))
    }

    func testMidnightBoundaryBelongsToTheNewDay() {
        XCTAssertEqual(date("2024-03-15T04:00:00Z").isoDateString(in: newYork), "2024-03-15",
                       "00:00 EDT is still the 15th")
        XCTAssertEqual(date("2024-03-15T03:59:59Z").isoDateString(in: newYork), "2024-03-14",
                       "one second earlier is the 14th")
    }
}

// MARK: - Goal calculation

final class GoalCalculatorTests: XCTestCase {

    // Mifflin-St Jeor. These must not drift: the extraction out of OnboardingViewModel has to
    // be behaviour-preserving.
    func testMifflinStJeorMatchesTheFormula() {
        // 10(80) + 6.25(180) − 5(30) + 5 = 800 + 1125 − 150 + 5
        XCTAssertEqual(
            GoalCalculator.bmr(sex: .male, ageYears: 30, heightCm: 180, weightKg: 80),
            1780, accuracy: 0.001
        )
        // ...− 161
        XCTAssertEqual(
            GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 180, weightKg: 80),
            1614, accuracy: 0.001
        )
    }

    // `.other` is the average of the male and female formulas, as the original code computed it.
    func testOtherSexAveragesTheTwoFormulas() {
        let male   = GoalCalculator.bmr(sex: .male,   ageYears: 30, heightCm: 180, weightKg: 80)
        let female = GoalCalculator.bmr(sex: .female, ageYears: 30, heightCm: 180, weightKg: 80)
        XCTAssertEqual(
            GoalCalculator.bmr(sex: .other, ageYears: 30, heightCm: 180, weightKg: 80),
            (male + female) / 2, accuracy: 0.001
        )
    }

    // An aggressive deficit must never recommend a starvation target.
    func testCalorieFloorClampsAggressiveDeficits() {
        let goals = GoalCalculator.goals(
            sex: .female, ageYears: 60, heightCm: 150, weightKg: 45,
            activity: .sedentary, weightGoal: .lose
        )
        XCTAssertEqual(goals.calories, GoalCalculator.calorieFloor)
        XCTAssertGreaterThan(goals.calories, 0, "never negative")
    }

    func testMacroSplitAndMinimums() {
        let goals = GoalCalculator.macros(calories: 2000, weightKg: 80)
        XCTAssertEqual(goals.proteinG, 150)   // 30% / 4
        XCTAssertEqual(goals.carbsG,   200)   // 40% / 4
        XCTAssertEqual(goals.fatG,      67)   // 30% / 9, rounded
        XCTAssertEqual(goals.fiberG,    28)   // 14g per 1000 kcal
        XCTAssertEqual(goals.waterMlTarget, 2800)  // 35 ml/kg
    }

    func testFiberAndWaterMinimums() {
        let goals = GoalCalculator.macros(calories: 1200, weightKg: 45)
        XCTAssertEqual(goals.fiberG, 25, "floor, not 16.8")
        XCTAssertEqual(goals.waterMlTarget, 2000, "floor, not 1575")
    }

    // Retargeting must preserve the user's current adjustment — the deficit they chose, or a
    // target they hand-tuned — rather than re-deriving from a WeightGoal profiles doesn't store.
    func testRetargetPreservesTheUsersDeficit() {
        // Living 500 kcal under maintenance; maintenance drops by 200 after weight loss.
        let goals = GoalCalculator.retargeted(
            currentCalories: 2000, oldTDEE: 2500, newTDEE: 2300, newWeightKg: 80
        )
        XCTAssertEqual(goals.calories, 1800, "the 500 kcal deficit follows the new TDEE")
    }

    func testRetargetPreservesAManualSurplus() {
        let goals = GoalCalculator.retargeted(
            currentCalories: 2750, oldTDEE: 2500, newTDEE: 2600, newWeightKg: 90
        )
        XCTAssertEqual(goals.calories, 2850, "the +250 surplus is kept")
    }

    func testRetargetRespectsTheFloor() {
        let goals = GoalCalculator.retargeted(
            currentCalories: 1300, oldTDEE: 1800, newTDEE: 1500, newWeightKg: 50
        )
        XCTAssertEqual(goals.calories, GoalCalculator.calorieFloor)
    }
}

// MARK: - Height unit conversion

final class HeightConversionTests: XCTestCase {

    private let imperial = UnitSystem.imperial

    // 172 cm is 67.7 inches. Truncating gave 67 → displayed 5'7" → saved back 170.18 cm.
    func testTotalInchesRoundsRatherThanTruncates() {
        XCTAssertEqual(UnitSystem.totalInches(fromCm: 172), 68)
        XCTAssertEqual(imperial.feetFrom(172), 5)
        XCTAssertEqual(imperial.inchesFrom(172), 8)
    }

    // Flooring the feet and separately rounding the remainder produced "5 ft 12 in".
    func testNeverProducesTwelveInches() {
        for cm in stride(from: 120.0, through: 220.0, by: 0.25) {
            let inches = imperial.inchesFrom(cm)
            XCTAssertTrue((0...11).contains(Int(inches)), "\(cm) cm produced \(inches) inches")
        }
        XCTAssertEqual(imperial.feetFrom(182), 6, "182 cm is 6 ft 0 in, not 5 ft 12 in")
        XCTAssertEqual(imperial.inchesFrom(182), 0)
    }

    func testFormatHeightRounds() {
        XCTAssertEqual(imperial.formatHeight(172), "5'8\"")
        XCTAssertEqual(imperial.formatHeight(170), "5'7\"")
    }

    // Opening Edit Stats and tapping Save without touching anything must not change height.
    // cm → ft/in → cm is lossy (whole inches only), so the conversion has to be skipped.
    func testUnchangedImperialHeightRoundTripsExactly() {
        for storedCm in [170.0, 172.0, 175.3, 182.0, 160.9] {
            let feet   = imperial.feetFrom(storedCm)
            let inches = imperial.inchesFrom(storedCm)
            let saved  = imperial.cmFrom(feet: feet, inches: inches, unchangedFrom: storedCm)
            XCTAssertEqual(saved, storedCm, "reopening and saving rewrote \(storedCm) cm")
        }
    }

    // A real edit still converts.
    func testEditedImperialHeightConverts() {
        let saved = imperial.cmFrom(feet: 6, inches: 0, unchangedFrom: 172)
        XCTAssertEqual(saved, 182.88, accuracy: 0.001)
    }
}

// MARK: - GLP-1 decoding

final class GLP1LogDecodingTests: XCTestCase {

    // site and next_due_at are nullable columns. Decoding them as non-optional threw a
    // DecodingError for the entire array on a single NULL row, blanking the GLP-1 card and
    // the titration chart — one bad row took out the whole feature.
    func testDecodesRowWithNullSiteAndNextDue() throws {
        let json = """
        [
          {"id":"\(UUID().uuidString)","user_id":"\(UUID().uuidString)",
           "injected_at":"2026-07-01T12:00:00Z","medication":"Mounjaro","dose_mg":12.5,
           "site":null,"next_due_at":null},
          {"id":"\(UUID().uuidString)","user_id":"\(UUID().uuidString)",
           "injected_at":"2026-07-08T12:00:00Z","medication":"Mounjaro","dose_mg":12.5,
           "site":"Left Thigh","next_due_at":"2026-07-15T12:00:00Z"}
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let logs = try decoder.decode([GLP1Log].self, from: json)

        XCTAssertEqual(logs.count, 2, "one NULL row must not take the rest down with it")
        XCTAssertNil(logs[0].site)
        XCTAssertNil(logs[0].nextDueAt)
        XCTAssertEqual(logs[1].site, "Left Thigh")
        XCTAssertNotNil(logs[1].nextDueAt)
    }
}

// MARK: - Ring closure semantics

final class RingClosureTests: XCTestCase {

    // 1800 kcal, 135g protein, 180g carbs, 30g fiber
    private let goal = DailyGoal(
        id: UUID(), userId: UUID(), effectiveDate: "2026-07-07",
        calories: 1800, proteinG: 135, carbsG: 180, fatG: 60, fiberG: 30, waterMlTarget: 2000
    )

    private func closed(_ cal: Double, _ pro: Double = 140, _ carb: Double = 170, _ fib: Double = 32) -> Bool {
        goal.ringsClosed(calories: cal, proteinG: pro, carbsG: carb, fiberG: fib)
    }

    func testHittingTheTargetCloses() {
        XCTAssertTrue(closed(1750))
        XCTAssertTrue(closed(1800), "exactly on the calorie goal")
        XCTAssertTrue(closed(1620), "the 90% band floor")
    }

    // The bug: calories and carbs are ceilings, but both the haptic and CelebrationEngine
    // tested `>=`, so a 3200-calorie day earned a success haptic and a compliment from Pulse.
    func testOvereatingDoesNotClose() {
        XCTAssertFalse(closed(3200))
        XCTAssertFalse(closed(1801), "one calorie over the ceiling")
    }

    func testUndereatingDoesNotClose() {
        XCTAssertFalse(closed(900))
        XCTAssertFalse(closed(1619), "just under the 90% band floor")
    }

    func testCarbCeilingIsNotAFloor() {
        XCTAssertFalse(closed(1750, 140, 181, 32), "carbs one gram over the ceiling")
        XCTAssertTrue(closed(1750, 140, 100, 32), "well under the carb ceiling is fine")
    }

    func testProteinAndFiberAreFloors() {
        XCTAssertFalse(closed(1750, 134, 170, 32), "protein under the floor")
        XCTAssertFalse(closed(1750, 140, 170, 29), "fiber under the floor")
        XCTAssertTrue(closed(1750, 300, 170, 90), "way over the floors is still a win")
    }

    // A zero calorie goal is corrupt data, not a day where every ring is trivially closed.
    func testZeroGoalNeverCloses() {
        let zeroGoal = DailyGoal(
            id: UUID(), userId: UUID(), effectiveDate: "2026-07-07",
            calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0, waterMlTarget: 2000
        )
        XCTAssertFalse(zeroGoal.ringsClosed(calories: 0, proteinG: 0, carbsG: 0, fiberG: 0))
    }

    // The Today haptic and Pulse's recentWins must never disagree — that was the whole bug.
    func testCelebrationEngineAgreesWithRingsClosed() {
        let overate = DailySummary(date: .now, calories: 3200, proteinG: 140, carbsG: 170, fatG: 60, fiberG: 32)
        let wins = CelebrationEngine.detectWins(goal: goal, history: [overate])
        XCTAssertFalse(
            wins.contains { $0.contains("Closed every ring") },
            "Pulse must not congratulate a 3200-calorie day on an 1800-calorie goal"
        )
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

    // MARK: Pull reconciliation

    private func remoteLog(id: UUID, meal: Meal, quantity: Double, logDate: String = "2026-07-07") -> FoodLog {
        FoodLog(
            id: id, userId: userId, loggedAt: Date(), logDate: logDate, meal: meal,
            foodItemId: UUID(), quantity: quantity,
            caloriesSnapshot: 100, proteinGSnapshot: 2, carbsGSnapshot: 20,
            fatGSnapshot: 1, fiberGSnapshot: 1,
            foodItems: FoodItemSummary(name: "Rice", brand: nil, servingDesc: nil)
        )
    }

    // The pull applied quantity and macros but never `meal`, so moving an item from lunch
    // to dinner on another device never reached this one.
    func testPullAppliesMealChange() throws {
        let id = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)
        XCTAssertEqual(try XCTUnwrap(row(id)).meal, "lunch")

        try LocalStore.shared.upsertFoodLog(from: remoteLog(id: id, meal: .dinner, quantity: 1))

        XCTAssertEqual(try XCTUnwrap(row(id)).meal, "dinner")
    }

    // A log deleted on another device used to live here forever — phantom calories in
    // Today's totals that disagreed with Analytics.
    func testPruneRemovesRowsTheServerNoLongerHas() throws {
        let kept = try insertLog()
        let deletedRemotely = try insertLog()
        for id in [kept, deletedRemotely] {
            try LocalStore.shared.markFoodLogCreated(id: id, pushedRevision: try XCTUnwrap(row(id)).revision)
        }

        try LocalStore.shared.pruneDeletedFoodLogs(
            userId: userId, since: "2026-07-01", remoteIds: [kept]
        )

        XCTAssertNotNil(try row(kept))
        XCTAssertNil(try row(deletedRemotely))
    }

    // Pruning must never touch rows with local changes still waiting to be pushed.
    func testPruneSparesUnsyncedRows() throws {
        let pendingCreate = try insertLog()

        let pendingUpdate = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: pendingUpdate, pushedRevision: try XCTUnwrap(row(pendingUpdate)).revision)
        try LocalStore.shared.updateFoodLog(id: pendingUpdate, meal: "dinner", quantity: 2)

        let pendingDelete = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: pendingDelete, pushedRevision: try XCTUnwrap(row(pendingDelete)).revision)
        try LocalStore.shared.markFoodLogDeleted(id: pendingDelete)

        // Server returned none of them.
        try LocalStore.shared.pruneDeletedFoodLogs(userId: userId, since: "2026-07-01", remoteIds: [])

        XCTAssertNotNil(try row(pendingCreate), "never pushed — pruning it would lose the log")
        XCTAssertNotNil(try row(pendingUpdate), "edit not yet pushed")
        XCTAssertNotNil(try row(pendingDelete), "tombstone still needs to reach the server")
    }

    func testPruneIgnoresRowsOutsideTheWindowAndOtherUsers() throws {
        let old = try insertLog()
        try LocalStore.shared.markFoodLogCreated(id: old, pushedRevision: try XCTUnwrap(row(old)).revision)

        // Window starts after this row's logDate ("2026-07-07").
        try LocalStore.shared.pruneDeletedFoodLogs(userId: userId, since: "2026-07-08", remoteIds: [])
        XCTAssertNotNil(try row(old), "outside the pulled window — the server was never asked about it")

        try LocalStore.shared.pruneDeletedFoodLogs(userId: UUID(), since: "2026-07-01", remoteIds: [])
        XCTAssertNotNil(try row(old), "belongs to a different user")
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

// MARK: - Sleep interval merging

// HealthKitManager.mergedDuration is the fix for a real double-count: an Apple Watch and a
// sleep app (AutoSleep, Oura, Whoop) each write their own "asleep" samples for the same
// night, so summing every sample reported ~14h for a 7h night. It must count any covered
// stretch once, regardless of overlap or input order. Pure and nonisolated, so it tests
// without touching HealthKit.
final class SleepMergeTests: XCTestCase {

    // A fixed reference instant; offsets are in hours for readability.
    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private func h(_ hours: Double) -> Date { base.addingTimeInterval(hours * 3600) }
    private func interval(_ start: Double, _ end: Double) -> (start: Date, end: Date) {
        (start: h(start), end: h(end))
    }

    func testEmptyIsZero() {
        XCTAssertEqual(HealthKitManager.mergedDuration(of: []), 0)
    }

    func testSingleInterval() {
        XCTAssertEqual(HealthKitManager.mergedDuration(of: [interval(0, 7)]), 7 * 3600, accuracy: 0.001)
    }

    // Two non-overlapping stretches (woke up, fell back asleep) sum.
    func testDisjointIntervalsSum() {
        let d = HealthKitManager.mergedDuration(of: [interval(0, 3), interval(4, 7)])
        XCTAssertEqual(d, 6 * 3600, accuracy: 0.001)
    }

    // The bug this guards: two sources logging the SAME 7h night must not become 14h.
    func testIdenticalOverlapCountsOnce() {
        let watch = interval(0, 7)
        let sleepApp = interval(0, 7)
        XCTAssertEqual(HealthKitManager.mergedDuration(of: [watch, sleepApp]), 7 * 3600, accuracy: 0.001)
    }

    // 0–5 and 4–9 overlap on 4–5; the union is 0–9.
    func testPartialOverlapMerges() {
        let d = HealthKitManager.mergedDuration(of: [interval(0, 5), interval(4, 9)])
        XCTAssertEqual(d, 9 * 3600, accuracy: 0.001)
    }

    // An interval fully inside another contributes nothing extra.
    func testNestedIntervalAbsorbed() {
        let d = HealthKitManager.mergedDuration(of: [interval(0, 8), interval(2, 5)])
        XCTAssertEqual(d, 8 * 3600, accuracy: 0.001)
    }

    // Touching (end == next start) is one continuous stretch, not a gap.
    func testAdjacentIntervalsJoin() {
        let d = HealthKitManager.mergedDuration(of: [interval(0, 3), interval(3, 7)])
        XCTAssertEqual(d, 7 * 3600, accuracy: 0.001)
    }

    // HealthKit returns samples in no guaranteed order; the merge must sort first.
    func testUnsortedInputIsMerged() {
        let d = HealthKitManager.mergedDuration(of: [interval(4, 9), interval(0, 5)])
        XCTAssertEqual(d, 9 * 3600, accuracy: 0.001)
    }

    // Zero- and negative-length intervals are dropped, never counted or crashed on.
    func testDegenerateIntervalsIgnored() {
        let d = HealthKitManager.mergedDuration(of: [interval(2, 2), interval(5, 4), interval(0, 6)])
        XCTAssertEqual(d, 6 * 3600, accuracy: 0.001)
    }
}

// MARK: - Age from date of birth

// GoalCalculator.ageYears feeds Mifflin-St Jeor. dateComponents(.year) floors to completed
// years, which is the intent. Passing `now` keeps these deterministic.
final class AgeFromDOBTests: XCTestCase {

    private let cal = Calendar.current
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testExactBirthdayCountsTheFullYear() {
        XCTAssertEqual(
            GoalCalculator.ageYears(fromDOB: date(1990, 6, 15), now: date(2020, 6, 15)),
            30
        )
    }

    // The day before the birthday they are still 29 — completed years only.
    func testDayBeforeBirthdayIsStillYounger() {
        XCTAssertEqual(
            GoalCalculator.ageYears(fromDOB: date(1990, 6, 15), now: date(2020, 6, 14)),
            29
        )
    }

    // A DOB under a year old is age 0 — NOT the 30 fallback (age-0 DOB was a real onboarding bug).
    func testUnderOneYearIsZeroNotFallback() {
        XCTAssertEqual(
            GoalCalculator.ageYears(fromDOB: date(2020, 1, 1), now: date(2020, 8, 1)),
            0
        )
    }

    // A leap-day birthday resolves without throwing and floors correctly.
    func testLeapDayBirthday() {
        XCTAssertEqual(
            GoalCalculator.ageYears(fromDOB: date(2000, 2, 29), now: date(2020, 3, 1)),
            20
        )
    }
}

// MARK: - HealthKit weight auto-import decision

// TodayViewModel.shouldImportHKWeight gates whether a HealthKit weight sample becomes a new
// weight_logs row. Getting it wrong produced real duplicates: back-imported old readings, a
// write→read→re-import echo of the app's own writes, and a second row when two loads raced.
// The three guards form a simple truth table, tested here in isolation.
final class HKWeightImportTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var yesterday: Date { now.addingTimeInterval(-24 * 3600) }

    private func decide(sampleDate: Date, isFromThisApp: Bool, alreadySyncedToday: Bool) -> Bool {
        TodayViewModel.shouldImportHKWeight(
            sampleDate: sampleDate,
            isFromThisApp: isFromThisApp,
            alreadySyncedToday: alreadySyncedToday,
            now: now
        )
    }

    // Today's reading, from another source, first import of the day → import it.
    func testTodaysExternalSampleImports() {
        XCTAssertTrue(decide(sampleDate: now, isFromThisApp: false, alreadySyncedToday: false))
    }

    // An older reading is never back-imported, even if everything else allows it.
    func testYesterdaysSampleIsNotImported() {
        XCTAssertFalse(decide(sampleDate: yesterday, isFromThisApp: false, alreadySyncedToday: false))
    }

    // The app's own write, read straight back, must not become a second row (echo loop).
    func testOwnWriteIsNotReimported() {
        XCTAssertFalse(decide(sampleDate: now, isFromThisApp: true, alreadySyncedToday: false))
    }

    // Once-per-day guard: a second load the same day doesn't import again.
    func testAlreadySyncedTodayBlocksSecondImport() {
        XCTAssertFalse(decide(sampleDate: now, isFromThisApp: false, alreadySyncedToday: true))
    }

    // A same-day sample counts even a minute before midnight — the guard is calendar-day, not 24h.
    func testLateNightSampleStillCountsAsToday() {
        let cal = Calendar.current
        let almostMidnight = cal.date(bySettingHour: 23, minute: 59, second: 0, of: now)!
        XCTAssertTrue(TodayViewModel.shouldImportHKWeight(
            sampleDate: almostMidnight, isFromThisApp: false, alreadySyncedToday: false, now: now
        ))
    }
}
