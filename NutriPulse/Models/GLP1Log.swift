import Foundation

// A skipped scheduled dose is not an injection. Keeping it separate preserves dose charts,
// site rotation, and the actual number of days since the last shot.
struct GLP1SkippedDose: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let injectionId: UUID
    let scheduledAt: Date
    let nextReminderAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case injectionId = "injection_id"
        case scheduledAt = "scheduled_at"
        case nextReminderAt = "next_reminder_at"
        case createdAt = "created_at"
    }
}

struct GLP1DoseSchedule {
    let latest: GLP1Log?
    let skips: [GLP1SkippedDose]
    var now: Date = .now
    var calendar: Calendar = .current

    var relevantSkips: [GLP1SkippedDose] {
        skips.filter { $0.injectionId == latest?.id }.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    // Advance only through explicitly skipped dates. Passing time alone is not a skip.
    var nextDue: Date? {
        guard var due = latest?.nextDueAt else { return nil }
        for skip in relevantSkips {
            if abs(skip.scheduledAt.timeIntervalSince(due)) < 1, skip.nextReminderAt > due {
                due = skip.nextReminderAt
            }
        }
        return due
    }

    var latestSkip: GLP1SkippedDose? { relevantSkips.last }
    var skippedThisWeek: GLP1SkippedDose? {
        guard let skip = latestSkip, let due = nextDue,
              calendar.startOfDay(for: due) > calendar.startOfDay(for: now),
              abs(due.timeIntervalSince(skip.nextReminderAt)) < 1 else { return nil }
        return skip
    }

    var cycleInterrupted: Bool {
        relevantSkips.contains {
            calendar.startOfDay(for: $0.scheduledAt) <= calendar.startOfDay(for: now)
        }
    }

    var isPastDueDay: Bool {
        nextDue.map { calendar.startOfDay(for: $0) < calendar.startOfDay(for: now) } ?? false
    }

    /// More than one dose has gone by with no shot or skip logged: the planned day is a full
    /// cycle or more in the past, so the next one has been missed too. Today's card then shows
    /// the last shot and points to the prescriber rather than presenting an old plan as current
    /// (docs/skipped-shot-support.md).
    var missedMoreThanOneDose: Bool {
        guard let latest, let due = nextDue else { return false }
        let daysPast = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: due), to: calendar.startOfDay(for: now)
        ).day ?? 0
        return daysPast >= latest.cycleLengthDays
    }
}

extension GLP1Log {
    /// Days between this shot and the next one due, from the dose schedule; weekly when that
    /// is missing or implausible. Past it, the cycle reads as "Shot due" rather than day 8, 9…
    var cycleLengthDays: Int {
        guard let due = nextDueAt else { return 7 }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: injectedAt),
            to: Calendar.current.startOfDay(for: due)
        ).day ?? 7
        return (1...14).contains(days) ? days : 7
    }
}

extension Notification.Name {
    static let glp1DoseHistoryChanged = Notification.Name("glp1DoseHistoryChanged")
}

struct GLP1Log: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let injectedAt: Date
    let medication: String
    let doseMg: Double
    // Nullable in the database (glp1_logs.site, glp1_logs.next_due_at). This app always
    // writes both, but decoding them as non-optional meant a single row created anywhere
    // else — the SQL editor, support tooling, an older or newer client — threw a
    // DecodingError for the *entire array*, blanking the GLP-1 card and the titration
    // chart rather than skipping one row.
    let site: String?
    let nextDueAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case injectedAt = "injected_at"
        case medication
        case doseMg     = "dose_mg"
        case site
        case nextDueAt  = "next_due_at"
    }
}

struct NewGLP1Log: Encodable {
    let userId: UUID
    let injectedAt: Date
    let medication: String
    let doseMg: Double
    let site: String
    let nextDueAt: Date

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case injectedAt = "injected_at"
        case medication
        case doseMg     = "dose_mg"
        case site
        case nextDueAt  = "next_due_at"
    }
}

// ─── Medication definitions ───────────────────────────────────────────────────

enum GLP1Medication: String, CaseIterable, Identifiable {
    case ozempic  = "Ozempic"
    case wegovy   = "Wegovy"
    case mounjaro = "Mounjaro"
    case zepbound = "Zepbound"

    var id: String { rawValue }

    var activeIngredient: String {
        switch self {
        case .ozempic, .wegovy:    return "semaglutide"
        case .mounjaro, .zepbound: return "tirzepatide"
        }
    }

    var availableDoses: [Double] {
        switch self {
        case .ozempic:             return [0.25, 0.5, 1.0, 2.0]
        case .wegovy:              return [0.25, 0.5, 1.0, 1.7, 2.4]
        case .mounjaro, .zepbound: return [2.5, 5.0, 7.5, 10.0, 12.5, 15.0]
        }
    }
}

// ─── Dose formatting ─────────────────────────────────────────────────────────

extension Double {
    // Renders a dose exactly: 12.5 → "12.5", 10.0 → "10", 0.25 → "0.25".
    // Never use "%g"-family format specifiers here — they round to significant
    // digits, so "%.2g" silently turns Mounjaro's 12.5 mg step into "12".
    var glp1DoseString: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}

// ─── Injection sites (rotation order) ────────────────────────────────────────

enum InjectionSite: String, CaseIterable, Identifiable {
    case leftAbdomen  = "Left Abdomen"
    case rightAbdomen = "Right Abdomen"
    case leftThigh    = "Left Thigh"
    case rightThigh   = "Right Thigh"
    case leftArm      = "Left Arm"
    case rightArm     = "Right Arm"

    var id: String { rawValue }
}
