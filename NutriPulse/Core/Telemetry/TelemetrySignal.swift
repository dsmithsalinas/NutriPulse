import Foundation

// The full catalog of analytics signals NutriPulse fires — kept in one enum so
// every call site is greppable and no signal name gets typo'd or duplicated.
// Never call TelemetryDeck directly — go through `Telemetry` (Telemetry.swift),
// which wraps every case here. See ENHANCEMENTS.md Phase 1C.
enum TelemetrySignal: String {
    // MARK: Goal 1 — is logging fast enough to sustain the habit?

    /// Once per app launch/foreground. The only signal retention (day 1/3/7,
    /// days-logged/week) needs — TelemetryDeck derives cohorts from its timing.
    case appOpened = "app.opened"

    /// Fired the moment a food-logging surface opens (the "+" button, or a
    /// deep link into it). Parameters: `source` (see `LogSource`). Pairs with
    /// `logConfirmed` to compute time-to-log (intent → confirmed).
    case logIntentStarted = "log.intentStarted"

    /// Fired the moment a food log actually saves — the "logs/day" and
    /// "share of logs by source" metrics both come from this one signal's
    /// volume and `source` parameter. Parameters: `source` (see `LogSource`);
    /// for `source == .talk`, also `rowsTotal` / `rowsEdited` (the confirm-card
    /// trust proxy). Sent via the SDK's duration-tracking pair (started in
    /// `logIntentStarted`), so it carries time-to-log automatically.
    case logConfirmed = "log.confirmed"

    // MARK: Goal 2 — is Pulse valuable enough to justify its cost?

    /// A user sent a message to Pulse (not an auto-generated check-in).
    /// Parameters: `messageType` ("chat" | "checkin" | "weekly_summary").
    case coachMessageSent = "coach.messageSent"

    /// An auto-generated check-in or weekly summary was actually seen, not
    /// just silently sitting unread in the Coach tab. Parameters: `messageType`.
    case checkinMessageViewed = "coach.checkinViewed"

    // MARK: Feedback

    /// The "Send Feedback" form was submitted. The message body itself goes to
    /// Supabase (`feedback` table), not TelemetryDeck — this signal is only for
    /// tracking submission rate. Parameters: `category` (bug | idea | general).
    case feedbackSubmitted = "feedback.submitted"
}

// Parameter values for `TelemetrySignal.logIntentStarted` / `.logConfirmed`'s
// `source` field — mirrors the app's actual logging entry points.
enum LogSource: String {
    case talk
    case manual
    case search
    case scan
    case favorite
}
