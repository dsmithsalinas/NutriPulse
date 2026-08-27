import Foundation

struct SmartNotificationHistoryEntry: Codable, Identifiable, Equatable {
    enum Feedback: String, Codable { case helpful, notHelpful }
    enum Status: String, Codable {
        case scheduled, delivered, opened, actioned, dismissed
    }

    let id: String
    let kind: SmartNotificationKind
    let title: String
    let body: String
    let rationale: String
    let scheduledAt: Date
    let fireDate: Date
    var feedback: Feedback?
    var status: Status

    init(
        id: String,
        kind: SmartNotificationKind,
        title: String,
        body: String,
        rationale: String,
        scheduledAt: Date,
        fireDate: Date,
        feedback: Feedback?,
        status: Status = .scheduled
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.rationale = rationale
        self.scheduledAt = scheduledAt
        self.fireDate = fireDate
        self.feedback = feedback
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, title, body, rationale, scheduledAt, fireDate, feedback, status
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        kind = try values.decode(SmartNotificationKind.self, forKey: .kind)
        title = try values.decode(String.self, forKey: .title)
        body = try values.decode(String.self, forKey: .body)
        rationale = try values.decode(String.self, forKey: .rationale)
        scheduledAt = try values.decode(Date.self, forKey: .scheduledAt)
        fireDate = try values.decode(Date.self, forKey: .fireDate)
        feedback = try values.decodeIfPresent(Feedback.self, forKey: .feedback)
        status = try values.decodeIfPresent(Status.self, forKey: .status) ?? .scheduled
    }
}

enum SmartNotificationHistoryStore {
    private static let key = "smartNotificationHistory"

    static func load(defaults: UserDefaults = .standard) -> [SmartNotificationHistoryEntry] {
        guard let data = defaults.data(forKey: key),
              let values = try? JSONDecoder().decode([SmartNotificationHistoryEntry].self, from: data) else { return [] }
        return values.sorted { $0.fireDate > $1.fireDate }
    }

    static func upsert(_ entry: SmartNotificationHistoryEntry, defaults: UserDefaults = .standard) {
        var values = load(defaults: defaults)
        values.removeAll { $0.id == entry.id }
        values.insert(entry, at: 0)
        save(Array(values.prefix(30)), defaults: defaults)
    }

    static func remove(ids: [String], defaults: UserDefaults = .standard) {
        guard !ids.isEmpty else { return }
        save(load(defaults: defaults).filter { !ids.contains($0.id) }, defaults: defaults)
    }

    static func setFeedback(_ feedback: SmartNotificationHistoryEntry.Feedback, for id: String, defaults: UserDefaults = .standard) {
        var values = load(defaults: defaults)
        guard let index = values.firstIndex(where: { $0.id == id }) else { return }
        values[index].feedback = feedback
        save(values, defaults: defaults)
    }

    static func setStatus(_ status: SmartNotificationHistoryEntry.Status, for id: String, defaults: UserDefaults = .standard) {
        var values = load(defaults: defaults)
        guard let index = values.firstIndex(where: { $0.id == id }) else { return }
        values[index].status = status
        save(values, defaults: defaults)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    private static func save(_ values: [SmartNotificationHistoryEntry], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: key)
    }
}
