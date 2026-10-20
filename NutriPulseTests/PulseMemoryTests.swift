import XCTest
import Supabase
@testable import Footing

@MainActor
private final class MemoryTestRepository: PulseMemoryRepositoryProtocol {
    var rows: [PulseMemory] = []
    var fails = false
    var delaysFetch = false
    var delaysSave = false
    var fetchWaiter: CheckedContinuation<[PulseMemory], Error>?
    var saveWaiter: CheckedContinuation<Void, Error>?
    func fetch(userId: UUID) async throws -> [PulseMemory] {
        if delaysFetch { return try await withCheckedThrowingContinuation { fetchWaiter = $0 } }
        if fails { throw URLError(.notConnectedToInternet) }
        return rows
    }
    func save(_ memory: PulseMemory) async throws {
        if delaysSave { try await withCheckedThrowingContinuation { saveWaiter = $0 } }
        if fails { throw URLError(.notConnectedToInternet) }
        rows.removeAll { $0.id == memory.id }; rows.append(memory)
    }
    func delete(_ memory: PulseMemory) async throws {
        if fails { throw URLError(.notConnectedToInternet) }
        rows.removeAll { $0.id == memory.id }
    }
}

@MainActor
final class PulseMemoryIsolationTests: XCTestCase {
    func testOnlyApprovedMemoriesPersistAndCanBeEditedOrForgotten() async throws {
        let repo = MemoryTestRepository(), id = UUID()
        let store = PulseMemoryStore(repository: repo); store.setAccount(id)
        XCTAssertTrue(repo.rows.isEmpty) // No model/proposal write.
        try await store.approve("  Familiar breakfasts help while traveling.  ", for: id)
        XCTAssertEqual(store.memories.first?.content, "Familiar breakfasts help while traveling.")
        try await store.approve("FAMILIAR BREAKFASTS HELP WHILE TRAVELING.", for: id)
        XCTAssertEqual(repo.rows.count, 1)
        var edit = try XCTUnwrap(store.memories.first); edit.content = "Keep breakfast simple on busy mornings."
        try await store.save(edit)
        XCTAssertEqual(repo.rows.first?.content, edit.content)
        try await store.forget(edit)
        XCTAssertTrue(store.memories.isEmpty); XCTAssertTrue(repo.rows.isEmpty)
    }
    func testRowsFromOtherAccountsNeverReachMemoryAndSwitchClearsImmediately() async {
        let repo = MemoryTestRepository(), a = UUID(), b = UUID()
        repo.rows = [.init(userId: a, content: "A private memory"), .init(userId: b, content: "B private memory")]
        let store = PulseMemoryStore(repository: repo); store.setAccount(a); await store.load()
        XCTAssertEqual(store.memories.map(\.content), ["A private memory"])
        store.setAccount(b)
        XCTAssertTrue(store.memories.isEmpty); XCTAssertFalse(store.isLoaded)
        await store.load(); XCTAssertEqual(store.memories.map(\.content), ["B private memory"])
        store.setAccount(nil); XCTAssertTrue(store.memories.isEmpty)
    }
    func testApprovalFromAFormerUsersScreenCannotSaveToCurrentAccount() async {
        let repository = MemoryTestRepository(), a = UUID(), b = UUID()
        let store = PulseMemoryStore(repository: repository); store.setAccount(b)
        do { try await store.approve("A private preference", for: a); XCTFail("Old owner must be rejected") } catch { }
        XCTAssertTrue(repository.rows.isEmpty); XCTAssertTrue(store.memories.isEmpty)
    }
    func testLateLoadAfterSwitchAndSwitchBackCannotRestoreOldSessionData() async {
        let repo = MemoryTestRepository(), a = UUID(), b = UUID()
        repo.delaysFetch = true
        let store = PulseMemoryStore(repository: repo); store.setAccount(a)
        let work = Task { await store.load() }
        while repo.fetchWaiter == nil { await Task.yield() }
        store.setAccount(b); store.setAccount(a)
        repo.fetchWaiter?.resume(returning: [.init(userId: a, content: "Stale session memory")])
        await work.value
        XCTAssertTrue(store.memories.isEmpty); XCTAssertFalse(store.isLoaded)
    }
    func testLateApprovalDoesNotPopulateNextAccount() async {
        let repo = MemoryTestRepository(), a = UUID(), b = UUID()
        repo.delaysSave = true
        let store = PulseMemoryStore(repository: repo); store.setAccount(a)
        let work = Task { do { try await store.approve("A memory", for: a); return false } catch { return true } }
        while repo.saveWaiter == nil { await Task.yield() }
        store.setAccount(b); repo.saveWaiter?.resume()
        let rejected = await work.value
        XCTAssertTrue(rejected); XCTAssertTrue(store.memories.isEmpty); XCTAssertEqual(store.accountId, b)
    }
    func testFailedRefreshDropsStaleMemoryAndFailedApprovalDoesNotPretendSaved() async {
        let repo = MemoryTestRepository(), id = UUID()
        let store = PulseMemoryStore(repository: repo); store.setAccount(id)
        repo.rows = [.init(userId: id, content: "Old memory")]; await store.load()
        repo.fails = true; await store.load()
        XCTAssertTrue(store.loadFailed); XCTAssertTrue(store.memories.isEmpty)
        do { try await store.approve("Not saved", for: id); XCTFail("Must fail") } catch { }
        XCTAssertTrue(store.memories.isEmpty)
    }
    func testBlankOversizedAndForeignMemoryCannotBeSaved() async {
        let store = PulseMemoryStore(repository: MemoryTestRepository()), id = UUID(); store.setAccount(id)
        for content in [" \n ", String(repeating: "a", count: 301)] {
            do { try await store.approve(content, for: id); XCTFail("Invalid memory") } catch { }
        }
        do { try await store.save(.init(userId: UUID(), content: "Other owner")); XCTFail("Wrong owner") } catch { }
        XCTAssertTrue(store.memories.isEmpty)
    }
    func testLegacyPulseCacheCannotGrantConsentOrCarryPreferencesToAnotherUser() {
        let name = "PulseProfileIsolation-\(UUID())", a = UUID(), b = UUID()
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "pulse.enabled"); defaults.set(Date.now, forKey: "pulse.aiConsentAt")
        defaults.set(Data("private queued preference".utf8), forKey: "pulse.pendingPreferences")
        let store = PulseProfileStore(defaults: defaults); store.setAccount(a)
        XCTAssertNil(store.aiConsentAt); XCTAssertNil(defaults.object(forKey: "pulse.pendingPreferences"))
        store.setForPreview(preferences: .init(loves: ["User A private favorite"]))
        store.setAccount(b)
        XCTAssertTrue(store.preferences.isEmpty); XCTAssertNil(store.aiConsentAt)
        store.setAccount(nil); XCTAssertFalse(store.pulseActive); XCTAssertTrue(store.preferences.isEmpty)
    }
    func testBreakfastCheckinEncodesNoPortionsOrNutrition() throws {
        let record = BreakfastCheckin(userId: UUID(), localDay: "2026-10-20", usualMealId: UUID(), name: "My usual breakfast")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["id", "user_id", "local_day", "usual_meal_id", "name"]))
        XCTAssertEqual(try JSONDecoder().decode(BreakfastCheckin.self, from: JSONEncoder().encode(record)), record)
    }
}

