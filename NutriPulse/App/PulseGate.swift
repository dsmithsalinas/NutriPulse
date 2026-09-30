import Foundation

// Pure decisions about what Pulse is allowed to do, given just the settings PulseProfileStore
// caches on device (pulseEnabled, pulseOnToday, aiConsentAt). Kept free of Supabase, Observation,
// or SwiftUI so tab visibility, consent timing, and hand-off gating can be unit tested without a
// signed-in session or a running app.
enum PulseGate {
    /// What should happen when something tries to hand a prompt to Pulse — a Today nudge, a
    /// Goals question, the GLP-1 tracker's "Ask Pulse about today", or a retry after consent.
    enum Handoff: Equatable {
        /// Send it: Pulse is on and the user has agreed to the AI data sharing.
        case allowed
        /// Pulse is on but hasn't been asked yet (or was declined earlier and turned back on
        /// without re-confirming) — hold the prompt and show the consent sheet.
        case needsConsent
        /// Pulse is off. Drop the prompt; nothing should reach the AI provider.
        case blocked
    }

    static func handoff(pulseEnabled: Bool, aiConsentAt: Date?) -> Handoff {
        guard pulseEnabled else { return .blocked }
        return aiConsentAt == nil ? .needsConsent : .allowed
    }

    /// Pulse is fully available: on and consented. Everything that sends data to the AI
    /// provider — Pulse chat, the written Strong Week outlook — checks this before it calls out.
    static func isActive(pulseEnabled: Bool, aiConsentAt: Date?) -> Bool {
        handoff(pulseEnabled: pulseEnabled, aiConsentAt: aiConsentAt) == .allowed
    }

    /// The tab bar shows the Pulse tab whenever Pulse is turned on — needing consent doesn't
    /// hide the tab, it's what shows the consent sheet once the user lands there.
    static func showsPulseTab(pulseEnabled: Bool) -> Bool { pulseEnabled }

    /// Whether Today's Pulse-branded nudge strip (UnderEatingNudgeCard, LowAppetitePreparationCard)
    /// is allowed to show at all.
    static func showsPulseStripOnToday(pulseOnToday: Bool) -> Bool { pulseOnToday }
}
