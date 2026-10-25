import XCTest
@testable import Footing

final class HealthExperienceTests: XCTestCase {
    private let owner = UUID()
    private let now = Date.fromISODateString("2026-10-24")!
    private func date(_ day: String) -> Date { Date.fromISODateString(day)! }
    private func workout(_ start: Date, _ minutes: Double = 20, slug: String = "walking") -> HealthKitManager.HKWorkoutSummary {
        .init(uuid: UUID().uuidString, activitySlug: slug, startDate: start, durationMinutes: minutes, activeCalories: nil, distanceMeters: nil)
    }
    func testWalkingClipsWindowMergesDuplicatesAndNeverFillsMissing() {
        let start = date("2026-10-23").addingTimeInterval(12 * 3600)
        let link = ExperimentHealthLink(metric: .walking, startHour: 12, endHour: 13)
        let a = workout(start.addingTimeInterval(-600), 30)
        let b = workout(start.addingTimeInterval(600), 20)
        let irrelevant = workout(start, 60, slug: "cycling")
        XCTAssertEqual(ExperimentHealthEvidence.walkingMinutes([a, b, irrelevant], on: start, link: link, now: now), 30)
        XCTAssertNil(ExperimentHealthEvidence.walkingMinutes([], on: start, link: link, now: now))
        XCTAssertNil(ExperimentHealthEvidence.walkingMinutes([irrelevant], on: start, link: link, now: now))
    }
    func testWalkingWindowUsesLocalClockOnDaylightSavingTransition() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
        let start = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        XCTAssertEqual(ExperimentHealthEvidence.walkingMinutes([workout(start, 20)], on: day,
            link: .init(metric: .walking, startHour: 12, endHour: 13), now: start.addingTimeInterval(3600), calendar: calendar), 20)
    }
    func testHealthNeverCreatesConfirmationAndNeedsBothGroups() {
        var experiment = TinyExperiment(action: "Wind down", outcome: "Sleep", startedOn: "2026-10-01", healthOutcome: true, healthLink: .init(metric: .sleep))
        let days = (1...8).map { ExperimentHealthDay(day: String(format: "2026-10-%02d", $0), value: 7) }
        XCTAssertNil(ExperimentHealthEvidence.comparison(experiment: experiment, days: days))
        experiment.observations = days.prefix(3).map { .init(day: $0.day, tried: true, rating: nil) }
        XCTAssertNil(ExperimentHealthEvidence.comparison(experiment: experiment, days: days))
        experiment.observations += days.dropFirst(3).prefix(3).map { .init(day: $0.day, tried: false, rating: nil) }
        let text = ExperimentHealthEvidence.comparison(experiment: experiment, days: days)
        XCTAssertTrue(text?.contains("3 confirmed tried") == true)
        XCTAssertTrue(text?.contains("not evidence") == true)
        XCTAssertTrue(experiment.summary.contains("following-night sleep"))
        XCTAssertFalse(experiment.summary.contains("/5"), "Objective-only observations cannot manufacture subjective ratings.")
    }
    func testOldExperimentsDecodeAndNewLinkRoundTrips() throws {
        let old = TinyExperiment(action: "Walk", outcome: "Energy", startedOn: "2026-10-01")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        object.removeValue(forKey: "healthLink")
        let restored = try JSONDecoder().decode(TinyExperiment.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.healthLink)
        var linked = restored; linked.healthLink = .init(metric: .sleep)
        linked.observations = [.init(day: "2026-10-02", tried: true, rating: nil)]
        XCTAssertEqual(try JSONDecoder().decode(TinyExperiment.self, from: JSONEncoder().encode(linked)), linked)
    }
    func testShortSleepRequiresPersonalPlausibleBaseline() {
        XCTAssertFalse(HealthPatternInsights.shorterSleep(hours: 5, baseline: nil))
        XCTAssertFalse(HealthPatternInsights.shorterSleep(hours: nil, baseline: 8))
        XCTAssertFalse(HealthPatternInsights.shorterSleep(hours: .nan, baseline: 8))
        XCTAssertFalse(HealthPatternInsights.shorterSleep(hours: 7.5, baseline: 8))
        XCTAssertTrue(HealthPatternInsights.shorterSleep(hours: 6, baseline: 8))
    }
    private func report(_ day: String, cycleDay: Int = 1, owner: UUID? = nil) -> ShotCycleCheckIn {
        .init(id: UUID(), userId: owner ?? self.owner, checkinDate: day, cycleDay: cycleDay,
              appetite: 2, fullness: 3, nausea: 1, energy: 2, digestion: 3, note: nil, createdAt: date(day))
    }
    private func shots() -> [GLP1Log] {
        ["2026-09-26", "2026-10-03", "2026-10-10", "2026-10-17"].map {
            let day = date($0)
            return .init(id: UUID(), userId: owner, injectedAt: day, medication: "Example", doseMg: 1, site: nil,
                         nextDueAt: Calendar.current.date(byAdding: .day, value: 7, to: day))
        }
    }
    func testCycleNeedsThreeDistinctCompletedSameRegimenCycles() {
        let reports = ["2026-09-27", "2026-10-04", "2026-10-11"].map { report($0) }
        let logs = shots()
        XCTAssertEqual(HealthPatternInsights.cycle(cycleDay: 1, injections: logs, skips: [], checkIns: reports, days: [], owner: owner, now: now).count, 1)
        XCTAssertTrue(HealthPatternInsights.cycle(cycleDay: 1, injections: logs, skips: [], checkIns: Array(reports.prefix(2)), days: [], owner: owner, now: now).isEmpty)
        XCTAssertTrue(HealthPatternInsights.cycle(cycleDay: 1, injections: logs, skips: [], checkIns: reports, days: [], owner: UUID(), now: now).isEmpty)
        let skip = GLP1SkippedDose(id: UUID(), userId: owner, injectionId: logs[0].id, scheduledAt: date("2026-10-03"), nextReminderAt: date("2026-10-10"), createdAt: now)
        XCTAssertTrue(HealthPatternInsights.cycle(cycleDay: 1, injections: logs, skips: [skip], checkIns: reports, days: [], owner: owner, now: now).isEmpty)
        XCTAssertTrue(HealthPatternInsights.cycle(cycleDay: 8, injections: logs, skips: [], checkIns: reports, days: [], owner: owner, now: now).isEmpty)
    }
    func testDoseChangeAndWrongOwnerReportsCannotEstablishCyclePattern() {
        let logs = shots()
        let reports = ["2026-09-27", "2026-10-04", "2026-10-11"].map { report($0) }
        let changed = logs.dropLast() + [GLP1Log(id: UUID(), userId: owner, injectedAt: logs.last!.injectedAt,
            medication: "Example", doseMg: 2, site: nil, nextDueAt: logs.last!.nextDueAt)]
        XCTAssertTrue(HealthPatternInsights.cycle(cycleDay: 1, injections: Array(changed), skips: [], checkIns: reports, days: [], owner: owner, now: now).isEmpty)
        let other = reports.map { report($0.checkinDate, owner: UUID()) }
        XCTAssertTrue(HealthPatternInsights.cycle(cycleDay: 1, injections: logs, skips: [], checkIns: other, days: [], owner: owner, now: now).isEmpty)
        let currentOnly = [report("2026-10-18"), report("2026-10-18"), report("2026-10-18")]
        XCTAssertTrue(HealthPatternInsights.cycle(cycleDay: 1, injections: logs, skips: [], checkIns: currentOnly, days: [], owner: owner, now: now).isEmpty)
    }
    func testWeeklyReflectionExcludesPartialTodayAndSparseSleep() {
        let today = HealthExperienceDay(day: "2026-10-24", sleep: 8, steps: 99999, workouts: [workout(now, 30, slug: "strength")])
        XCTAssertTrue(HealthPatternInsights.week(days: [today], checkIns: [], now: now).isEmpty)
        let days = ["2026-10-20", "2026-10-21", "2026-10-22"].map { HealthExperienceDay(day: $0, sleep: 7, steps: nil, workouts: []) }
        let lines = HealthPatternInsights.week(days: days, checkIns: [], now: now)
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].text.contains("3/7 nights"))
        XCTAssertTrue(HealthPatternInsights.week(days: Array(days.prefix(2)), checkIns: [], now: now).isEmpty)
    }
}