@MainActor
private final class AttentionTestRepository: PulseAttentionRepositoryProtocol {
    var preference: PulseAttentionPreference?
    var fails = false
    var reservations = 0
    var delayReserve = false
    var waiter: CheckedContinuation<Bool, Error>?
    func fetch(userId: UUID) async throws -> PulseAttentionPreference? {
        if fails { throw URLError(.notConnectedToInternet) }; return preference
    }
    func save(_ value: PulseAttentionPreference) async throws {
        if fails { throw URLError(.notConnectedToInternet) }; preference = value
    }
    func reserve(day: String, token: UUID) async throws -> Bool {
        reservations += 1
        if delayReserve { return try await withCheckedThrowingContinuation { waiter = $0 } }
        return true
    }
}
@MainActor
final class PulseAttentionTests: XCTestCase {
    func testUnknownQuietAndOfflineNeverSpendAllowance() async throws {
        let repo = AttentionTestRepository(), id = UUID(), store = PulseAttentionStore(repository: nil)
        store.setAccount(id); XCTAssertFalse(store.allowsProactive)
        let tested = PulseAttentionStore(repository: repo); tested.setAccount(id); await tested.load()
        XCTAssertTrue(tested.allowsProactive)
        try await tested.setLimit(.quiet)
        XCTAssertFalse(tested.allowsProactive)
        let quiet = await tested.reserve(on: .now, token: UUID()); XCTAssertFalse(quiet); XCTAssertEqual(repo.reservations, 0)
        repo.fails = true; await tested.load(); XCTAssertFalse(tested.allowsProactive)
    }
    func testForeignPreferenceIsRejectedAndAccountSwitchStopsLateReservation() async {
        let repo = AttentionTestRepository(), a = UUID(), b = UUID()
        let store = PulseAttentionStore(repository: repo); store.setAccount(a)
        repo.preference = .init(userId: b, limit: .one); await store.load()
        XCTAssertFalse(store.allowsProactive)
        repo.preference = nil; await store.load(); XCTAssertTrue(store.allowsProactive)
        repo.delayReserve = true
        let work = Task { await store.reserve(on: .now, token: UUID()) }
        while repo.waiter == nil { await Task.yield() }
        store.setAccount(b); repo.waiter?.resume(returning: true)
        let accepted = await work.value; XCTAssertFalse(accepted); XCTAssertFalse(store.allowsProactive)
    }
}

