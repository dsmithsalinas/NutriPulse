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
    func upsert(_ fields: [String: AnyJSON], userId: UUID) async throws -> PulseProfile {
        guard supabase.auth.currentSession?.user.id == userId else { throw URLError(.userAuthenticationRequired) }
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
    private(set) var accountId: UUID?
    private var generation = UUID()
    private func scoped(_ key: String) -> String { "\(key).\(accountId?.uuidString ?? "signed-out")" }

    func setAccount(_ id: UUID?) {
        guard accountId != id else { return }
        generation = UUID(); accountId = id; preferences = PulsePreferences()
        isLoaded = false; loadFailed = false
        // Old shared keys cannot be safely attributed to any account.
        for key in [Key.enabled, Key.onToday, Key.consent, Key.pending] { defaults.removeObject(forKey: key) }
        pulseEnabled = id == nil ? false : defaults.object(forKey: scoped(Key.enabled)) as? Bool ?? true
        pulseOnToday = defaults.object(forKey: scoped(Key.onToday)) as? Bool ?? true
        aiConsentAt = defaults.object(forKey: scoped(Key.consent)) as? Date
    }

    private func owner() throws -> (UUID, UUID) {
        guard let id = supabase.auth.currentSession?.user.id, id == accountId else { throw URLError(.userAuthenticationRequired) }
        return (id, generation)
    }
    private func validate(_ id: UUID, _ request: UUID, saved: PulseProfile? = nil) throws {
        guard accountId == id, generation == request, supabase.auth.currentSession?.user.id == id, saved == nil || saved?.userId == id else { throw URLError(.userAuthenticationRequired) }
    }
    private let defaults: UserDefaults

    private enum Key {
        static let enabled = "pulse.enabled", onToday = "pulse.onToday", consent = "pulse.aiConsentAt"
        static let pending = "pulse.pendingPreferences"
    }

    func purgeAccount(_ id: UUID) {
        for key in [Key.enabled, Key.onToday, Key.consent, Key.pending] {
            defaults.removeObject(forKey: "\(key).\(id.uuidString)")
        }
        if accountId == id { setAccount(nil) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pulseEnabled = false
        pulseOnToday = true
        aiConsentAt = nil
    }

    func load() async {
        #if DEBUG
        if CoachViewModel.isPreview {
            if DebugLaunch.tour {
                setForPreview(preferences: .init(allergies: ["Peanuts"], allergyNote: "", eatingPatterns: [.pescatarian],
                                                 loves: ["Greek yogurt"], avoids: []))
            }
            isLoaded = true
            return
        }
        #endif
        setAccount(supabase.auth.currentSession?.user.id)
        guard let (id, request) = try? owner() else { return }
        do {
            let loaded = try await repo.fetch()
            try validate(id, request, saved: loaded)
            apply(loaded)
            loadFailed = false
            await flushPendingPreferences()
        } catch {
            guard accountId == id, generation == request else { return }
            loadFailed = true
        }
        guard accountId == id, generation == request else { return }
        isLoaded = true
    }

    /// For saves the user shouldn't have to redo (onboarding): if the save fails, the preferences
    /// wait on the device and are merged into what the server holds on the next successful load.
    /// Allergies in particular must never silently disappear.
    func savePreferencesOrQueue(_ new: PulsePreferences) async {
        setAccount(supabase.auth.currentSession?.user.id)
        guard let (id, request) = try? owner() else { return }
        do {
            try await savePreferences(new)
        } catch {
            guard accountId == id, generation == request else { return }
            let queued = pendingPreferences.map { $0.merged(with: new) } ?? new.normalized
            if let data = try? JSONEncoder().encode(queued) { defaults.set(data, forKey: scoped(Key.pending)) }
        }
    }

    private var pendingPreferences: PulsePreferences? {
        defaults.data(forKey: scoped(Key.pending)).flatMap { try? JSONDecoder().decode(PulsePreferences.self, from: $0) }
    }

    private func flushPendingPreferences() async {
        guard let pending = pendingPreferences else { return }
        do {
            try await savePreferences(preferences.merged(with: pending))
            defaults.removeObject(forKey: scoped(Key.pending))
        } catch {
            // Still offline or failing: keep it for the next load.
        }
    }

    func savePreferences(_ new: PulsePreferences) async throws {
        let (id, request) = try owner()
        let value = new.normalized
        let saved = try await repo.upsert([
            "allergies": .array(value.allergies.map { .string($0) }),
            "allergy_note": .string(value.allergyNote),
            "eating_patterns": .array(value.eatingPatterns.map(\.rawValue).sorted().map { .string($0) }),
            "loves": .array(value.loves.map { .string($0) }),
            "avoids": .array(value.avoids.map { .string($0) }),
        ], userId: id)
        try validate(id, request, saved: saved)
        apply(saved)
        NotificationCenter.default.post(name: .pulseProfileChanged, object: nil)
    }

    /// Adds one thing Pulse heard in chat, after the user tapped Save.
    func remember(_ suggestion: PulseRememberSuggestion, for expectedOwner: UUID) async throws {
        guard accountId == expectedOwner, supabase.auth.currentSession?.user.id == expectedOwner else { throw URLError(.userAuthenticationRequired) }
        var next = preferences
        switch suggestion.kind {
        case .allergy: next.allergies.append(suggestion.value)
        case .avoid: next.avoids.append(suggestion.value)
        case .love: next.loves.append(suggestion.value)
        case .helpful:
            try await PulseMemoryStore.shared.approve(suggestion.value, for: expectedOwner)
            return
        }
        try await savePreferences(next)
    }

    func setPulseEnabled(_ on: Bool) async throws { try await saveSetting("pulse_enabled", on) }
    func setPulseOnToday(_ on: Bool) async throws { try await saveSetting("pulse_on_today", on) }

    /// The consent sheet's answer. Declining turns Pulse off rather than leaving it half-on.
    func recordConsent(agreed: Bool) async throws {
        let (id, request) = try owner()
        if agreed {
            let saved = try await repo.upsert(["ai_consent_at": .string(Date.now.ISO8601Format()), "pulse_enabled": .bool(true)], userId: id)
            try validate(id, request, saved: saved)
            apply(saved)
        } else {
            let saved = try await repo.upsert(["ai_consent_at": .null, "pulse_enabled": .bool(false)], userId: id)
            try validate(id, request, saved: saved)
            apply(saved)
        }
        NotificationCenter.default.post(name: .pulseProfileChanged, object: nil)
    }

    /// coach-chat refused because Pulse is off on the server: match it here at once (the tab
    /// backs out, nothing else sends); the change notice reloads the rest from the server.
    func serverReportedPulseOff() {
        pulseEnabled = false
        cacheSettings()
        NotificationCenter.default.post(name: .pulseProfileChanged, object: nil)
    }

    func serverReportedConsentRequired() {
        aiConsentAt = nil
        cacheSettings()
        NotificationCenter.default.post(name: .pulseProfileChanged, object: nil)
    }

    private func saveSetting(_ column: String, _ value: Bool) async throws {
        let (id, request) = try owner()
        // Optimistic: the switch moves at once; a failed save puts it back.
        let before = (pulseEnabled, pulseOnToday)
        if column == "pulse_enabled" { pulseEnabled = value } else { pulseOnToday = value }
        cacheSettings()
        do {
            let saved = try await repo.upsert([column: .bool(value)], userId: id)
            try validate(id, request, saved: saved)
            apply(saved)
            NotificationCenter.default.post(name: .pulseProfileChanged, object: nil)
        } catch {
            guard accountId == id, generation == request else { throw error }
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
        defaults.set(pulseEnabled, forKey: scoped(Key.enabled))
        defaults.set(pulseOnToday, forKey: scoped(Key.onToday))
        defaults.set(aiConsentAt, forKey: scoped(Key.consent))
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
