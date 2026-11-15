import XCTest
import StoreKit
import StoreKitTest
@testable import Footing

@MainActor final class MembershipTests: XCTestCase {
    private let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private func value(_ owner: UUID, expires: String? = "2099-01-01T00:00:00+00:00", enforced: Bool = true) throws -> MembershipSnapshot {
        var object: [String: Any] = ["user_id": owner.uuidString, "enforced": enforced, "founder_available": true,
            "founder_claimed": false, "pulse_used": 0, "food_used": 0, "pulse_limit": 60, "food_limit": 60]
        object["premium_expires_at"] = expires
        return try JSONDecoder().decode(MembershipSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func testUnknownAccountIsNotPremiumAndServerExpirationIsHonored() async throws {
        let repo = MembershipFixture(); repo.reply = try value(a)
        let store = MembershipStore(repository: repo, currentUser: { self.a })
        store.setAccount(a); XCTAssertFalse(store.hasPremium)
        await store.refresh(); XCTAssertTrue(store.hasPremium)
        repo.reply = try value(a, expires: "2020-01-01T00:00:00.000+00:00")
        await store.refresh(); XCTAssertFalse(store.hasPremium); XCTAssertFalse(store.canUseAI)
    }
    func testFailureAndForeignRowsFailClosed() async throws {
        let repo = MembershipFixture(); repo.reply = try value(b)
        let store = MembershipStore(repository: repo, currentUser: { self.a })
        await store.refresh(); XCTAssertNil(store.snapshot); XCTAssertFalse(store.canUseAI)
        repo.reply = try value(a); await store.refresh(); XCTAssertTrue(store.hasPremium)
        repo.fails = true; await store.refresh(); XCTAssertFalse(store.hasPremium)
    }
    func testSwitchingAccountDropsOldGrantAndLateClaimCannotGrantNextAccount() async throws {
        var current = a
        let repo = MembershipFixture(); repo.reply = try value(a)
        let store = MembershipStore(repository: repo, currentUser: { current })
        await store.refresh(); XCTAssertTrue(store.hasPremium)
        repo.onRequest = { current = self.b; store.setAccount(self.b) }
        await store.claim()
        XCTAssertEqual(store.accountId,b); XCTAssertNil(store.snapshot); XCTAssertFalse(store.canUseAI)
        XCTAssertFalse(store.isBusy)
    }
    func testRolloutDisabledStillRequiresAnAccountOwnedServerResponse() async throws {
        let repo = MembershipFixture(); repo.reply = try value(a, expires: nil, enforced: false)
        let store = MembershipStore(repository: repo, currentUser: { self.a })
        await store.refresh(); XCTAssertFalse(store.hasPremium); XCTAssertTrue(store.canUseAI)
        store.setAccount(nil); XCTAssertFalse(store.canUseAI)
    }
    func testAccessPreflightRejectsAnAccountSwitchDuringRefresh() async throws {
        var current = a
        let repo = MembershipFixture(); repo.reply = try value(a)
        let store = MembershipStore(repository: repo, currentUser: { current })
        repo.onRequest = { current = self.b; store.setAccount(self.b) }
        let allowed = await store.ensureAccess()
        XCTAssertFalse(allowed)
    }
    func testRepeatedFounderClaimUsesServerExpiryAndNeverStartsAPurchase() async throws {
        let repo = MembershipFixture(); repo.reply = try value(a)
        let store = MembershipStore(repository: repo, currentUser: { self.a })
        store.setAccount(a)
        await store.claim(); await store.claim()
        XCTAssertEqual(repo.actions,["claim","claim"])
        XCTAssertTrue(store.hasPremium)
        XCTAssertEqual(store.notice,"Your three free months are ready. No payment was started.")
    }

    func testLocalStoreKitTransactionSyncRequiresServerAcknowledgement() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FootingPremium", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let repo = MembershipFixture(); repo.reply = try value(a)
        let store = MembershipStore(repository: repo, currentUser: { self.a })
        store.setAccount(a)
        await store.loadProduct()
        let product = try XCTUnwrap(store.product)
        XCTAssertEqual(product.price, Decimal(string: "2.99"))
        XCTAssertEqual(product.subscription?.subscriptionPeriod.unit, .month)
        XCTAssertEqual(product.subscription?.subscriptionPeriod.value, 1)
        let transaction = try await session.buyProduct(identifier: MembershipStore.productId, options: [.appAccountToken(a)])
        repo.fails = true
        do {
            try await store.sync(.verified(transaction))
            XCTFail("Server rejection must not unlock premium")
        } catch { }
        XCTAssertFalse(store.hasPremium)
        var remainsUnfinished = false
        for await result in StoreKit.Transaction.unfinished {
            if case .verified(let tx) = result, tx.id == transaction.id { remainsUnfinished = true }
        }
        XCTAssertTrue(remainsUnfinished)
        repo.fails = false
        try await store.sync(.verified(transaction))
        XCTAssertEqual(repo.actions,["sync","sync"])
        XCTAssertTrue(store.hasPremium)
        var purchase: StoreKit.Transaction?
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.productID == MembershipStore.productId { purchase = tx }
        }
        XCTAssertEqual(purchase?.appAccountToken,a)
        var stillUnfinished = false
        for await result in StoreKit.Transaction.unfinished {
            if case .verified(let tx) = result, tx.id == transaction.id { stillUnfinished = true }
        }
        XCTAssertFalse(stillUnfinished)
    }
    func testCanceledAndPendingPurchasesDoNotGrantAccessOrCallServer() async throws {
        let repo = MembershipFixture()
        let store = MembershipStore(repository: repo, currentUser: { self.a })
        store.setAccount(a)
        try await store.completePurchase(.userCancelled, owner: a)
        XCTAssertFalse(store.hasPremium); XCTAssertNil(store.notice)
        try await store.completePurchase(.pending, owner: a)
        XCTAssertFalse(store.hasPremium); XCTAssertNotNil(store.notice)
        XCTAssertTrue(repo.actions.isEmpty)
    }
}

@MainActor private final class MembershipFixture: MembershipRepositoryProtocol {
    var reply: MembershipSnapshot!
    var fails = false
    var actions: [String] = []
    var onRequest: (() -> Void)?
    func request(action: String, transactionId: String?, environment: String?) async throws -> MembershipSnapshot {
        actions.append(action); onRequest?()
        if fails { throw URLError(.notConnectedToInternet) }
        return reply
    }
}