// Opt-in: only runs against two disposable, project-checked fixtures. Never replaces
// a personal session. The HTTP role/adversarial suite runs before this native check.
@MainActor
final class SignedInPulseMemoryTests: XCTestCase {
    private struct Account: Decodable { let userId: UUID; let email: String; let password: String }
    private struct Fixture: Decodable { let projectRef: String; let accounts: [Account] }
    private struct Reply: Decodable { let reply: String }
    private struct Chat: Encodable {
        let message: String
        let messageType = "chat"
        let history: [String] = []
        let context = ["pulseMemoryVersion": 1]
    }
    func testTwoAccountsKeepMemoryAttentionAndBreakfastPrivate() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/footing-memory-e2e")
        let file = root.appendingPathComponent("ios-credentials.json")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("Requires isolated two-account fixtures") }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: file))
        guard fixture.projectRef == "dcabdzuhuixlcgwavtsc", Config.supabaseURL.contains(fixture.projectRef), fixture.accounts.count == 2,
              fixture.accounts.allSatisfy({ $0.email.hasPrefix("footing-memory-e2e-") }) else { XCTFail("Invalid disposable fixtures"); return }
        if let current = (try? await supabase.auth.session)?.user.id, !fixture.accounts.contains(where: { $0.userId == current }) {
            throw XCTSkip("Never replace a personal session")
        }
        let a = fixture.accounts[0], b = fixture.accounts[1]
        let memory = PulseMemoryStore(), attention = PulseAttentionStore(), breakfast = BreakfastCheckinStore(), usuals = UsualMealStore()
        func setAccount(_ id: UUID?) { memory.setAccount(id); attention.setAccount(id); breakfast.setAccount(id); usuals.setAccount(id) }
        func signIn(_ account: Account) async throws {
            let session = try await supabase.auth.signIn(email: account.email, password: account.password)
            XCTAssertEqual(session.user.id, account.userId)
            let restored = try await supabase.auth.session
            XCTAssertEqual(restored.user.id, account.userId)
            setAccount(account.userId)
        }
        var checks: [String] = []
        do {
            try await signIn(a)
            await memory.load(); XCTAssertFalse(memory.loadFailed); XCTAssertTrue(memory.memories.isEmpty)
            try await memory.approve("My simple travel breakfast is banana oatmeal.", for: a.userId)
            var approved = try XCTUnwrap(memory.memories.first)
            let secondDevice = PulseMemoryStore(); secondDevice.setAccount(a.userId); await secondDevice.load()
            XCTAssertEqual(secondDevice.memories.first?.id, approved.id)
            approved.content = "My simple travel breakfast is apple oatmeal."
            try await memory.save(approved); await secondDevice.load()
            XCTAssertEqual(secondDevice.memories.first?.content, approved.content)
            checks.append("native approval and edit persist across independent store instances")

            let food = FoodLog(id: UUID(), userId: a.userId, loggedAt: .now, logDate: Date.now.isoDateString, meal: .breakfast,
                foodItemId: UUID(), quantity: 1, caloriesSnapshot: 250, proteinGSnapshot: 10, carbsGSnapshot: 35,
                fatGSnapshot: 7, fiberGSnapshot: 5, foodItems: .init(name: "Apple oatmeal", brand: nil, servingDesc: "1 bowl"))
            let usual = UsualMeal(userId: a.userId, name: "My usual breakfast", meal: .breakfast, items: [food])
            try await usuals.save(usual); try await breakfast.enable(usual); try await breakfast.checkIn(usual)
            let checkin = try XCTUnwrap(breakfast.checkins.first)
            let foodRows: [FoodLog] = try await supabase.from("food_logs").select().eq("user_id", value: a.userId).execute().value
            XCTAssertTrue(foodRows.isEmpty)
            let breakfastReload = BreakfastCheckinStore(); breakfastReload.setAccount(a.userId); await breakfastReload.load()
            XCTAssertEqual(breakfastReload.checkins.first?.id, checkin.id)
            checks.append("native simple breakfast persists without creating a food log")

            await attention.load(); XCTAssertFalse(attention.loadFailed)
            try await attention.setLimit(.quiet)
            let quietClaim = await attention.reserve(on: .now, token: UUID()); XCTAssertFalse(quietClaim)
            try await attention.setLimit(.one)
            let day = Calendar.current.date(byAdding: .day, value: 3, to: .now)!, token = UUID()
            let first = await attention.reserve(on: day, token: token)
            let retry = await attention.reserve(on: day, token: token)
            let second = await attention.reserve(on: day, token: UUID())
            XCTAssertTrue(first); XCTAssertTrue(retry); XCTAssertFalse(second)
            try await attention.setLimit(.quiet)
            checks.append("native quiet and idempotent daily attention allowance")

            try await supabase.auth.signOut(); setAccount(nil)
            XCTAssertTrue(memory.memories.isEmpty); XCTAssertTrue(breakfast.checkins.isEmpty); XCTAssertNil(breakfast.preference)
            XCTAssertFalse(attention.allowsProactive)
            try await signIn(b); await memory.load(); await breakfast.load(); await attention.load()
            XCTAssertFalse(memory.loadFailed); XCTAssertTrue(memory.memories.isEmpty)
            XCTAssertFalse(breakfast.loadFailed); XCTAssertTrue(breakfast.checkins.isEmpty); XCTAssertNil(breakfast.preference)
            checks.append("sign-out clears native stores; B does not inherit A memory or breakfast")
            do { try await memory.approve("Stale A approval", for: a.userId); XCTFail("Stale approval accepted") } catch { }
            do { try await breakfast.enable(usual); XCTFail("Foreign breakfast accepted") } catch { }
            let foreignRows: [PulseMemory] = try await supabase.from("pulse_memories").select().eq("user_id", value: a.userId).execute().value
            XCTAssertTrue(foreignRows.isEmpty)
            do {
                try await supabase.from("pulse_memories").upsert(PulseMemory(id: approved.id, userId: b.userId, content: "Takeover"), onConflict: "id").execute()
                XCTFail("Foreign memory takeover accepted")
            } catch { }
            checks.append("native stale-owner saves, foreign breakfast and upsert takeover rejected")
            try await memory.approve("My simple travel breakfast is rye toast.", for: b.userId)
            let bClaim = await attention.reserve(on: day, token: UUID()); XCTAssertTrue(bClaim)
            let response: Reply = try await supabase.functions.invoke("coach-chat", options: .init(body: Chat(message: "What exact travel breakfast have I approved for you to remember? Use only my approved memory.")))
            XCTAssertTrue(response.reply.lowercased().contains("rye toast"))
            XCTAssertFalse(response.reply.lowercased().contains("apple oatmeal"))
            checks.append("native authenticated Pulse request recalls B memory only; B has independent allowance")

            try await supabase.auth.signOut(); setAccount(nil)
            try await signIn(a); await memory.load(); await breakfast.load()
            XCTAssertEqual(memory.memories.first?.content, approved.content)
            XCTAssertFalse(memory.memories.contains { $0.content.contains("rye toast") })
            XCTAssertEqual(breakfast.preference?.usualMealId, usual.id)
            XCTAssertEqual(breakfast.checkins.first?.id, checkin.id)
            checks.append("A memory and breakfast return intact after A to B to A")
            try await breakfast.undo(checkin); try await breakfast.disable(); try await usuals.delete(usual)
            try await memory.forget(approved)
            let forgotten = PulseMemoryStore(); forgotten.setAccount(a.userId); await forgotten.load()
            XCTAssertTrue(forgotten.memories.isEmpty)
            let finalRows: [FoodLog] = try await supabase.from("food_logs").select().eq("user_id", value: a.userId).execute().value
            XCTAssertTrue(finalRows.isEmpty)
            checks.append("native undo disable and forget persist without invented food records")
            try await supabase.auth.signOut(); setAccount(nil)
            let report = try JSONSerialization.data(withJSONObject: ["projectRef": fixture.projectRef, "checks": checks, "signedOut": true], options: [.prettyPrinted, .sortedKeys])
            try report.write(to: root.appendingPathComponent("native-results.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            let attachment = XCTAttachment(string: String(decoding: report, as: UTF8.self)); attachment.name = "Two-account memory isolation — disposable fixtures"; attachment.lifetime = .keepAlways; add(attachment)
        } catch {
            try? await supabase.auth.signOut(); setAccount(nil)
            throw error
        }
    }
}
