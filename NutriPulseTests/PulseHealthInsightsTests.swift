import XCTest
@testable import Footing

@MainActor
final class PulseHealthInsightsTests: XCTestCase {
    func testLateAccountAResponseCannotPopulateAccountB() async throws {
        let a = UUID(), b = UUID()
        var session: UUID? = a
        let started = expectation(description: "Account A read started")
        var pending: CheckedContinuation<PulseHealthInsightsSnapshot, Error>?
        let model = PulseHealthInsightsModel(sessionOwner: { session }, read: { owner, _ in
            if owner == a {
                return try await withCheckedThrowingContinuation { continuation in pending = continuation; started.fulfill() }
            }
            return .init(weekly: [.init(id: "b", text: "Account B")])
        })
        model.configure(owner: a)
        let first = Task { await model.load() }
        await fulfillment(of: [started], timeout: 2)
        session = b; model.configure(owner: b)
        await model.load()
        pending?.resume(returning: .init(weekly: [.init(id: "a", text: "Account A")], experimentDays: [.init(day: "2026-10-01", value: 9)]))
        await first.value
        XCTAssertEqual(model.owner, b)
        XCTAssertEqual(model.weekly.map(\.id), ["b"])
        XCTAssertTrue(model.experimentDays.isEmpty)
        XCTAssertTrue(model.loaded)
    }
    func testNoReadWithoutMatchingSessionAndAccountScopedCache() async {
        let a = UUID(), b = UUID()
        var session: UUID?
        var reads = 0
        let model = PulseHealthInsightsModel(sessionOwner: { session }, read: { owner, _ in
            reads += 1
            return .init(weekly: [.init(id: owner.uuidString, text: "Recorded observations")])
        })
        model.configure(owner: a)
        await model.load()
        XCTAssertEqual(reads, 0)
        session = a; await model.load(); await model.load()
        XCTAssertEqual(reads, 1)
        session = b; model.configure(owner: b)
        XCTAssertTrue(model.weekly.isEmpty)
        await model.load()
        XCTAssertEqual(reads, 2)
        XCTAssertEqual(model.weekly.first?.id, b.uuidString)
        session = nil; model.configure(owner: nil)
        XCTAssertFalse(model.loaded)
        XCTAssertTrue(model.weekly.isEmpty)
    }
}
