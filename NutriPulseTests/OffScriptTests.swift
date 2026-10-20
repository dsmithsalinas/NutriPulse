import XCTest
import Supabase
@testable import Footing

final class OffScriptRequestTests: XCTestCase {
    func testThreePracticalExitsStayInOrder() {
        XCTAssertEqual(OffScriptAction.allCases.map(\.title), ["Help me find something", "Help me make this easier", "Just remember what happened"])
    }
    func testHelpUsesOnlyThePersonsContextAndDoesNotDemandDiaryCompletion() throws {
        let context = "  At the airport, ten minutes before boarding.  "
        for action in [OffScriptAction.findSomething, .makeEasier] {
            let prompt = try XCTUnwrap(action.prompt(context: context))
            XCTAssertTrue(prompt.contains("At the airport, ten minutes before boarding."))
            XCTAssertTrue(prompt.contains("without requiring a food diary"))
            XCTAssertTrue(prompt.contains("Don’t claim to save a note"))
        }
        XCTAssertNotEqual(OffScriptAction.findSomething.prompt(context: context), OffScriptAction.makeEasier.prompt(context: context))
        XCTAssertNil(OffScriptAction.remember.prompt(context: context))
    }
    func testEmptyAndOversizedHelpDoesNotCreateARequest() {
        for action in OffScriptAction.allCases {
            XCTAssertNil(action.prompt(context: " \n\t "))
            XCTAssertNil(action.prompt(context: String(repeating: "a", count: 1001)))
        }
    }
    func testOldNoteWithoutKindStillDecodesAsMealNote() throws {
        let id = UUID(), owner = UUID()
        let data = try JSONSerialization.data(withJSONObject: ["id": id.uuidString, "user_id": owner.uuidString,
            "log_date": "2026-10-19", "meal": "lunch", "body": "Lunch out"])
        let note = try JSONDecoder().decode(MealNote.self, from: data)
        XCTAssertFalse(note.isDayContext); XCTAssertEqual(note.contextMeal, "lunch")
        XCTAssertEqual(note.displayTitle, "Lunch · Meal note")
    }
    func testDayNotesKeepTheirMeaningWithoutAddingNutritionOrApprovedMemoryFields() throws {
        let note = MealNote(userId: UUID(), logDate: "2026-10-19", meal: .snack, body: "Travel changed the day", kind: .dayContext)
        let encoded = try JSONEncoder().encode(note)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["kind"] as? String, "day_context")
        XCTAssertEqual(Set(json.keys), Set(["id", "user_id", "log_date", "meal", "body", "kind"]))
        let decoded = try JSONDecoder().decode(MealNote.self, from: encoded)
        XCTAssertEqual(decoded, note); XCTAssertEqual(decoded.displayTitle, "Day note")
        XCTAssertEqual(decoded.contextMeal, "day_context")
    }
}

@MainActor
private final class OffScriptNoteTransport: MealNoteTransport {
    var notes: [MealNote] = []
    func fetch(for date: Date) async throws -> [MealNote] { notes.filter { $0.logDate == date.isoDateString } }
    func save(_ note: MealNote) async throws { notes.removeAll { $0.id == note.id }; notes.append(note) }
    func delete(_ note: MealNote) async throws { notes.removeAll { $0.id == note.id } }
}
@MainActor
final class OffScriptNoteTests: XCTestCase {
    func testOfflineDayNoteSurvivesRestartEditAccountSwitchSyncAndUndo() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let owner = UUID(), transport = OffScriptNoteTransport()
        let store = MealNoteStore(folder: folder, transport: transport); store.setAccount(owner)
        var note = MealNote(userId: owner, logDate: Date.now.isoDateString, meal: .snack, body: "The day changed", kind: .dayContext)
        try store.save(note)
        let restart = MealNoteStore(folder: folder, transport: transport); restart.setAccount(owner)
        XCTAssertEqual(try restart.cachedOnly(for: .now).first?.kind, .dayContext)
        restart.setAccount(UUID()); XCTAssertTrue(restart.cached(for: .now).isEmpty)
        XCTAssertThrowsError(try restart.save(note))
        restart.setAccount(owner)
        note.body = "The train was delayed. Kept things simple."; try restart.save(note)
        let synced = await restart.sync(); XCTAssertTrue(synced)
        XCTAssertEqual(transport.notes.first?.kind, .dayContext)
        XCTAssertEqual(transport.notes.first?.body, note.body)
        try restart.delete(note)
        XCTAssertTrue(restart.cached(for: .now).isEmpty)
        let deleted = await restart.sync(); XCTAssertTrue(deleted); XCTAssertTrue(transport.notes.isEmpty)
    }
    func testPulseHandoffKeepsConsentAndOffControls() {
        let profile = PulseProfileStore.shared, original = profile.preferences
        let enabled = profile.pulseEnabled, onToday = profile.pulseOnToday, consent = profile.aiConsentAt
        defer { profile.setForPreview(preferences: original, enabled: enabled, onToday: onToday, consentAt: consent) }
        let prompt = OffScriptAction.makeEasier.prompt(context: "A busy afternoon")!
        profile.setForPreview(preferences: .init(), enabled: true, consentAt: nil)
        let needsConsent = AppState(); needsConsent.askPulse(prompt)
        XCTAssertNil(needsConsent.pendingCoachPrompt); XCTAssertEqual(needsConsent.pendingConsentPrompt, prompt)
        XCTAssertTrue(needsConsent.showPulseConsentSheet)
        profile.setForPreview(preferences: .init(), enabled: false)
        let off = AppState(); off.askPulse(prompt); XCTAssertNil(off.pendingCoachPrompt)
        profile.setForPreview(preferences: .init(), enabled: true, consentAt: .now)
        let on = AppState(); on.askPulse(prompt); XCTAssertEqual(on.pendingCoachPrompt, prompt)
    }
}


