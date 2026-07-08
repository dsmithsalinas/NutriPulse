import Foundation

// FatSecret's `food.find_id_for_barcode` takes a GTIN-13: thirteen digits, zero-padded.
// The scanner accepts .ean8, .ean13, .upce and .code128 and forwarded whatever string
// AVFoundation handed it, so every product carrying a compressed UPC-E code — common on
// cans and bottles, where there's no room for a full UPC-A — came back "Barcode Not Found"
// even when FatSecret had the product.
//
// UPC-E is a *lossy-looking but reversible* compression of UPC-A: the position of the last
// digit tells you where to reinsert the run of zeros. It has to be expanded before padding.
enum BarcodeSymbology {
    case upce
    case ean8
    case ean13
    case other
}

enum BarcodeNormalizer {

    static func gtin13(value: String, symbology: BarcodeSymbology) -> String? {
        let digits = String(value.filter(\.isWholeNumber))
        guard !digits.isEmpty else { return nil }

        switch symbology {
        case .upce:
            guard let upca = expandUPCE(digits) else { return nil }
            return zeroPad(upca)
        case .ean8, .ean13, .other:
            // EAN-8 and UPC-A (12 digits, which AVFoundation reports as .ean13) just need
            // padding out to thirteen.
            guard digits.count <= 13 else { return nil }
            return zeroPad(digits)
        }
    }

    // MARK: - UPC-E → UPC-A

    // Accepts the 6-digit payload, or the 7-/8-digit forms that include the number system
    // and (for 8) the check digit. AVFoundation reports UPC-E as 8 characters.
    static func expandUPCE(_ digits: String) -> String? {
        var characters = Array(digits)
        var numberSystem: Character = "0"

        switch characters.count {
        case 6:
            break                                   // bare payload
        case 7:
            numberSystem = characters.removeFirst()
        case 8:
            numberSystem = characters.removeFirst()
            characters.removeLast()                 // provided check digit; recomputed below
        default:
            return nil
        }

        guard characters.count == 6, numberSystem == "0" || numberSystem == "1" else { return nil }

        let m = characters
        // The final digit selects where the suppressed zeros go back.
        let body: [Character]
        switch m[5] {
        case "0", "1", "2":
            body = [m[0], m[1], m[5], "0", "0", "0", "0", m[2], m[3], m[4]]
        case "3":
            body = [m[0], m[1], m[2], "0", "0", "0", "0", "0", m[3], m[4]]
        case "4":
            body = [m[0], m[1], m[2], m[3], "0", "0", "0", "0", "0", m[4]]
        default:  // 5–9
            body = [m[0], m[1], m[2], m[3], m[4], "0", "0", "0", "0", m[5]]
        }

        // Recompute rather than trusting the scanned check digit. By spec UPC-E carries the
        // UPC-A check digit, so the two agree — but this also makes the 6- and 7-digit forms
        // work, where there's no check digit to carry.
        let withoutCheck = String(numberSystem) + String(body)   // 11 digits
        return withoutCheck + String(upcCheckDigit(withoutCheck))
    }

    // Standard UPC/EAN modulo-10: digits in odd positions (1-indexed) weigh 3.
    static func upcCheckDigit(_ elevenDigits: String) -> Character {
        var sum = 0
        for (index, character) in elevenDigits.enumerated() {
            guard let value = character.wholeNumberValue else { return "0" }
            sum += (index % 2 == 0) ? value * 3 : value
        }
        let check = (10 - (sum % 10)) % 10
        return Character(String(check))
    }

    private static func zeroPad(_ digits: String) -> String {
        String(repeating: "0", count: max(0, 13 - digits.count)) + digits
    }
}
