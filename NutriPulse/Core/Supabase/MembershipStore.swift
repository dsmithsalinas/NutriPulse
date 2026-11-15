import Foundation
import Observation
import StoreKit
import Supabase

struct MembershipSnapshot: Decodable {
    let userId: UUID
    let enforced: Bool
    let premiumExpiresAt: String?
    let founderExpiresAt: String?
    let subscriptionExpiresAt: String?
    let founderAvailable: Bool
    let founderClaimed: Bool
    let pulseUsed: Int
    let foodUsed: Int
    let pulseLimit: Int
    let foodLimit: Int
    enum CodingKeys: String, CodingKey {
        case userId = "user_id", enforced, premiumExpiresAt = "premium_expires_at"
        case founderExpiresAt = "founder_expires_at", subscriptionExpiresAt = "subscription_expires_at"
        case founderAvailable = "founder_available", founderClaimed = "founder_claimed"
        case pulseUsed = "pulse_used", foodUsed = "food_used", pulseLimit = "pulse_limit", foodLimit = "food_limit"
    }
    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    var premiumUntil: Date? { Self.date(premiumExpiresAt) }
    var founderUntil: Date? { Self.date(founderExpiresAt) }
    var subscribedUntil: Date? { Self.date(subscriptionExpiresAt) }
    func hasPremium(at now: Date) -> Bool { premiumUntil.map { $0 > now } ?? false }
}

@MainActor protocol MembershipRepositoryProtocol {
    func request(action: String, transactionId: String?, environment: String?) async throws -> MembershipSnapshot
}
struct MembershipRepository: MembershipRepositoryProtocol {
    func request(action: String, transactionId: String? = nil, environment: String? = nil) async throws -> MembershipSnapshot {
        struct Request: Encodable { let action: String; let transactionId: String?; let environment: String? }
        return try await supabase.functions.invoke("membership", options: .init(body: Request(action: action, transactionId: transactionId, environment: environment)))
    }
}

enum MembershipAccessError: LocalizedError {
    case required, wrongAccount, pending, unavailable
    var errorDescription: String? {
        switch self {
        case .required: "Choose founding access or a subscription to use Pulse and AI food logging."
        case .wrongAccount: "This purchase belongs to another Footing account. Sign in to that account, or contact support if it was deleted."
        case .pending: "Your purchase is awaiting approval. Premium will unlock after Apple confirms it."
        case .unavailable: "Couldn’t verify premium access. Try again when you’re connected."
        }
    }
}

// No persisted entitlement boolean. Every account starts unknown, late responses are
// discarded, and only the server can grant access. StoreKit verification alone is
// insufficient because the AI endpoints also need a current server entitlement.
@Observable @MainActor final class MembershipStore {
    static let shared = MembershipStore()
    static let productId = "com.dustin.nutripulse.premium.monthly"
    private(set) var accountId: UUID?
    private(set) var snapshot: MembershipSnapshot?
    private(set) var product: Product?
    private(set) var isBusy = false
    private(set) var isRefreshing = false
    var errorMessage: String?
    var notice: String?
    private(set) var pendingPurchaseIntent = false
    private var generation = UUID()
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var intents: Task<Void, Never>?
    private let repository: any MembershipRepositoryProtocol
    private let currentUser: () -> UUID?

    init(repository: (any MembershipRepositoryProtocol)? = nil,
         currentUser: @escaping () -> UUID? = { supabase.auth.currentSession?.user.id }) {
        self.repository = repository ?? MembershipRepository()
        self.currentUser = currentUser
    }
    var hasPremium: Bool { accountId != nil && currentUser() == accountId && snapshot?.hasPremium(at: .now) == true }
    var canUseAI: Bool { accountId != nil && currentUser() == accountId && (snapshot?.enforced == false || hasPremium) }

