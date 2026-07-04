import SwiftUI

struct WaterCard: View {
    let intakeMl: Double
    let goalMl: Double
    let onAdd: (Double) -> Void

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
                Text("\(formatted(intakeMl)) / \(formatted(goalMl)) L")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                ForEach([250, 500, 750], id: \.self) { ml in
                    Button {
                        onAdd(Double(ml))
                    } label: {
                        Text("+\(ml) ml")
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatted(_ ml: Double) -> String {
        let liters = ml / 1000
        return liters.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", liters)
            : String(format: "%.1f", liters)
    }
}
