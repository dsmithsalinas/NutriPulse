import Foundation
import Observation
import Supabase

@Observable @MainActor
final class BreakfastCheckinStore {
    static let shared = BreakfastCheckinStore()
    private(set) var accountId: UUID?
    private(set) var preference: BreakfastCheckinPreference?
    private(set) var checkins: [BreakfastCheckin] = []
    private(set) var loadFailed = false
    private(set) var isSaving = false
    private var generation = UUID()
    func setAccount(_ id: UUID?) {
        guard id != accountId else { return }
        generation = UUID(); accountId = id; preference = nil; checkins = []; loadFailed = false; isSaving = false
    }
    #if DEBUG
    func preview() {
        accountId = AppStoreScreenshotPreview.sampleUser
        if let meal = UsualMealStore.shared.meals.first {
            preference = .init(userId: accountId!, usualMealId: meal.id)
            checkins = ProcessInfo.processInfo.arguments.contains("--breakfast-saved-preview")
                ? [.init(userId: accountId!, localDay: Date.now.isoDateString, usualMealId: meal.id, name: meal.name)] : []
        }
        loadFailed = false
    }
    #endif
    func load() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pulse-week-preview") { return }
        #endif
        guard let id = accountId, supabase.auth.currentSession?.user.id == id else { return }
        let request = generation
        do {
            async let prefs: [BreakfastCheckinPreference] = supabase.from("breakfast_checkin_preferences").select().eq("user_id", value: id).execute().value
            async let rows: [BreakfastCheckin] = supabase.from("breakfast_checkins").select().eq("user_id", value: id)
                .gte("local_day", value: Calendar.current.date(byAdding: .day, value: -30, to: .now)!.isoDateString).execute().value
            let (p, c) = try await (prefs, rows)
            guard generation == request, accountId == id, supabase.auth.currentSession?.user.id == id, !isSaving else { return }
            preference = p.first { $0.userId == id }; checkins = c.filter { $0.userId == id }; loadFailed = false
        } catch { if generation == request { loadFailed = true } }
    }
    var usualBreakfast: UsualMeal? {
        guard let preference, preference.userId == accountId else { return nil }
        return UsualMealStore.shared.meals.first { $0.id == preference.usualMealId && $0.userId == accountId && $0.meal == .breakfast }
    }
    func enable(_ meal: UsualMeal) async throws {
        guard meal.userId == accountId, meal.meal == .breakfast else { throw URLError(.badServerResponse) }
        try await mutate(owner: meal.userId) {
            let value = BreakfastCheckinPreference(userId: meal.userId, usualMealId: meal.id)
            try await supabase.from("breakfast_checkin_preferences").upsert(value, onConflict: "user_id").execute()
            return { self.preference = value }
        }
    }
    func disable() async throws {
        guard let id = accountId else { throw URLError(.userAuthenticationRequired) }
        try await mutate(owner: id) {
            try await supabase.from("breakfast_checkin_preferences").delete().eq("user_id", value: id).execute()
            return { self.preference = nil }
        }
    }
    func checkIn(_ meal: UsualMeal, on date: Date = .now) async throws {
        guard meal.userId == accountId, meal.meal == .breakfast, preference?.usualMealId == meal.id else { throw URLError(.badServerResponse) }
        let value = BreakfastCheckin(userId: meal.userId, localDay: date.isoDateString, usualMealId: meal.id, name: meal.name)
        try await mutate(owner: meal.userId) {
            // Unique owner/day makes repeated taps idempotent. No FoodLog is created.
            let saved: BreakfastCheckin = try await supabase.from("breakfast_checkins").upsert(value, onConflict: "user_id,local_day")
                .select().single().execute().value
            guard saved.userId == meal.userId else { throw URLError(.badServerResponse) }
            return { self.checkins.removeAll { $0.localDay == saved.localDay }; self.checkins.append(saved) }
        }
    }
    func undo(_ checkin: BreakfastCheckin) async throws {
        try await mutate(owner: checkin.userId) {
            try await supabase.from("breakfast_checkins").delete().eq("id", value: checkin.id).eq("user_id", value: checkin.userId).execute()
            return { self.checkins.removeAll { $0.id == checkin.id } }
        }
    }
    private func mutate(owner: UUID, operation: () async throws -> () -> Void) async throws {
        guard owner == accountId, supabase.auth.currentSession?.user.id == owner, !isSaving else { throw URLError(.userAuthenticationRequired) }
        let request = UUID(); generation = request; isSaving = true
        defer { if generation == request { isSaving = false } }
        let apply = try await operation()
        guard request == generation, accountId == owner, supabase.auth.currentSession?.user.id == owner else { throw URLError(.userAuthenticationRequired) }
        apply(); loadFailed = false
        NotificationCenter.default.post(name: .breakfastCheckinsChanged, object: nil)
    }
}
extension Notification.Name {
    static let breakfastCheckinsChanged = Notification.Name("breakfastCheckinsChanged")
}
