import Foundation

enum OffScriptAction: String, CaseIterable, Identifiable {
    case findSomething, makeEasier, remember
    var id: String { rawValue }
    var title: String {
        switch self {
        case .findSomething: "Help me find something"
        case .makeEasier: "Help me make this easier"
        case .remember: "Just remember what happened"
        }
    }
    var detail: String {
        switch self {
        case .findSomething: "Work with what’s available right now."
        case .makeEasier: "Find one manageable next step."
        case .remember: "Leave a note for today. No advice needed."
        }
    }
    var symbol: String {
        switch self {
        case .findSomething: "sparkle.magnifyingglass"
        case .makeEasier: "leaf"
        case .remember: "square.and.pencil"
        }
    }
    var contextLabel: String { self == .remember ? "What would you like to keep as a note?" : "What’s happening, and what would help?" }

    /// A user-initiated request, never a system instruction or automatic check-in.
    func prompt(context: String) -> String? {
        guard self != .remember, let text = MealNote.validBody(context) else { return nil }
        let request = self == .findSomething
            ? "Help me find a practical option using what is available to me."
            : "Help me make this situation easier with one manageable next step."
        return """
        Today went sideways. \(request)

        Here’s what’s happening:
        \(text)

        Keep this optional and low-pressure. Help with the situation without requiring a food diary, missing entries, or a catch-up plan. Don’t claim to save a note, change tracking settings, or create a lasting memory.
        """
    }
}
