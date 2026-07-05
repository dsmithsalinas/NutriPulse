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

struct WaterCard: View {
    let intakeMl: Double
    let goalMl: Double
    let onAdd: (Double) -> Void

    @AppStorage("waterUnit") private var waterUnitRaw = WaterUnit.ml.rawValue
    private var unit: WaterUnit { WaterUnit(rawValue: waterUnitRaw) ?? .ml }

    private var progress: Double {
        goalMl > 0 ? min(intakeMl / goalMl, 1.0) : 0
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Theme.NutrientColor.water)
                    Text("Water")
                        .fontWeight(.semibold)
                }
                Spacer()
                Text(unit.displayTotal(intakeMl, goalMl: goalMl))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Unit", selection: $waterUnitRaw) {
                    Text("ml").tag(WaterUnit.ml.rawValue)
                    Text("oz").tag(WaterUnit.oz.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.NutrientColor.water)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.4), value: intakeMl)
                }
            }
            .frame(height: 6)

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(unit.quickAdds, id: \.label) { item in
                    Button {
                        onAdd(item.ml)
                    } label: {
                        Text("+\(item.label)")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Theme.NutrientColor.water.opacity(0.12))
                            .foregroundStyle(Theme.NutrientColor.water)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }
}
