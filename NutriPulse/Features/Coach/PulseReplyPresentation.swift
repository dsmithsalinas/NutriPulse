import Foundation

// Pure, unit-tested logic behind rendering a structured Pulse reply (docs/daylight-redesign.md):
// resolving a suggested food name to something the user can actually log again, and deciding
// which chips sit above the composer. Kept free of Supabase/LocalStore/SwiftUI so both can be
// tested without a device, network, or view hierarchy.

/// Resolves a food name Pulse suggested to the user's own recently logged food, so a food card
/// can log it again in one tap. Pulse is instructed to spell suggestions exactly as they appear
/// in the user's log (pulse-context.ts's `foods` schema), but matching is still case-insensitive
/// and trimmed rather than exact — a stray space or capitalization difference shouldn't silently
/// hide a card the user would otherwise see.
enum PulseFoodResolver {
    /// The most recently logged food (by `loggedAt`) whose display name matches `name`,
    /// case-insensitively and trimmed. `logs` is normally the user's last 30 days of local food
    /// logs; a name with no match returns nil, and the caller hides the card rather than
    /// showing one that can't be logged.
    static func resolve(_ name: String, in logs: [FoodLog]) -> FoodLog? {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !target.isEmpty else { return nil }
        return logs
            .filter { $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target }
            .max { $0.loggedAt < $1.loggedAt }
    }
}

/// Picks what shows in the chip strip above the composer: the newest message's own follow-ups
/// when it's an assistant reply that has them, otherwise the device-built `suggestedPrompts`
/// that were already there before structured replies existed.
enum PulseChipSource {
    static func chips(latestMessage: CoachMessage?, fallback: [String]) -> [String] {
        guard let latestMessage, !latestMessage.isUser,
              let followUps = latestMessage.payload?.followUps, !followUps.isEmpty
        else {
            return fallback
        }
        return followUps
    }
}
