import Foundation
import Observation

struct MedicationRemoteRecord: Codable, Equatable {
    var user_id: UUID
    var revision: Int
    var write_id: UUID
    var document: MedicationDocument
}

@MainActor
protocol MedicationTransport {
    func fetch(owner: UUID) async throws -> MedicationRemoteRecord?
    func save(owner: UUID, document: MedicationDocument, expectedRevision: Int, writeID: UUID) async throws -> MedicationRemoteRecord
}

/// Atomic account document + durable outbox. A server CAS prevents another device's
/// schedule/status corrections being silently overwritten. No network is needed to log.
@Observable @MainActor
final class MedicationStore {
    static let shared = MedicationStore()
    struct Cache: Codable {
        var document = MedicationDocument()
        var serverRevision = 0
        var writeID = UUID()
        var pending = false
        var conflict: MedicationRemoteRecord?
    }
    private(set) var accountID: UUID?
    private(set) var cache = Cache()
    private(set) var storageFailed = false
    private(set) var syncFailed = false
    private(set) var isSyncing = false
    private(set) var didLoad = false
    private let folder: URL
    private let transport: any MedicationTransport
    private var generation = UUID()
    private var syncGeneration: UUID?
    private let automaticallyReconcile: Bool
    var document: MedicationDocument { cache.document }
    var enabled: Bool { accountID != nil && !storageFailed && cache.document.enabled }
    var pendingCount: Int { cache.pending ? 1 : 0 }
    var hasConflict: Bool { cache.conflict != nil }

    init(folder: URL? = nil, transport: (any MedicationTransport)? = nil, automaticallyReconcile: Bool = true) {
        self.folder = folder ?? URL.applicationSupportDirectory.appendingPathComponent("Medications", isDirectory: true)
        self.transport = transport ?? RemoteMedicationTransport()
        self.automaticallyReconcile = automaticallyReconcile
    }

