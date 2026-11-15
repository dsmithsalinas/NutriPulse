import XCTest
@testable import Footing

final class WidgetSnapshotTests: XCTestCase {
    private func isolated(_ test: (UserDefaults) throws -> Void) rethrows {
        let suite = "WidgetSnapshotTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }
    func testSameAccountRestorationPreservesSnapshot() throws {
        try isolated { defaults in
            let owner = UUID()
            SharedStore.bindAccount(owner, defaults: defaults, reload: false)
            let snapshot = ProteinFloorSnapshot(proteinToday: 94, proteinGoal: 140, updatedAt: .now, showsDose: true)
            SharedStore.save(snapshot, owner: owner, defaults: defaults, reload: false)
            SharedStore.bindAccount(owner, defaults: defaults, reload: false)
            let restored = try XCTUnwrap(SharedStore.load(defaults: defaults))
            XCTAssertEqual(restored.proteinToday, 94)
            XCTAssertEqual(restored.updatedAt, snapshot.updatedAt)
            XCTAssertNotEqual(restored.nutritionUnknown, true)
        }
    }
    func testAccountSwitchAndSignOutClearNumbersAndRejectLateWrites() throws {
        try isolated { defaults in
            let first = UUID(), second = UUID()
            let snapshot = ProteinFloorSnapshot(proteinToday: 94, proteinGoal: 140, updatedAt: .now)
            SharedStore.bindAccount(first, defaults: defaults, reload: false)
            SharedStore.save(snapshot, owner: first, defaults: defaults, reload: false)
            SharedStore.bindAccount(second, defaults: defaults, reload: false)
            SharedStore.save(snapshot, owner: first, defaults: defaults, reload: false)
            XCTAssertEqual(SharedStore.load(defaults: defaults)?.proteinToday, 0)
            XCTAssertEqual(SharedStore.load(defaults: defaults)?.needsRefresh, true)
            SharedStore.save(snapshot, owner: second, defaults: defaults, reload: false)
            SharedStore.bindAccount(nil, defaults: defaults, reload: false)
            SharedStore.save(snapshot, owner: second, defaults: defaults, reload: false)
            XCTAssertEqual(SharedStore.load(defaults: defaults)?.proteinToday, 0)
        }
    }
    func testSourceChangeInvalidatesProteinButKeepsGoalAndActions() throws {
        try isolated { defaults in
            let owner = UUID()
            SharedStore.bindAccount(owner, defaults: defaults, reload: false)
            SharedStore.save(.init(proteinToday: 94, proteinGoal: 140, updatedAt: .now, showsDose: true),
                             owner: owner, defaults: defaults, reload: false)
            SharedStore.invalidateProtein(owner: owner, defaults: defaults, reload: false)
            let pending = try XCTUnwrap(SharedStore.load(defaults: defaults))
            XCTAssertEqual(pending.proteinToday, 0)
            XCTAssertEqual(pending.proteinGoal, 140)
            XCTAssertEqual(pending.showsDose, true)
            XCTAssertEqual(pending.nutritionUnknown, true)
            XCTAssertEqual(pending.needsRefresh, true)
            SharedStore.save(.init(proteinToday: 42, proteinGoal: 140, updatedAt: .now), owner: owner, defaults: defaults, reload: false)
            XCTAssertNotEqual(SharedStore.load(defaults: defaults)?.nutritionUnknown, true)
        }
    }
    func testLegacySnapshotIsNotAttributedToAnUnknownAccount() throws {
        try isolated { defaults in
            let legacy = ProteinFloorSnapshot(proteinToday: 94, proteinGoal: 140, updatedAt: .now)
            defaults.set(try JSONEncoder().encode(legacy), forKey: "proteinFloorSnapshot")
            SharedStore.bindAccount(UUID(), defaults: defaults, reload: false)
            XCTAssertEqual(SharedStore.load(defaults: defaults)?.proteinToday, 0)
        }
    }
}
