import Foundation
import Observation
import Supabase

@MainActor
protocol TrackingPreferencesRepositoryProtocol {
    func fetch(userId: UUID) async throws -> LighterTrackingSetting?
    func save(_ setting: LighterTrackingSetting) async throws -> LighterTrackingSetting
}

@MainActor
struct TrackingPreferencesRepository: TrackingPreferencesRepositoryProtocol {
    func fetch(userId: UUID) async throws -> LighterTrackingSetting? {
        let rows: [LighterTrackingSetting] = try await supabase.from("tracking_preferences")
            .select().eq("user_id", value: userId).limit(1).execute().value
        return rows.first
    }
    func save(_ setting: LighterTrackingSetting) async throws -> LighterTrackingSetting {
        var updated = setting
        updated.updatedAt = .now
        return try await supabase.from("tracking_preferences").upsert(updated, onConflict: "user_id")
            .select().single().execute().value
    }
}

@Observable @MainActor
final class TrackingPreferencesStore {
    static let shared = TrackingPreferencesStore()
    private(set) var setting: LighterTrackingSetting?
    private(set) var isLoaded = false
    private(set) var loadFailed = false
    private(set) var isSaving = false
    private(set) var accountId: UUID?
    private var generation = UUID()
    private var clockRevision = 0
    private var expiryTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let repository: any TrackingPreferencesRepositoryProtocol

    init(defaults: UserDefaults = .standard, repository: (any TrackingPreferencesRepositoryProtocol)? = nil) {
        self.defaults = defaults
        self.repository = repository ?? TrackingPreferencesRepository()
    }
    var isActive: Bool {
        _ = clockRevision
        return setting?.isActive() == true || needsResumeChoice
    }
    var needsResumeChoice: Bool {
        _ = clockRevision
        return setting?.needsResumeChoice() == true
    }
    var contextReason: LighterTrackingSetting.Reason? { needsResumeChoice ? nil : setting?.reason }
    /// Unknown settings pause unsolicited goal prompts until refreshed. Medication is separate.
    var suppressesGoalPrompts: Bool {
        accountId != nil && (!isLoaded || loadFailed || isActive)
    }
    private func key(_ id: UUID) -> String { "lighterTracking.\(id.uuidString)" }

    func setAccount(_ id: UUID?) {
        guard id != accountId else { return }
        if let previous = accountId { defaults.removeObject(forKey: key(previous)) }
        generation = UUID()
        expiryTask?.cancel()
        accountId = id
        setting = id.flatMap { userId in
            defaults.data(forKey: key(userId)).flatMap { try? JSONDecoder().decode(LighterTrackingSetting.self, from: $0) }
        }
        if setting?.userId != id { setting = nil }
        isLoaded = setting != nil
        loadFailed = false
        isSaving = false
        scheduleExpiry()
        changed()
    }

    func load() async {
        guard let id = accountId else { return }
        let request = generation
        do {
            let loaded = try await repository.fetch(userId: id)
            guard accountId == id, generation == request, !isSaving else { return }
            setting = loaded ?? .init(userId: id)
            isLoaded = true
            loadFailed = false
            cache()
        } catch {
            guard accountId == id, generation == request else { return }
            loadFailed = true
        }
        changed()
    }

    func start(reason: LighterTrackingSetting.Reason?, duration: LighterTrackingSetting.Duration) async throws {
        guard let id = accountId else { throw SaveError.signedOut }
        try await save(.start(userId: id, reason: reason, duration: duration))
    }
    func update(reason: LighterTrackingSetting.Reason?, duration: LighterTrackingSetting.Duration?) async throws {
        if isActive, duration == nil, var current = setting {
            current.reason = reason
            try await save(current)
        } else {
            try await start(reason: reason, duration: duration ?? .untilReady)
        }
    }
    func resume() async throws {
        guard let id = accountId else { throw SaveError.signedOut }
        try await save(.init(userId: id))
    }
    private func save(_ value: LighterTrackingSetting) async throws {
        guard !isSaving, accountId == value.userId else { throw SaveError.unavailable }
        let request = UUID()
        generation = request
        isSaving = true
        defer { if generation == request { isSaving = false } }
        let saved = try await repository.save(value)
        guard accountId == value.userId, generation == request, saved.userId == value.userId else {
            throw SaveError.signedOut
        }
        setting = saved
        loadFailed = false
        isLoaded = true
        cache()
        changed()
    }
    func refreshTiming() {
        clockRevision += 1
        changed()
    }
    private func cache() {
        if let id = accountId, let data = try? JSONEncoder().encode(setting) { defaults.set(data, forKey: key(id)) }
        scheduleExpiry()
    }
    private func changed() { NotificationCenter.default.post(name: .trackingModeChanged, object: nil) }
    private func scheduleExpiry() {
        expiryTask?.cancel()
        guard let end = setting?.endsAt, end > .now else { return }
        expiryTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(end.timeIntervalSinceNow)) } catch { return }
            guard let self else { return }
            self.clockRevision += 1
            self.changed()
        }
    }
    enum SaveError: Error { case signedOut, unavailable }

    #if DEBUG
    func preview(reason: LighterTrackingSetting.Reason? = .vacation) {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        accountId = id
        setting = .start(userId: id, reason: reason, duration: .untilReady)
        if ProcessInfo.processInfo.arguments.contains("--lighter-ended-preview") {
            setting?.startedAt = .now.addingTimeInterval(-500)
            setting?.endsAt = .now.addingTimeInterval(-10)
        }
        isLoaded = true
        loadFailed = false
    }
    #endif
}

extension Notification.Name {
    static let trackingModeChanged = Notification.Name("trackingModeChanged")
}
