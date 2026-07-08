import Foundation

extension Date {

    // "2024-03-15" — matches Supabase `date` columns.
    //
    // Built per call rather than cached in a `static let` DateFormatter. The cached one
    // captured `TimeZone.current` once, for the life of the process. `isToday` reads
    // `Calendar.current`, which reflects the *current* zone on every call. Change
    // timezone without relaunching — fly New York → Tokyo, or just toggle it in Settings —
    // and the two disagreed: `isToday` said Jul 7 while this still formatted `.now` as
    // Jul 6 in Eastern time. Every `log_date` the app writes and every date filter it
    // queries with comes from here, so a meal logged in that state was written to, and
    // then invisible on, the day the user was looking at.
    //
    // Two deliberate choices guard the format itself:
    //   * an explicit Gregorian calendar, so a Thai user's Buddhist `Calendar.current`
    //     doesn't render the year as 2569
    //   * `String(format:)` over a DateFormatter, so digits are always ASCII — locales
    //     with Arabic-Indic numerals would otherwise send Postgres something it can't parse
    func isoDateString(in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: self)
        // %ld, not %d: Int is CLong on 64-bit Apple platforms, and %d reads only 32 bits.
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    var isoDateString: String { isoDateString(in: .current) }

    // The exact inverse of isoDateString: "2024-03-15" → that day's midnight, in the given
    // zone. Anything that parses a `log_date` MUST read it back in the zone it was written
    // in. Reading it as UTC midnight (`logDate + "T00:00:00Z"`) put a US Pacific user's
    // body-fat point at 5pm the previous day, one column left of the calories and weight
    // charts built from the same log.
    static func fromISODateString(_ string: String, in timeZone: TimeZone = .current) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    // "Friday, March 15, 2024" — FormatStyle resolves locale and timezone at call time,
    // unlike a cached DateFormatter, which freezes both.
    var displayDateString: String { formatted(date: .complete, time: .omitted) }

    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isFuture: Bool { self > .now }
}
