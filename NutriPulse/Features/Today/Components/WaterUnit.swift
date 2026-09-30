import SwiftUI

// Storage is always ml. This enum handles display and quick-add conversions only.
enum WaterUnit: String {
    case ml = "ml"
    case oz = "oz"

    private static let mlPerOz: Double = 29.5735

    func display(_ ml: Double) -> String {
        switch self {
        case .ml: return String(format: "%.0f ml", ml)
        case .oz: return String(format: "%.0f oz", ml / WaterUnit.mlPerOz)
        }
    }

    func displayTotal(_ intakeMl: Double, goalMl: Double) -> String {
        switch self {
        case .ml:
            return "\(String(format: "%.0f", intakeMl)) / \(String(format: "%.0f", goalMl)) ml"
        case .oz:
            let intake = (intakeMl / WaterUnit.mlPerOz).rounded()
            let goal   = (goalMl   / WaterUnit.mlPerOz).rounded()
            return "\(Int(intake)) / \(Int(goal)) oz"
        }
    }

    var quickAdds: [(label: String, ml: Double)] {
        switch self {
        case .ml: return [("250 ml", 250), ("500 ml", 500), ("750 ml", 750)]
        case .oz: return [("8 oz",  8  * WaterUnit.mlPerOz),
                          ("12 oz", 12 * WaterUnit.mlPerOz),
                          ("16 oz", 16 * WaterUnit.mlPerOz)]
        }
    }
}
