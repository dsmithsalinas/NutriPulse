import Foundation
import Observation
import Supabase

struct PulseProfileRepository {
    func fetch() async throws -> PulseProfile? {
        let userId = try await supabase.auth.session.user.id
        let rows: [PulseProfile] = try await supabase.from("pulse_profiles").select()
            .eq("user_id", value: userId).limit(1).execute().value
        return rows.first
    }

    /// Upserts only the given columns, so saving preferences never touches the settings and the
    /// reverse. The row is created on first write with the table's defaults for the rest.
    func upsert(_ fields: [String: AnyJSON]) async throws -> PulseProfile {
        let userId = try await supabase.auth.session.user.id
        var row = fields
        row["user_id"] = .string(userId.uuidString)
        row["updated_at"] = .string(Date.now.ISO8601Format())
        return try await supabase.from("pulse_profiles").upsert(row, onConflict: "user_id")
            .select().single().execute().value
    }
}

// The one place the app reads and writes what Pulse knows and the Pulse settings. Settings are
// cached on the device, so the tab bar and Today can decide at launch, before (or without) the
// network; the server copy wins once loaded. A missing row means the defaults: Pulse on, on
// Today, no consent yet, nothing known.
@Observable
@MainActor
final class PulseProfileStore {
    static let shared = PulseProfileStore()

    private(set) var preferences = PulsePreferences()
    private(set) var pulseEnabled: Bool
    private(set) var pulseOnToday: Bool
    private(set) var aiConsentAt: Date?
    private(set) var isLoaded = false
    /// The last load or save failed; views can offer a retry. Settings keep their cached values.
    private(set) var loadFailed = false

    /// Pulse is available: turned on and agreed to. Everything that sends data to the AI checks this.
    var pulseActive: Bool { pulseEnabled && aiConsentAt != nil }
    /// Consent hasn't been asked yet (or was declined and Pulse left on), so the consent sheet is due.
    var needsConsent: Bool { pulseEnabled && aiConsentAt == nil }

    private let repo = PulseProfileRepository()
    private let defaults: UserDefaults

    private enum Key {
        static let enabled = "pulse.enabled", onToday = "pulse.onToday", consent = "pulse.aiConsentAt"
        static let pending = "pulse.pendingPreferences"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pulseEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        pulseOnToday = defaults.object(forKey: Key.onToday) as? Bool ?? true
        aiConsentAt = defaults.object(forKey: Key.consent) as? Date
    }

    func load() async {
        #if DEBUG
        if CoachViewModel.isPreview { isLoaded = true; return }
        #endif
        do {
            apply(try await repo.fetch())
            loadFailed = false
            await flushPendingPreferences()
        } catch {
            loadFailed = true
        }
        isLoaded = true
    }

    /// For saves the user shouldn't have to redo (onboarding): if the save fails, the preferences
    /// wait on the device and are merged into what the server holds on the next successful load.
    /// Allergies in particular must never silently disappear.
    func savePreferencesOrQueue(_ new: PulsePreferences) async {
        do {
            try await savePreferences(new)
        } catch {
            let queued = pendingPreferences.map { $0.merged(with: new) } ?? new.normalized
            if let data = try? JSONEncoder().encode(queued) { defaults.set(data, forKey: Key.pending) }
        }
    }

    private var pendingPreferences: PulsePreferences? {
        defaults.data(forKey: Key.pending).flatMap { try? JSONDecoder().decode(PulsePreferences.self, from: $0) }
    }

    private func flushPendingPreferences() async {
        guard let pending = pendingPreferences else { return }
        do {
            try await savePreferences(preferences.merged(with: pending))
            defaults.removeObject(forKey: Key.pending)
        } catch {
            // Still offline or failing: keep it for the next load.
        }
    }

    func savePreferences(_ new: PulsePreferences) async throws {
        let value = new.normalized
        let saved = try await repo.upsert([
            "allergies": .array(value.allergies.map { .string($0) }),
            "allergy_note": .string(value.allergyNote),
            "eating_patterns": .array(value.eatingPatterns.map(\.rawValue).sorted().map { .string($0) }),
            "loves": .array(value.loves.map { .string($0) }),
            "avoids": .array(value.avoids.map { .string($0) }),
        ])
        apply(saved)
        NotificationCenter.default.post(name: .pulseProfileChanged, object: nil)
    }

    /// Adds one thing Pulse heard in chat, after the user tapped Save.
    func remember(_ suggestion: PulseRememberSuggestion) async throws {
        var next = preferences
        switch suggestion.kind {
        case .allergy: next.allergies.append(suggestion.value)
        case .avoid: next.avoids.append(suggestion.value)
        case .love: next.loves.append(suggestion.value)
        }
        try await savePreferences(next)
    }

    func setPulseEnabled(_ on: Bool) async throws { try await saveSetting("pulse_enabled", on) }
    func setPulseOnToday(_ on: Bool) async throws { try await saveSetting("pulse_on_today", on) }

    /// The consent sheet's answer. Declining turns Pulse off rather than leaving it half-on.
    func recordConsent(agreed: Bool) async throws {
        if agreed {
            let saved = try await repo.upsert(["ai_consent_at": .string(Date.now.ISO8601Format()), "pulse_enabled": .bool(true)])
            apply(saved)
        } else {
            try await saveSetting("pulse_enabled", false)
        }
        NotificationCenter.default.post(name: .pulseProfileChanged, object: nil)
    }

    private func saveSetting(_ column: String, _ value: Bool) async throws {
        // Optimistic: the switch moves at once; a failed save puts it back.
        let before = (pulseEnabled, pulseOnToday)
        if column == "pulse_enabled" { pulseEnabled = value } else { pulseOnToday = value }
        cacheSettings()
        do {
            apply(try await repo.upsert([column: .bool(value)]))
            NotificationCenter.default.post(name: .pulseProfileChanged, object: nil)
        } catch {
            (pulseEnabled, pulseOnToday) = before
            cacheSettings()
            throw error
        }
    }

    private func apply(_ profile: PulseProfile?) {
        preferences = profile?.preferences ?? PulsePreferences()
        pulseEnabled = profile?.pulseEnabled ?? true
        pulseOnToday = profile?.pulseOnToday ?? true
        aiConsentAt = profile?.aiConsentAt
        cacheSettings()
    }

    private func cacheSettings() {
        defaults.set(pulseEnabled, forKey: Key.enabled)
        defaults.set(pulseOnToday, forKey: Key.onToday)
        defaults.set(aiConsentAt, forKey: Key.consent)
    }

    #if DEBUG
    /// Preview and test fixtures: set state without the network.
    func setForPreview(preferences: PulsePreferences, enabled: Bool = true, onToday: Bool = true, consentAt: Date? = .now) {
        self.preferences = preferences
        pulseEnabled = enabled
        pulseOnToday = onToday
        aiConsentAt = consentAt
        isLoaded = true
    }
    #endif
}
