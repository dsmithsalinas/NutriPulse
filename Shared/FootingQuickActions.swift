import AppIntents
import Foundation

enum FootingQuickAction: String, AppEnum, Codable {
    case addWater
    case talkToLog
    case logFavorite
    case logDose

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Footing action")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .addWater: "Add water",
        .talkToLog: "Talk to Log",
        .logFavorite: "Log a favorite",
        .logDose: "Log dose",
    ]
}

enum QuickActionStore {
    private static let key = "pendingFootingQuickAction"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: SharedConfig.appGroup) }

    static func enqueue(_ action: FootingQuickAction) {
        defaults?.set(action.rawValue, forKey: key)
    }

    static func consume() -> FootingQuickAction? {
        guard let raw = defaults?.string(forKey: key), let action = FootingQuickAction(rawValue: raw) else { return nil }
        defaults?.removeObject(forKey: key)
        return action
    }
}

struct FootingQuickActionIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick action in Footing"
    static let description = IntentDescription("Open Footing and complete a common logging action.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Action") var action: FootingQuickAction

    init() {}
    init(action: FootingQuickAction) { self.action = action }

    func perform() async throws -> some IntentResult {
        QuickActionStore.enqueue(action)
        return .result()
    }
}
