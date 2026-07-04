import SwiftUI

struct BodyCompositionCard: View {
    let data: BodyCompositionData
    let units: UnitSystem
    let onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(.blue)
                    Text("Body Composition")
                        .fontWeight(.semibold)
                }
                Spacer()
                Button(action: onAddTapped) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // 2×2 metric grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                MetricTile(
                    label: "Weight",
                    value: data.weightKg.map { units.formatWeight($0) },
                    fromHK: data.weightFromHK
                )
                MetricTile(
                    label: "Body Fat",
                    value: data.bodyFatPct.map { String(format: "%.1f%%", $0) },
                    fromHK: data.bodyFatFromHK
                )
                MetricTile(
                    label: "BMI",
                    value: data.bmi.map { String(format: "%.1f", $0) },
                    fromHK: data.bmiFromHK
                )
                MetricTile(
                    label: "Lean Body Mass",
                    value: data.lbmKg.map { units.formatWeight($0) },
                    fromHK: data.lbmFromHK
                )
            }

            if let date = data.latestDate, !Calendar.current.isDateInToday(date) {
                Text("Last updated \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MetricTile: View {
    let label: String
    let value: String?
    let fromHK: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(value ?? "—")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(value != nil ? .primary : .tertiary)
                if fromHK {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
