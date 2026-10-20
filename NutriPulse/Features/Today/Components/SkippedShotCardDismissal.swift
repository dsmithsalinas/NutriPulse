import Foundation

/// Presentation only: one dismissed skip per account. Never changes shot history or reminders.
enum SkippedShotCardDismissal {
    static let storageKey = "skippedShotCardDismissals"

    static func contains(_ skip: GLP1SkippedDose, in stored: String) -> Bool {
        records(stored)[skip.userId.uuidString] == skip.id.uuidString
    }

    static func recording(_ skip: GLP1SkippedDose, in stored: String) -> String {
        var values = records(stored)
        values[skip.userId.uuidString] = skip.id.uuidString
        guard let data = try? JSONEncoder().encode(values), let result = String(data: data, encoding: .utf8) else { return stored }
        return result
    }

    private static func records(_ stored: String) -> [String: String] {
        guard let data = stored.data(using: .utf8),
              let values = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return values
    }
}
