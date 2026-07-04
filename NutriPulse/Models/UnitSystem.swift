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
            let totalIn = Int(cm / 2.54)
            return "\(totalIn / 12)'\(totalIn % 12)\""
        }
    }

    // MARK: Input labels

    var weightUnit: String { self == .metric ? "kg" : "lbs" }

    // MARK: Conversion helpers (input → storage)

    func kgFrom(_ value: Double) -> Double {
        self == .imperial ? value / 2.20462 : value
    }

    func cmFrom(feet: Double, inches: Double) -> Double {
        (feet * 12 + inches) * 2.54
    }

    // MARK: Conversion helpers (storage → input)

    func weightInput(from kg: Double) -> Double {
        self == .imperial ? kg * 2.20462 : kg
    }

    func feetFrom(_ cm: Double) -> Double { Double(Int(cm / 2.54) / 12) }
    func inchesFrom(_ cm: Double) -> Double { Double(Int(cm / 2.54) % 12) }
}
