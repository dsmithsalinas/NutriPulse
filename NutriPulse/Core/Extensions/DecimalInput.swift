import Foundation

// Decimal text-field input handling.
//
// SWIFT CONCEPT — `TextField(value:format:)` looks like the right tool for a numeric
// field (it's the closest thing to `<input type="number">`), but it writes back to its
// binding only on submit or focus loss. A `.decimalPad` keyboard has no return key, and
// tapping a SwiftUI Button does not resign first responder — so the value the user just
// typed never reaches the ViewModel. Binding a plain String and parsing on every
// keystroke avoids the whole problem.
enum DecimalInput {

    // Keeps digits and at most one decimal separator; drops everything else.
    //
    // Dropping "-" matters: .decimalPad has no minus key, but *pasting* bypasses the
    // keyboard entirely, and a negative macro silently corrupts every daily total that
    // sums it. Fractions like "½" are `isNumber` but not `isWholeNumber`, hence the
    // stricter test.
    //
    // Typing "." on a comma-decimal keyboard (and vice versa) is normalized to whatever
    // separator the locale actually uses, so both keypad layouts behave the same.
    static func sanitize(_ raw: String, locale: Locale = .current) -> String {
        let separator = locale.decimalSeparator ?? "."
        var result = ""
        var hasSeparator = false

        for character in raw {
            if character.isWholeNumber {
                result.append(character)
            } else if character == "." || character == "," {
                guard !hasSeparator else { continue }
                hasSeparator = true
                result.append(separator)
            }
        }
        return result
    }

    // Parses text produced by `sanitize`. The NumberFormatter fallback covers locales
    // whose keypad emits non-ASCII digits (Arabic-Indic, Devanagari), which `Double.init`
    // rejects outright.
    static func value(from text: String, locale: Locale = .current) -> Double {
        guard !text.isEmpty else { return 0 }

        let separator = locale.decimalSeparator ?? "."
        let normalized = text.replacingOccurrences(of: separator, with: ".")
        if let parsed = Double(normalized) { return parsed }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        return formatter.number(from: text)?.doubleValue ?? 0
    }

    // Renders a value back into editable text. Grouping separators are suppressed — a
    // rendered "1,000" would be re-read as a decimal separator on the next keystroke.
    // Zero renders as empty so the field shows its "0" placeholder rather than a literal 0
    // the user has to delete before typing.
    static func text(from value: Double, locale: Locale = .current) -> String {
        guard value != 0 else { return "" }
        return value.formatted(.number.grouping(.never).locale(locale))
    }
}
