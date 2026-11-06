import Foundation

struct MedicationTime: Codable, Equatable, Identifiable {
    var id = UUID()
    var minute: Int
    var date: Date {
        MedicationCalendar.calendar.date(bySettingHour: minute / 60, minute: minute % 60,
                                         second: 0, of: .now) ?? .now
    }
}

/// Immutable once used: editing closes the old version and appends another.
struct MedicationSchedule: Codable, Equatable, Identifiable {
    var id = UUID()
    var routineID: UUID
    var name: String
    var amount: String
    var weekdays: Set<Int> // Gregorian Calendar weekday: Sunday = 1.
    var times: [MedicationTime]
    var startsAt: Date
    var endsAt: Date?
}

struct MedicationTrackingInterval: Codable, Equatable {
    var start: Date
    var end: Date?
    func contains(_ date: Date) -> Bool { date >= start && (end == nil || date < end!) }
}

enum MedicationDoseStatus: String, Codable, CaseIterable {
    case notLogged, taken, skipped
    var title: String {
        switch self { case .notLogged: "Not logged"; case .taken: "Taken"; case .skipped: "Skipped" }
    }
}

struct MedicationOccurrence: Codable, Equatable, Identifiable {
    var id: String
    var scheduleID: UUID
    var routineID: UUID
    var localDay: String
    var timeZoneID: String
    var scheduledAt: Date
    var minute: Int
    var name: String
    var amount: String
    var status: MedicationDoseStatus = .notLogged
    var takenAt: Date?
    var recordedAt: Date?
    var revision = UUID()
    var group: String { minute < 720 ? "Morning" : (minute < 1020 ? "Afternoon" : "Evening") }
}

struct MedicationDoseEvent: Codable, Equatable, Identifiable {
    var id = UUID()
    var occurrence: MedicationOccurrence
    var source: String
}

struct MedicationDocument: Codable, Equatable {
    var enabled = false
    var intervals: [MedicationTrackingInterval] = []
    var schedules: [MedicationSchedule] = []
    // Only resolved or explicitly corrected occurrences need durable materialization.
    // Unlogged days are reconstructed from effective schedules and activation intervals.
    var doses: [String: MedicationOccurrence] = [:]
    var events: [MedicationDoseEvent] = []

    var isValid: Bool {
        guard Set(schedules.map(\.id)).count == schedules.count,
              schedules.allSatisfy({ schedule in
                  MedicationCalendar.valid(name: schedule.name, amount: schedule.amount,
                      weekdays: schedule.weekdays, times: schedule.times)
                      && Set(schedule.times.map(\.id)).count == schedule.times.count
                      && (schedule.endsAt.map { $0 >= schedule.startsAt } ?? true)
              }),
              intervals.allSatisfy({ interval in interval.end.map { $0 >= interval.start } ?? true }) else { return false }
        return doses.allSatisfy { key, dose in
            key == dose.id && (0..<1440).contains(dose.minute)
                && Date.fromISODateString(dose.localDay) != nil
                && TimeZone(identifier: dose.timeZoneID) != nil
                && (dose.status == .taken ? dose.takenAt != nil : dose.takenAt == nil)
        }
    }

    func occurrences(on date: Date, calendar: Calendar = MedicationCalendar.calendar) -> [MedicationOccurrence] {
        let day = date.isoDateString(in: calendar.timeZone)
        let weekday = calendar.component(.weekday, from: date)
        var values: [String: MedicationOccurrence] = [:]
        for schedule in schedules where schedule.weekdays.contains(weekday) {
            for slot in schedule.times {
                guard let fire = MedicationCalendar.fireDate(on: date, minute: slot.minute, calendar: calendar),
                      fire >= schedule.startsAt, schedule.endsAt.map({ fire < $0 }) ?? true,
                      intervals.contains(where: { $0.contains(fire) }) else { continue }
                // A dose can be taken early. Replacing the remaining schedule today must
                // not create another obligation for a slot already taken or skipped.
                if doses.values.contains(where: {
                    $0.localDay == day && $0.routineID == schedule.routineID && $0.scheduleID != schedule.id
                        && $0.status != .notLogged && ($0.id.hasSuffix(slot.id.uuidString) || $0.minute == slot.minute)
                }) { continue }
                let id = "\(schedule.id.uuidString)-\(day)-\(slot.id.uuidString)"
                values[id] = doses[id] ?? MedicationOccurrence(
                    id: id, scheduleID: schedule.id, routineID: schedule.routineID, localDay: day,
                    timeZoneID: calendar.timeZone.identifier, scheduledAt: fire, minute: slot.minute,
                    name: schedule.name, amount: schedule.amount,
                    // A stable initial revision makes the payload check survive regeneration.
                    revision: slot.id)
            }
        }
        // Preserve already logged entries across time-zone changes, archiving and pauses.
        for dose in doses.values where dose.localDay == day {
            if dose.status == .notLogged && values.values.contains(where: {
                $0.routineID == dose.routineID && $0.scheduleID != dose.scheduleID
                    && ($0.minute == dose.minute || $0.id.suffix(36) == dose.id.suffix(36))
            }) { continue }
            values[dose.id] = dose
        }
        return values.values.sorted {
            if $0.minute != $1.minute { return $0.minute < $1.minute }
            if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return $0.id < $1.id
        }
    }

    func currentSchedules(at now: Date) -> [MedicationSchedule] {
        // Include tomorrow's replacement in management without listing the old version twice.
        Dictionary(grouping: schedules.filter { $0.endsAt == nil || $0.endsAt! > now }, by: \.routineID)
            .values.compactMap { $0.max(by: { $0.startsAt < $1.startsAt }) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

enum MedicationCalendar {
    static func notificationBudget(otherRequestCount: Int) -> Int { max(0, 64 - max(8, otherRequestCount)) }
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
    static func fireDate(on day: Date, minute: Int, calendar: Calendar) -> Date? {
        guard (0..<1440).contains(minute) else { return nil }
        // nextTime handles a spring-forward gap; first handles a repeated fall-back time.
        return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day,
                             matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }
    static func valid(name: String, amount: String, weekdays: Set<Int>, times: [MedicationTime]) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 80 && amount.count <= 120
            && !weekdays.isEmpty && weekdays.isSubset(of: Set(1...7))
            && !times.isEmpty && times.count <= 12
            && times.allSatisfy { (0..<1440).contains($0.minute) }
            && Set(times.map(\.minute)).count == times.count
    }
}

enum MedicationError: LocalizedError {
    case unavailable, invalid, stale, conflict
    var errorDescription: String? {
        switch self {
        case .unavailable: "Couldn’t save your medication changes. Please try again."
        case .invalid: "Add a name, at least one day, and distinct dose times."
        case .stale: "This dose has changed. Review its latest entry before trying again."
        case .conflict: "Medications changed on another device. Review the synced version before continuing."
        }
    }
}
