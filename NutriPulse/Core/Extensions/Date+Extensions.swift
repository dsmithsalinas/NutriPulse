import Foundation

extension Date {
    // SWIFT CONCEPT — `static let` on a DateFormatter is a cached singleton on the type.
    // DateFormatter is expensive to initialize. Creating it once and reusing it is the
    // Swift equivalent of memoizing an Intl.DateTimeFormat instance in JS.

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    // "2024-03-15" — matches Supabase date columns
    var isoDateString: String { Date.isoDateFormatter.string(from: self) }

    // "Friday, March 15, 2024"
    var displayDateString: String { Date.displayDateFormatter.string(from: self) }

    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isFuture: Bool { self > .now }
}
