import Foundation
import Observation

@MainActor
protocol MealNoteTransport {
    func fetch(for date: Date) async throws -> [MealNote]
    func save(_ note: MealNote) async throws
    func delete(_ note: MealNote) async throws
}

/// Durable account-scoped outbox. A revision prevents an in-flight upload from consuming
/// a later edit or undo. Deletes are tombstones even when creation has not finished yet.
@Observable @MainActor
final class MealNoteStore {
    static let shared = MealNoteStore()
    struct Entry: Codable, Equatable {
        var note: MealNote
        var revision = UUID()
        var pending: Operation?
    }
    enum Operation: String, Codable { case upsert, delete }
    struct Document: Codable { var entries: [Entry] = []; var knownDays: Set<String> = [] }
    private(set) var accountId: UUID?
    private(set) var entries: [Entry] = []
    private(set) var lastSyncFailed = false
    private(set) var storageFailed = false
    private var knownDays: Set<String> = []
    private var syncing = false
    private var generation = UUID()
    private var dataRevision = UUID()
    private let folder: URL
    private let transport: any MealNoteTransport
    init(folder: URL? = nil, transport: (any MealNoteTransport)? = nil) {
        self.folder = folder ?? URL.applicationSupportDirectory.appendingPathComponent("MealNotes", isDirectory: true)
        self.transport = transport ?? RemoteMealNoteRepository()
    }
    var pendingCount: Int { entries.filter { $0.pending != nil }.count }
    func isPending(_ id: UUID) -> Bool { entries.contains { $0.note.id == id && $0.pending != nil } }
    func cached(for date: Date) -> [MealNote] {
        entries.filter { $0.note.logDate == date.isoDateString && $0.pending != .delete }
            .map(\.note).sorted { $0.id.uuidString < $1.id.uuidString }
    }
    func cachedOnly(for date: Date) throws -> [MealNote] {
        guard accountId != nil, !storageFailed, knownDays.contains(date.isoDateString) else { throw URLError(.notConnectedToInternet) }
        return cached(for: date)
    }
    private func file(_ id: UUID) -> URL { folder.appendingPathComponent(id.uuidString + ".json") }
    func setAccount(_ id: UUID?) {
        guard id != accountId else { return }
        generation = UUID(); accountId = id; entries = []; knownDays = []; lastSyncFailed = false; storageFailed = false
        guard let id else { return }
        do {
            if FileManager.default.fileExists(atPath: file(id).path) {
                let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: file(id)))
                guard document.entries.allSatisfy({ $0.note.userId == id }) else { throw URLError(.cannotDecodeContentData) }
                entries = document.entries; knownDays = document.knownDays
            }
        } catch { storageFailed = true }
    }
    private func persist(_ document: Document) throws {
        guard let id = accountId, !storageFailed else { throw URLError(.cannotWriteToFile) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var directory = folder
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try JSONEncoder().encode(document).write(to: file(id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func save(_ note: MealNote) throws {
        guard note.userId == accountId, MealNote.validBody(note.body) != nil else { throw URLError(.userAuthenticationRequired) }
        var next = entries.filter { $0.note.id != note.id }
        next.append(.init(note: note, pending: .upsert))
        let days = knownDays.union([note.logDate])
        try persist(.init(entries: next, knownDays: days))
        entries = next; knownDays = days; dataRevision = UUID(); changed()
    }
    func delete(_ note: MealNote) throws {
        guard note.userId == accountId else { throw URLError(.userAuthenticationRequired) }
        var next = entries.filter { $0.note.id != note.id }
        next.append(.init(note: note, pending: .delete))
        try persist(.init(entries: next, knownDays: knownDays))
        entries = next; dataRevision = UUID(); changed()
    }
    func fetch(for date: Date) async throws -> [MealNote] {
        guard let id = accountId, !storageFailed else { throw URLError(.cannotOpenFile) }
        let request = generation
        let revision = dataRevision
        do {
            let remote = try await transport.fetch(for: date)
            guard accountId == id, generation == request, remote.allSatisfy({ $0.userId == id }) else { throw URLError(.userAuthenticationRequired) }
            guard dataRevision == revision else { return cached(for: date) }
            let pendingIDs = Set(entries.filter { $0.pending != nil }.map { $0.note.id })
            let next = entries.filter { $0.note.logDate != date.isoDateString || $0.pending != nil }
                + remote.filter { !pendingIDs.contains($0.id) }.map { Entry(note: $0) }
            let days = knownDays.union([date.isoDateString])
            try persist(.init(entries: next, knownDays: days))
            entries = next; knownDays = days
            return cached(for: date)
        } catch {
            guard accountId == id, generation == request else { throw URLError(.userAuthenticationRequired) }
            if knownDays.contains(date.isoDateString) { return cached(for: date) }
            throw error
        }
    }
    @discardableResult func sync() async -> Bool {
        guard !syncing, let id = accountId, !storageFailed else { return pendingCount == 0 }
        syncing = true
        defer { syncing = false }
        let request = generation
        do {
            while let item = entries.first(where: { $0.pending != nil }) {
                guard accountId == id, generation == request else { return false }
                if item.pending == .delete { try await transport.delete(item.note) }
                else { try await transport.save(item.note) }
                guard accountId == id, generation == request else { return false }
                if let index = entries.firstIndex(where: { $0.note.id == item.note.id && $0.revision == item.revision }) {
                    var next = entries
                    if item.pending == .delete { next.remove(at: index) } else { next[index].pending = nil }
                    try persist(.init(entries: next, knownDays: knownDays))
                    entries = next; dataRevision = UUID()
                }
            }
            lastSyncFailed = false; changed(); return true
        } catch {
            if accountId == id, generation == request { lastSyncFailed = true; changed() }
            return false
        }
    }
    func purgeAccount(_ id: UUID) throws {
        let url = file(id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        if accountId == id { generation = UUID(); entries = []; knownDays = []; changed() }
    }
    #if DEBUG
    func preview(_ note: MealNote) {
        accountId = note.userId; entries = [.init(note: note, pending: .upsert)]; knownDays = [note.logDate]
    }
    #endif
    private func changed() { NotificationCenter.default.post(name: .mealNotesChanged, object: nil) }
}
