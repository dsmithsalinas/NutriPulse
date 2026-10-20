import Foundation

enum LogMethodPreference {
    static func key(_ id: UUID) -> String { "preferredLogMethod.\(id.uuidString)" }
    static func read(userId: UUID?, defaults: UserDefaults = .standard) -> FoodLoggingViewModel.LogTab {
        guard let userId, let raw = defaults.string(forKey: key(userId)),
              let method = FoodLoggingViewModel.LogTab(rawValue: raw) else { return .talk }
        return method
    }
    static func save(_ method: FoodLoggingViewModel.LogTab, userId: UUID?, defaults: UserDefaults = .standard) {
        guard let userId else { return }
        defaults.set(method.rawValue, forKey: key(userId))
    }
}