@MainActor
final class SignedInOffScriptTests: XCTestCase {
    func testDayNoteOfflineSyncEditUndoAndNoAutomaticMemory() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/footing-off-script-e2e")
        let credentials = root.appendingPathComponent("ios-credentials.json")
        guard FileManager.default.fileExists(atPath: credentials.path) else { throw XCTSkip("Requires disposable Off-script fixture") }
        struct Fixture: Decodable { let projectRef: String; let userId: UUID; let email: String; let password: String }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: credentials))
        guard fixture.projectRef == "dcabdzuhuixlcgwavtsc", Config.supabaseURL.contains(fixture.projectRef),
              fixture.email.hasPrefix("footing-off-script-e2e-") else { XCTFail("Invalid fixture"); return }
        if let existing = try? await supabase.auth.session, existing.user.id != fixture.userId { throw XCTSkip("Never replace a personal session") }
        _ = try await supabase.auth.signIn(email: fixture.email, password: fixture.password)
        let session = try await supabase.auth.session; XCTAssertEqual(session.user.id, fixture.userId)
        let store = MealNoteStore.shared; store.setAccount(fixture.userId)
        do {
            SyncEngine.shared.isOnline = false
            var note = MealNote(userId: fixture.userId, logDate: Date.now.isoDateString, meal: .snack,
                                body: "Travel changed the day. No advice needed.", kind: .dayContext)
            try await MealNoteRepository().save(note)
            XCTAssertTrue(store.isPending(note.id))
            let restart = MealNoteStore(); restart.setAccount(fixture.userId)
            XCTAssertEqual(try restart.cachedOnly(for: .now).first?.kind, .dayContext)
            SyncEngine.shared.isOnline = true
            let firstSync = await store.sync(); XCTAssertTrue(firstSync)
            let rows: [MealNote] = try await supabase.from("meal_notes").select().eq("id", value: note.id).execute().value
            XCTAssertEqual(rows.first?.kind, .dayContext); XCTAssertEqual(rows.first?.displayTitle, "Day note")
            note.body = "The train was delayed. Kept things simple."
            try await MealNoteRepository().save(note)
            let edited = await store.sync(); XCTAssertTrue(edited)
            let updated: [MealNote] = try await supabase.from("meal_notes").select().eq("id", value: note.id).execute().value
            XCTAssertEqual(updated.first?.body, note.body); XCTAssertEqual(updated.first?.kind, .dayContext)
            let food: [FoodLog] = try await supabase.from("food_logs").select().eq("user_id", value: fixture.userId).execute().value
            let memories: [PulseMemory] = try await supabase.from("pulse_memories").select().eq("user_id", value: fixture.userId).execute().value
            XCTAssertTrue(food.isEmpty); XCTAssertTrue(memories.isEmpty)
            let undo = FoodSaveUndo(); undo.record(note: note)
            let undone = await undo.undo(); XCTAssertTrue(undone)
            let deleteSync = await store.sync(); XCTAssertTrue(deleteSync)
            let deleted: [MealNote] = try await supabase.from("meal_notes").select().eq("id", value: note.id).execute().value
            XCTAssertTrue(deleted.isEmpty)
            let report = try JSONSerialization.data(withJSONObject: ["offlineRestart":true,"cloudKind":"day_context",
                "editPreservedKind":true,"undoRemovedCloudNote":true,"foodLogs":0,"automaticMemories":0], options: [.prettyPrinted,.sortedKeys])
            try report.write(to: root.appendingPathComponent("native-results.json"), options: .atomic)
            try store.purgeAccount(fixture.userId)
            try await supabase.auth.signOut()
        } catch { SyncEngine.shared.isOnline = true; try? await supabase.auth.signOut(); throw error }
    }
}
