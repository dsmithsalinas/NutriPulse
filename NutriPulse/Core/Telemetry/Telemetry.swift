import Foundation
import TelemetryDeck

// Thin facade over the TelemetryDeck SDK — every call site in the app goes
// through here, never `TelemetryDeck` directly, so signal names/parameters
// stay centralized in TelemetrySignal. No-ops everywhere if no App ID is
// configured (e.g. local dev without a TelemetryDeck project).
@MainActor
enum Telemetry {
    static func initialize() {
        guard let appID = Config.telemetryDeckAppID else { return }
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
    }

    /// Fire once per launch/foreground — the only signal day-1/3/7 retention
    /// and days-logged/week need; TelemetryDeck derives cohorts from its timing.
    static func appOpened() {
        TelemetryDeck.signal(TelemetrySignal.appOpened.rawValue)
    }

    // MARK: - Logging funnel

    /// Call the moment a food-logging surface opens. Fires `logIntentStarted`
    /// immediately (so abandoned attempts still count toward the funnel), and
    /// starts the SDK's native duration tracker that `logConfirmed` below stops
    /// and sends — that's what gives us time-to-log for free.
    static func logIntentStarted(source: LogSource) {
        TelemetryDeck.signal(
            TelemetrySignal.logIntentStarted.rawValue,
            parameters: ["source": source.rawValue]
        )
        TelemetryDeck.startDurationSignal(
            TelemetrySignal.logConfirmed.rawValue,
            parameters: ["source": source.rawValue]
        )
    }

    /// Call the moment a log actually saves. `rowsTotal`/`rowsEdited` are the
    /// confirm-card trust proxy — only meaningful for `source == .talk`; leave
    /// them nil for every other source.
    static func logConfirmed(source: LogSource, rowsTotal: Int? = nil, rowsEdited: Int? = nil) {
        var parameters = ["source": source.rawValue]
        if let rowsTotal  { parameters["rowsTotal"]  = String(rowsTotal) }
        if let rowsEdited { parameters["rowsEdited"] = String(rowsEdited) }
        TelemetryDeck.stopAndSendDurationSignal(
            TelemetrySignal.logConfirmed.rawValue,
            parameters: parameters
        )
    }

    // MARK: - Pulse

    /// A user sent a message to Pulse (not an auto-generated check-in).
    static func coachMessageSent(messageType: String) {
        TelemetryDeck.signal(
            TelemetrySignal.coachMessageSent.rawValue,
            parameters: ["messageType": messageType]
        )
    }

    /// An auto-generated check-in or weekly summary was actually seen.
    static func checkinMessageViewed(messageType: String) {
        TelemetryDeck.signal(
            TelemetrySignal.checkinMessageViewed.rawValue,
            parameters: ["messageType": messageType]
        )
    }

    // MARK: - Feedback

    static func feedbackSubmitted(category: FeedbackCategory) {
        TelemetryDeck.signal(
            TelemetrySignal.feedbackSubmitted.rawValue,
            parameters: ["category": category.rawValue]
        )
    }

    // MARK: - App health

    static func previousSessionCrashed() {
        TelemetryDeck.signal(TelemetrySignal.previousSessionCrashed.rawValue)
    }

    static func localStoreFallback() {
        TelemetryDeck.signal(TelemetrySignal.localStoreFallback.rawValue)
    }
}
