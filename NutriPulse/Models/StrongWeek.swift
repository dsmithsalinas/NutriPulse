import Foundation

enum WeekCircumstance: String, Codable, CaseIterable, Identifiable {
    case travel, busy, easy, injury, usual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .travel: "Traveling"
        case .busy: "Busy week"
        case .easy: "Taking it easier"
        case .injury: "Injured / limited movement"
        case .usual: "Nothing different"
        }
    }
}

enum WeekAdjustment: String, Codable, CaseIterable, Identifiable {
    case simpler, moreFoodIdeas = "more_food_ideas", lessActivity = "less_activity"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .simpler: "Make it simpler"
        case .moreFoodIdeas: "More food ideas"
        case .lessActivity: "Less activity"
        }
    }
}

struct StrongWeekDraft: Equatable {
    var circumstances: Set<WeekCircumstance> = []
    var note = ""
    var activityRestrictions = ""
    var ongoing = false
    var adjustments: Set<WeekAdjustment> = []

    mutating func toggle(_ value: WeekCircumstance) {
        if circumstances.contains(value) { circumstances.remove(value); return }
        if value == .usual {
            circumstances = [.usual]
            note = ""
            activityRestrictions = ""
            ongoing = false
        } else {
            circumstances.remove(.usual)
            circumstances.insert(value)
        }
    }

    var normalized: Self {
        var value = self
        value.note = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        value.activityRestrictions = String(activityRestrictions.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        if !value.note.isEmpty || !value.activityRestrictions.isEmpty { value.circumstances.remove(.usual) }
        if value.circumstances == [.usual] || (value.circumstances.isEmpty && value.note.isEmpty && value.activityRestrictions.isEmpty) { value.ongoing = false }
        return value
    }
}

struct StrongWeekOutlook: Codable, Equatable {
    let observation: String
    let foodFocus: String
    let movementFocus: String
}

struct StrongWeek: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let weekStart: String
    let circumstances: [WeekCircumstance]
    let note: String
    let activityRestrictions: String
    let ongoing: Bool
    let contextRevision: UUID
    let outlook: StrongWeekOutlook?
    let generatedAt: Date?
    let updatedAt: Date
    var adjustments: [WeekAdjustment]? = nil

    var draft: StrongWeekDraft {
        .init(circumstances: Set(circumstances), note: note, activityRestrictions: activityRestrictions, ongoing: ongoing, adjustments: Set(adjustments ?? []))
    }
    enum CodingKeys: String, CodingKey {
        case id, circumstances, note, ongoing, outlook, adjustments
        case userId = "user_id", weekStart = "week_start", activityRestrictions = "activity_restrictions"
        case contextRevision = "context_revision", generatedAt = "generated_at", updatedAt = "updated_at"
    }
}

enum StrongWeekWindow {
    // Explicit Monday–Sunday local weeks, independent of the device's first-weekday setting.
    static func start(containing date: Date = .now, calendar: Calendar = .current) -> Date {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = calendar.timeZone
        let calendar = local
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day)!
    }
    static func key(for date: Date = .now, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: start(containing: date, calendar: calendar))
    }
}

struct StrongWeekContext: Encodable {
    let weekStart: String
    let status: String // current, needs_confirmation, not_provided
    let circumstances: [String]
    let note: String
    let activityRestrictions: String
    let outlook: StrongWeekOutlook?
    var adjustments: [String] = []

    static func make(current: StrongWeek?, previous: StrongWeek?, now: Date = .now) -> Self {
        let key = StrongWeekWindow.key(for: now)
        let active = current?.weekStart == key ? current : nil
        let pending = active == nil && previous?.ongoing == true && (previous?.weekStart ?? key) < key ? previous : nil
        let record = active ?? pending
        return .init(weekStart: key, status: active != nil ? "current" : pending != nil ? "needs_confirmation" : "not_provided",
                     circumstances: record?.circumstances.map(\.rawValue) ?? [], note: record?.note ?? "",
                     activityRestrictions: record?.activityRestrictions ?? "", outlook: active?.outlook,
                     adjustments: active?.adjustments?.map(\.rawValue) ?? [])
    }
    var needsTailoredSuggestions: Bool {
        status == "needs_confirmation" || adjustments.contains(WeekAdjustment.lessActivity.rawValue) || !note.isEmpty || !activityRestrictions.isEmpty
            || circumstances.contains(where: { $0 != "usual" })
    }
}

extension Notification.Name {
    static let strongWeekChanged = Notification.Name("strongWeekChanged")
}
