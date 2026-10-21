import XCTest
@testable import Footing

@MainActor
private final class ConsentRepository: FoodAIConsentRepositoryProtocol {
    var row: FoodAIConsent?
    var fails = false
    var delayFetch = false
    var delaySave = false
    var fetchWaiter: CheckedContinuation<FoodAIConsent?, Error>?
    var saveWaiter: CheckedContinuation<FoodAIConsent, Error>?
    var saves = 0
    func fetch(userId: UUID) async throws -> FoodAIConsent? {
        if delayFetch { return try await withCheckedThrowingContinuation { fetchWaiter = $0 } }
        if fails { throw URLError(.notConnectedToInternet) }
        return row
    }
    func save(userId: UUID, agreed: Bool) async throws -> FoodAIConsent {
        saves += 1
        if delaySave { return try await withCheckedThrowingContinuation { saveWaiter = $0 } }
        if fails { throw URLError(.notConnectedToInternet) }
        let saved = FoodAIConsent(userId: userId, agreedAt: agreed ? .now : nil)
        row = saved; return saved
    }
}

@MainActor
final class FoodAIConsentTests: XCTestCase {
    func testNoGrantUntilExplicitSaveAndRevocationClearsIt() async throws {
        let id = UUID(), repo = ConsentRepository()
        let store = FoodAIConsentStore(repository: repo, currentUser: { id }); store.setAccount(id)
        XCTAssertFalse(store.isAllowed)
        await store.load(); XCTAssertFalse(store.isAllowed); XCTAssertEqual(repo.saves, 0)
        try await store.record(agreed: true, for: id); XCTAssertTrue(store.isAllowed)
        try await store.record(agreed: false, for: id); XCTAssertFalse(store.isAllowed); XCTAssertNil(repo.row?.agreedAt)
    }
    func testOfflineLookupNeverReusesPreviousGrant() async throws {
        let id = UUID(), repo = ConsentRepository()
        let store = FoodAIConsentStore(repository: repo, currentUser: { id }); store.setAccount(id)
        try await store.record(agreed: true, for: id)
        repo.fails = true; await store.load()
        XCTAssertFalse(store.isAllowed); XCTAssertTrue(store.loadFailed); XCTAssertNil(store.agreedAt)
    }
    func testForeignRowCannotGrantPermission() async {
        let id = UUID(), repo = ConsentRepository(); repo.row = .init(userId: UUID(), agreedAt: .now)
        let store = FoodAIConsentStore(repository: repo, currentUser: { id }); await store.load()
        XCTAssertFalse(store.isAllowed); XCTAssertTrue(store.loadFailed)
    }
    func testSwitchClearsPermissionAndFormerScreenCannotApproveForNextUser() async throws {
        let a = UUID(), b = UUID(), repo = ConsentRepository(); var current: UUID? = a
        let store = FoodAIConsentStore(repository: repo, currentUser: { current }); store.setAccount(a)
        try await store.record(agreed: true, for: a); current = b; store.setAccount(b)
        XCTAssertFalse(store.isAllowed); XCTAssertNil(store.agreedAt)
        do { try await store.record(agreed: true, for: a); XCTFail("Stale approval") } catch { }
        XCTAssertEqual(repo.saves, 1)
        current = nil; store.setAccount(nil); XCTAssertFalse(store.isAllowed)
    }
    func testLateFetchCannotGrantAfterSwitchAwayAndBack() async {
        let id = UUID(), repo = ConsentRepository(); repo.delayFetch = true
        let store = FoodAIConsentStore(repository: repo, currentUser: { id }); store.setAccount(id)
        let load = Task { await store.load() }
        while repo.fetchWaiter == nil { await Task.yield() }
        store.setAccount(UUID()); store.setAccount(id)
        repo.fetchWaiter?.resume(returning: .init(userId: id, agreedAt: .now))
        await load.value
        XCTAssertFalse(store.isAllowed); XCTAssertFalse(store.isLoaded)
    }
    func testLateSaveDoesNotGrantTheNextAccount() async {
        let a = UUID(), b = UUID(), repo = ConsentRepository(); var current: UUID? = a
        repo.delaySave = true
        let store = FoodAIConsentStore(repository: repo, currentUser: { current }); store.setAccount(a)
        let save = Task { do { try await store.record(agreed: true, for: a); return false } catch { return true } }
        while repo.saveWaiter == nil { await Task.yield() }
        current = b; store.setAccount(b)
        repo.saveWaiter?.resume(returning: .init(userId: a, agreedAt: .now))
        let rejected = await save.value
        XCTAssertTrue(rejected); XCTAssertFalse(store.isAllowed); XCTAssertNil(store.agreedAt)
    }
    func testFailedRevocationBlocksLocalParsingUntilServerCanBeChecked() async throws {
        let id = UUID(), repo = ConsentRepository()
        let store = FoodAIConsentStore(repository: repo, currentUser: { id }); store.setAccount(id)
        try await store.record(agreed: true, for: id); repo.fails = true
        do { try await store.record(agreed: false, for: id); XCTFail("Must report failure") } catch { }
        XCTAssertFalse(store.isAllowed); XCTAssertTrue(store.loadFailed)
    }
    func testRevocationOnAnotherDeviceOverridesPreviousPermission() async throws {
        let id = UUID(), repo = ConsentRepository()
        let store = FoodAIConsentStore(repository: repo, currentUser: { id }); store.setAccount(id)
        try await store.record(agreed: true, for: id)
        repo.row = .init(userId: id, agreedAt: nil)
        await store.load()
        XCTAssertFalse(store.isAllowed); XCTAssertTrue(store.isLoaded); XCTAssertFalse(store.loadFailed)
    }
    func testFailedOptInDoesNotAllowParsing() async {
        let id = UUID(), repo = ConsentRepository(); repo.fails = true
        let store = FoodAIConsentStore(repository: repo, currentUser: { id }); store.setAccount(id)
        do { try await store.record(agreed: true, for: id); XCTFail("Failed save must be surfaced") } catch { }
        XCTAssertFalse(store.isAllowed); XCTAssertNil(store.agreedAt)
    }
}
