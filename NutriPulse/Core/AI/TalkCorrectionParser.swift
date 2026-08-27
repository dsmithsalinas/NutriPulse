import Foundation

enum TalkCorrectionAction: Equatable {
    case remove(query: String)
    case scale(query: String?, multiplier: Double)
    case setQuantity(query: String?, quantity: Double)
}

// Fast, on-device handling for the corrections people naturally make after seeing the
// confirm card. This deliberately covers edits to resolved rows; adding a brand-new food
// still goes through Parse so its nutrition can be grounded rather than guessed locally.
enum TalkCorrectionParser {
    static func parse(_ raw: String) -> TalkCorrectionAction? {
        var text = raw.lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix(".") { text.removeLast() }
        for prefix in ["actually ", "please ", "change "] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }

        if let query = suffix(afterAny: ["remove ", "drop ", "without "], in: text) {
            return .remove(query: cleanedQuery(query))
        }

        if let query = suffix(afterAny: ["half the ", "halve the ", "half ", "halve "], in: text) {
            return .scale(query: optionalQuery(query), multiplier: 0.5)
        }
        if let query = suffix(afterAny: ["double the ", "double "], in: text) {
            return .scale(query: optionalQuery(query), multiplier: 2)
        }

        let words = text.split(separator: " ").map(String.init)
        if words.first == "make", let quantityIndex = words.lastIndex(where: { number($0) != nil }),
           let quantity = number(words[quantityIndex]) {
            let rawQuery = words.dropFirst().prefix(quantityIndex - 1).joined(separator: " ")
            return .setQuantity(query: optionalQuery(rawQuery), quantity: quantity)
        }

        return nil
    }

    private static func suffix(afterAny prefixes: [String], in text: String) -> String? {
        guard let prefix = prefixes.first(where: text.hasPrefix) else { return nil }
        return String(text.dropFirst(prefix.count))
    }

    private static func cleanedQuery(_ value: String) -> String {
        var cleaned = value.replacingOccurrences(of: "serving of ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if cleaned.hasPrefix("the ") { cleaned.removeFirst(4) }
        return cleaned
    }

    private static func optionalQuery(_ value: String) -> String? {
        let cleaned = cleanedQuery(value)
        return cleaned.isEmpty || ["it", "that", "this"].contains(cleaned) ? nil : cleaned
    }

    private static func number(_ word: String) -> Double? {
        if let value = Double(word) { return value }
        return [
            "quarter": 0.25, "half": 0.5, "one": 1, "two": 2, "three": 3,
            "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8
        ][word]
    }
}