    func setAccount(_ owner: UUID?) {
        guard owner != accountId else { return }
        accountId = owner; generation = UUID(); snapshot = nil; errorMessage = nil; notice = nil
        // A purchase may still be in flight. Don't unlock its controls until it completes.
    }
    func startListening() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                do { try await self.sync(result) }
                catch { self.errorMessage = error.localizedDescription }
            }
        }
        intents = Task { [weak self] in
            for await intent in PurchaseIntent.intents {
                guard let self else { return }
                guard intent.product.id == Self.productId else { continue }
                // Wait for Footing sign-in and an explicit purchase/claim choice.
                // Never buy automatically in response to an outside-app intent.
                self.product = intent.product
                self.pendingPurchaseIntent = true
            }
        }
    }
    func consumePurchaseIntent() { pendingPurchaseIntent = false }
    func refresh() async {
        setAccount(currentUser())
        guard let owner = accountId else { return }
        let request = generation
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let value = try await repository.request(action: "status", transactionId: nil, environment: nil)
            try accept(value, owner: owner, request: request)
            errorMessage = nil
        } catch {
            guard accountId == owner, generation == request else { return }
            snapshot = nil
            errorMessage = EdgeFunctionError.message(from: error, fallback: "Couldn’t load your membership. Try again when you’re connected.")
        }
    }
    func ensureAccess() async -> Bool {
        let owner = currentUser()
        await refresh()
        return owner != nil && owner == currentUser() && owner == accountId && canUseAI
    }
    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productId]).first(where: {
                $0.type == .autoRenewable && $0.subscription?.subscriptionPeriod.unit == .month && $0.subscription?.subscriptionPeriod.value == 1
            })
            if product == nil { notice = "Subscriptions aren’t available from the App Store right now. Free tracking is still available." }
        } catch { notice = "Couldn’t load the App Store price. Try again shortly." }
    }
    func claim() async {
        guard !isBusy, let owner = accountId, currentUser() == owner else { return }
        let request = generation
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            let value = try await repository.request(action: "claim", transactionId: nil, environment: nil)
            try accept(value, owner: owner, request: request)
            notice = "Your three free months are ready. No payment was started."
        } catch { if generation == request { errorMessage = EdgeFunctionError.message(from: error, fallback: "Couldn’t claim founding access. Try again.") } }
    }
    func purchase() async {
        guard !isBusy, let product, let owner = accountId, currentUser() == owner else { return }
        let request = generation
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            await refresh()
            guard generation == request, currentUser() == owner, snapshot?.enforced == true else {
                if generation == request { notice = "Subscriptions aren’t available yet. Free tracking is still available." }
                return
            }
            // A founding member shouldn't start billing during the free period.
            guard !hasPremium else { return }
            try await completePurchase(try await product.purchase(options: [.appAccountToken(owner)]), owner: owner, request: request)
        } catch { if generation == request { errorMessage = EdgeFunctionError.message(from: error, fallback: error.localizedDescription) } }
    }
    func completePurchase(_ result: Product.PurchaseResult, owner: UUID, request: UUID? = nil) async throws {
        let stamp = request ?? generation
        guard currentUser() == owner, accountId == owner, stamp == generation else { throw MembershipAccessError.wrongAccount }
        switch result {
        case .success(let result): try await sync(result, expectedOwner: owner, request: stamp)
        case .pending: notice = MembershipAccessError.pending.localizedDescription
        case .userCancelled: break
        @unknown default: throw MembershipAccessError.unavailable
        }
    }
    func restore() async {
        guard !isBusy, let owner = accountId, currentUser() == owner else { return }
        let request = generation
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            var found = false
            for await result in StoreKit.Transaction.currentEntitlements {
                guard case .verified(let tx) = result, tx.productID == Self.productId else { continue }
                try await sync(result, expectedOwner: owner, request: request); found = true
            }
            guard generation == request, currentUser() == owner else { return }
            await refresh()
            notice = found ? "Your purchases have been restored." : "No current subscription was found for this Apple Account."
        } catch { if generation == request { errorMessage = EdgeFunctionError.message(from: error, fallback: error.localizedDescription) } }
    }
    func sync(_ result: VerificationResult<StoreKit.Transaction>, expectedOwner: UUID? = nil, request: UUID? = nil) async throws {
        guard case .verified(let tx) = result else { throw MembershipAccessError.unavailable }
        guard tx.productID == Self.productId else { return }
        guard let owner = expectedOwner ?? currentUser(), owner == currentUser(), owner == accountId,
              tx.appAccountToken == owner else { throw MembershipAccessError.wrongAccount }
        let stamp = request ?? generation
        let value = try await repository.request(action: "sync", transactionId: String(tx.id), environment: tx.environment.rawValue)
        try accept(value, owner: owner, request: stamp)
        // Finish only after the server accepts ownership and current Apple status.
        // An interrupted sync is delivered again through Transaction.updates/unfinished.
        await tx.finish()
    }
    func retryUnfinishedPurchases() async {
        for await result in StoreKit.Transaction.unfinished {
            guard case .verified(let tx) = result, tx.productID == Self.productId,
                  tx.appAccountToken == currentUser() else { continue }
            do { try await sync(result) } catch { /* Retain unfinished for the next retry. */ }
        }
    }
    private func accept(_ value: MembershipSnapshot, owner: UUID, request: UUID) throws {
        guard owner == accountId, owner == currentUser(), generation == request, value.userId == owner else { throw MembershipAccessError.wrongAccount }
        snapshot = value
    }

    #if DEBUG
    static func preview(founder: Bool) -> MembershipStore {
        let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let store = MembershipStore(currentUser: { owner })
        store.setAccount(owner)
        store.snapshot = MembershipSnapshot(userId: owner, enforced: true,
            premiumExpiresAt: founder ? "2099-01-01T00:00:00Z" : nil,
            founderExpiresAt: founder ? "2099-01-01T00:00:00Z" : nil,
            subscriptionExpiresAt: nil, founderAvailable: true, founderClaimed: founder,
            pulseUsed: 3, foodUsed: 7, pulseLimit: 60, foodLimit: 60)
        return store
    }
    #endif
}
