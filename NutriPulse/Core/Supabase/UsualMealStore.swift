import Foundation
import Observation
import Supabase

@Observable @MainActor
final class UsualMealStore {
    static let shared = UsualMealStore()
    private(set) var meals: [UsualMeal] = []
    private(set) var accountId: UUID?
    private(set) var loadFailed = false
    private var revision = UUID()
    private var folder: URL { URL.applicationSupportDirectory.appendingPathComponent("UsualMeals", isDirectory: true) }
    private func file(_ id: UUID) -> URL { folder.appendingPathComponent(id.uuidString + ".json") }
    func setAccount(_ id: UUID?) {
        guard id != accountId else { return }
        revision = UUID(); accountId = id; meals = []; loadFailed = false
        if let id, let data = try? Data(contentsOf: file(id)), let decoded = try? JSONDecoder().decode([UsualMeal].self, from: data) {
            meals = decoded.filter { $0.userId == id && $0.isValid }
        }
    }
    private func cache() throws {
        guard let id = accountId else { return }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var directory = folder; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try JSONEncoder().encode(meals).write(to: file(id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func load() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pulse-week-preview") { return }
        #endif
        guard let id = supabase.auth.currentSession?.user.id else { setAccount(nil); return }
        setAccount(id)
        let request = UUID(); revision = request
        do {
            let remote: [UsualMeal] = try await supabase.from("usual_meals").select().eq("user_id", value: id)
                .order("created_at", ascending: false).execute().value
            guard accountId == id, revision == request, supabase.auth.currentSession?.user.id == id else { return }
            meals = remote.filter { $0.userId == id && $0.isValid }; loadFailed = false
            try cache()
        } catch { if accountId == id, revision == request { loadFailed = true } }
    }
    func save(_ meal: UsualMeal) async throws {
        guard meal.isValid, supabase.auth.currentSession?.user.id == meal.userId else { throw URLError(.badServerResponse) }
        setAccount(meal.userId)
        let request = UUID(); revision = request
        try await supabase.from("usual_meals").upsert(meal, onConflict: "id").execute()
        guard accountId == meal.userId, revision == request, supabase.auth.currentSession?.user.id == meal.userId else { throw URLError(.userAuthenticationRequired) }
        meals.removeAll { $0.id == meal.id }; meals.insert(meal, at: 0); try cache()
    }
    func delete(_ meal: UsualMeal) async throws {
        guard accountId == meal.userId, supabase.auth.currentSession?.user.id == meal.userId else { throw URLError(.userAuthenticationRequired) }
        let request = UUID(); revision = request
        try await supabase.from("usual_meals").delete().eq("id", value: meal.id).eq("user_id", value: meal.userId).execute()
        guard accountId == meal.userId, revision == request, supabase.auth.currentSession?.user.id == meal.userId else { throw URLError(.userAuthenticationRequired) }
        meals.removeAll { $0.id == meal.id }; try cache()
    }
    #if DEBUG
    func preview() {
        let foods = Array(AppStoreScreenshotPreview.todayModel().foodLogs.prefix(2))
        guard let owner = foods.first?.userId else { return }
        accountId = owner
        meals = [UsualMeal(userId: owner, name: "My usual breakfast", meal: .breakfast, items: foods)]
    }
    #endif
    func purgeAccount(_ id: UUID) throws {
        if FileManager.default.fileExists(atPath: file(id).path) { try FileManager.default.removeItem(at: file(id)) }
        if accountId == id { revision = UUID(); meals = [] }
    }
}