    private func file(_ owner: UUID) -> URL { folder.appendingPathComponent(owner.uuidString + ".json") }
    func setAccount(_ owner: UUID?) {
        guard accountID != owner else { return }
        generation = UUID(); accountID = owner; cache = Cache()
        storageFailed = false; syncFailed = false; didLoad = false; isSyncing = false
        if let owner, FileManager.default.fileExists(atPath: file(owner).path) {
            do {
                let loaded = try JSONDecoder().decode(Cache.self, from: Data(contentsOf: file(owner)))
                guard loaded.document.isValid else { throw MedicationError.invalid }
                cache = loaded
            }
            catch { storageFailed = true }
        }
        changed()
    }
    private func persist(_ next: Cache) throws {
        guard let owner = accountID, !storageFailed else { throw MedicationError.unavailable }
        guard next.document.isValid else { throw MedicationError.invalid }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var directory = folder
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try JSONEncoder().encode(next).write(to: file(owner), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache = next
    }
    private func mutate(_ update: (inout MedicationDocument) throws -> Void) throws {
        guard !hasConflict else { throw MedicationError.conflict }
        var next = cache
        try update(&next.document)
        next.writeID = UUID(); next.pending = true
        try persist(next)
        changed()
        if automaticallyReconcile {
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
        }
    }
    func setEnabled(_ value: Bool, now: Date = .now) throws {
        guard value != document.enabled else { return }
        try mutate { doc in
            doc.enabled = value
            if value { doc.intervals.append(.init(start: now)) }
            else if let index = doc.intervals.indices.last, doc.intervals[index].end == nil {
                doc.intervals[index].end = max(now, doc.intervals[index].start)
            }
        }
    }
    func saveRoutine(routineID: UUID? = nil, name: String, amount: String, weekdays: Set<Int>,
                     times: [MedicationTime], applyToday: Bool = false, now: Date = .now) throws {
        guard MedicationCalendar.valid(name: name, amount: amount, weekdays: weekdays, times: times) else { throw MedicationError.invalid }
        let calendar = MedicationCalendar.calendar
        let starts = routineID == nil || applyToday ? now : calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let id = routineID ?? UUID()
        try mutate { doc in
            // Discard a not-yet-started replacement before replacing it again.
            doc.schedules.removeAll { $0.routineID == id && $0.startsAt >= starts }
            for index in doc.schedules.indices where doc.schedules[index].routineID == id
                && (doc.schedules[index].endsAt == nil || doc.schedules[index].endsAt! > starts) {
                doc.schedules[index].endsAt = starts
            }
            doc.schedules.append(.init(routineID: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount.trimmingCharacters(in: .whitespacesAndNewlines), weekdays: weekdays,
                times: times.sorted { $0.minute < $1.minute }, startsAt: starts))
        }
    }
    func archive(_ routineID: UUID, now: Date = .now) throws {
        try mutate { doc in
            // Close versions instead of deleting them: past unlogged history still exists.
            for i in doc.schedules.indices where doc.schedules[i].routineID == routineID {
                if doc.schedules[i].endsAt == nil || doc.schedules[i].endsAt! > now {
                    doc.schedules[i].endsAt = max(doc.schedules[i].startsAt, now)
                }
            }
        }
    }
    func occurrences(on date: Date) -> [MedicationOccurrence] { document.occurrences(on: date) }

    func record(_ dose: MedicationOccurrence, status: MedicationDoseStatus, takenAt: Date? = nil,
                source: String = "today", now: Date = .now) throws {
        guard let day = Date.fromISODateString(dose.localDay),
              day <= MedicationCalendar.calendar.startOfDay(for: now),
              let current = occurrences(on: day).first(where: { $0.id == dose.id }),
              current.revision == dose.revision else { throw MedicationError.stale }
        if source == "notification" {
            guard enabled, current.status == .notLogged, dose.localDay == now.isoDateString,
                  document.schedules.contains(where: { $0.id == dose.scheduleID && ($0.endsAt == nil || $0.endsAt! > now) })
            else { throw MedicationError.stale }
        }
        let actual = status == .taken ? (takenAt ?? now) : nil
        if let actual, actual > now { throw MedicationError.invalid }
        try mutate { doc in
            var next = current
            next.status = status; next.takenAt = actual; next.recordedAt = now; next.revision = UUID()
            doc.doses[next.id] = next
            doc.events.append(.init(occurrence: next, source: source))
        }
    }

    /// Returns false only for failed pending writes. An unused, default-off feature must
    /// not put a global sync error on Today before its schema is deployed.
    @discardableResult func sync(refresh: Bool = false) async -> Bool {
        guard let owner = accountID, !storageFailed else { return pendingCount == 0 }
        guard syncGeneration != generation else { return true }
        let token = generation
        syncGeneration = token; isSyncing = true
        defer { if generation == token { isSyncing = false }; if syncGeneration == token { syncGeneration = nil } }
        do {
            if cache.pending && !hasConflict {
                let snapshot = cache
                let remote = try await transport.save(owner: owner, document: snapshot.document,
                    expectedRevision: snapshot.serverRevision, writeID: snapshot.writeID)
                guard generation == token, remote.user_id == owner, remote.document.isValid else { return false }
                var next = cache
                next.serverRevision = remote.revision
                if next.writeID == snapshot.writeID { next.pending = false }
                try persist(next)
                if next.pending && automaticallyReconcile {
                    // An edit landed during the upload. A push requested against this store
                    // while it was busy may already have returned, so queue a trailing pass.
                    Task { await SyncEngine.shared.pushPendingChanges() }
                }
            }
            if refresh || hasConflict {
                let revision = cache.writeID
                let remote = try await transport.fetch(owner: owner)
                guard generation == token, cache.writeID == revision else { return true }
                if let remote {
                    guard remote.user_id == owner, remote.document.isValid else { throw MedicationError.unavailable }
                    var next = cache
                    if cache.pending { next.conflict = remote }
                    else {
                        next.document = remote.document; next.serverRevision = remote.revision
                        next.writeID = remote.write_id; next.conflict = nil
                    }
                    try persist(next)
                }
            }
            didLoad = true; syncFailed = hasConflict; changed()
            return !hasConflict
        } catch MedicationError.conflict {
            // Fetch the conflicting snapshot without replacing this phone's durable edits.
            if let remote = try? await transport.fetch(owner: owner), generation == token,
               remote.user_id == owner, remote.document.isValid {
                var next = cache; next.conflict = remote
                try? persist(next)
            }
            if generation == token { syncFailed = true; changed() }
            return false
        } catch {
            if generation == token { syncFailed = true }
            return !cache.pending
        }
    }
    func resolveConflict(useThisPhone: Bool) throws {
        guard let remote = cache.conflict else { return }
        var next = cache
        next.conflict = nil; next.serverRevision = remote.revision; next.writeID = UUID()
        if !useThisPhone { next.document = remote.document }
        next.pending = useThisPhone
        try persist(next); syncFailed = false; changed()
        if automaticallyReconcile { Task { await SyncEngine.shared.pushPendingChanges() } }
    }
    func purgeAccount(_ owner: UUID) throws {
        if FileManager.default.fileExists(atPath: file(owner).path) { try FileManager.default.removeItem(at: file(owner)) }
        if accountID == owner { setAccount(nil) }
    }
    private func changed() {
        NotificationCenter.default.post(name: .medicationsChanged, object: nil)
        if automaticallyReconcile { Task { await MedicationNotificationScheduler.shared.reconcile() } }
    }
}

extension Notification.Name {
    static let medicationsChanged = Notification.Name("medicationsChanged")
    static let medicationNotificationOpened = Notification.Name("medicationNotificationOpened")
}

#if DEBUG
extension MedicationStore {
    static func compactLayoutPreview() -> MedicationStore {
        let store = MedicationStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("medication-layout-\(UUID())"), automaticallyReconcile: false)
        store.accountID = UUID()
        let day = MedicationCalendar.calendar.startOfDay(for: .now)
        store.cache.document.enabled = true
        store.cache.document.intervals = [.init(start: day)]
        store.cache.document.schedules = ["NAC", "Stress Reset"].map { name in
            MedicationSchedule(routineID: UUID(), name: name, amount: "1 capsule", weekdays: Set(1...7), times: [.init(minute: 480), .init(minute: 1200)], startsAt: day)
        }
        for var dose in store.occurrences(on: .now) where dose.minute == 480 {
            dose.status = .taken; dose.takenAt = min(dose.scheduledAt, .now); dose.recordedAt = .now
            store.cache.document.doses[dose.id] = dose
        }
        store.didLoad = true
        return store
    }
}
#endif
