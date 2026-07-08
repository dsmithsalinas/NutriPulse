import Foundation

enum UnitSystem: String {
    case metric   = "metric"
    case imperial = "imperial"

    // MARK: Display formatting

    func formatWeight(_ kg: Double) -> String {
        switch self {
        case .metric:   return String(format: "%.1f kg", kg)
        case .imperial: return String(format: "%.1f lbs", kg * 2.20462)
        }
    }

    func formatHeight(_ cm: Double) -> String {
        switch self {
        case .metric: return String(format: "%.0f cm", cm)
        case .imperial:
            let totalIn = UnitSystem.totalInches(fromCm: cm)
            return "\(totalIn / 12)'\(totalIn % 12)\""
        }
    }

    // MARK: Input labels

    var weightUnit: String { self == .metric ? "kg" : "lbs" }

    // MARK: Conversion helpers (input → storage)

    func kgFrom(_ value: Double) -> Double {
        self == .imperial ? value / 2.20462 : value
    }

    // cm → ft/in → cm is lossy, because the UI only offers whole inches: 172 cm displays
    // as 5'8" and converts back to 172.72. So merely opening the Edit Stats sheet and
    // tapping Save rewrote the user's height — silently, and it feeds BMR.
    //
    // When the entered feet/inches still describe the height we're holding, return that
    // height untouched. Only a real edit converts. `storedCm` is required rather than
    // defaulted: an unconditional cmFrom(feet:inches:) is precisely the trap that caused
    // the corruption, so it no longer exists to be reached for.
    func cmFrom(feet: Double, inches: Double, unchangedFrom storedCm: Double) -> Double {
        let entered = Int(feet.rounded()) * 12 + Int(inches.rounded())
        guard entered != UnitSystem.totalInches(fromCm: storedCm) else { return storedCm }
        return Double(entered) * 2.54
    }

    // MARK: Conversion helpers (storage → input)

    func weightInput(from kg: Double) -> Double {
        self == .imperial ? kg * 2.20462 : kg
    }

    // Whole inches, ROUNDED. Truncating instead — `Int(cm / 2.54)` — lost up to an inch
    // every time: 172 cm is 67.7 in, which truncated to 67 and displayed as 5'7", and any
    // save then wrote back 170.18 cm. Rounding the total *before* splitting it also
    // prevents "5 ft 12 in", which is what you get from flooring the feet and separately
    // rounding the remainder (182 cm → 5 ft, remainder 11.65 in → rounds to 12).
    static func totalInches(fromCm cm: Double) -> Int {
        Int((cm / 2.54).rounded())
    }

    func feetFrom(_ cm: Double) -> Double { Double(UnitSystem.totalInches(fromCm: cm) / 12) }
    func inchesFrom(_ cm: Double) -> Double { Double(UnitSystem.totalInches(fromCm: cm) % 12) }
}
