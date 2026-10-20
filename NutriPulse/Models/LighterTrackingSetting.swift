import Foundation

struct LighterTrackingSetting: Codable, Equatable {
    enum Reason: String, Codable, CaseIterable, Identifiable {
        case vacation, feelingUnwell = "feeling_unwell", busyStretch = "busy_stretch"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .vacation: "Vacation"
            case .feelingUnwell: "Feeling unwell"
            case .busyStretch: "Busy stretch"
            }
        }
    }
    enum Duration: String, CaseIterable, Identifiable {
        case threeDays, oneWeek, untilReady
        var id: String { rawValue }
        var title: String {
            switch self {
            case .threeDays: "3 days"
            case .oneWeek: "1 week"
            case .untilReady: "Until I’m ready"
            }
        }
        func endDate(from now: Date, calendar: Calendar = .current) -> Date? {
            switch self {
            case .threeDays: calendar.date(byAdding: .day, value: 3, to: now)
            case .oneWeek: calendar.date(byAdding: .day, value: 7, to: now)
            case .untilReady: nil
            }
        }
    }
    var userId: UUID
    var enabled = false
    var reason: Reason? = nil
    var startedAt: Date? = nil
    var endsAt: Date? = nil
    var updatedAt: Date = .now

    enum CodingKeys: String, CodingKey {
        case userId = "user_id", enabled, reason, startedAt = "started_at", endsAt = "ends_at", updatedAt = "updated_at"
    }
    // Explicit nulls are essential on resume: an upsert must clear old context and dates.
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(userId, forKey: .userId)
        try values.encode(enabled, forKey: .enabled)
        try values.encode(updatedAt, forKey: .updatedAt)
        if let reason { try values.encode(reason, forKey: .reason) } else { try values.encodeNil(forKey: .reason) }
        if let startedAt { try values.encode(startedAt, forKey: .startedAt) } else { try values.encodeNil(forKey: .startedAt) }
        if let endsAt { try values.encode(endsAt, forKey: .endsAt) } else { try values.encodeNil(forKey: .endsAt) }
    }
    func needsResumeChoice(at now: Date = .now) -> Bool {
        enabled && startedAt.map { $0 <= now } == true && endsAt.map { $0 <= now } == true
    }
    func isActive(at now: Date = .now) -> Bool {
        enabled && startedAt.map { $0 <= now } == true && endsAt.map { $0 > now } != false
    }
    static func start(userId: UUID, reason: Reason?, duration: Duration, now: Date = .now,
                      calendar: Calendar = .current) -> Self {
        .init(userId: userId, enabled: true, reason: reason, startedAt: now,
              endsAt: duration.endDate(from: now, calendar: calendar))
    }
}
