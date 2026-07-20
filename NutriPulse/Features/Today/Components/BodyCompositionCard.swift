import SwiftUI

// The door to the Body hub. Once a 2×2 detail grid, now a compact four-chip summary —
// the detail (history, trends, measurements) lives in the hub; this card answers
// "where am I right now" and gets out of the way. The + keeps the direct-log shortcut.
struct BodyCompositionCard: View {
    let data: BodyCompositionData
    let waistCm: Double?
    let units: UnitSystem
    let onOpen: () -> Void
    let onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(Theme.Colors.primary)
                    Text("Body")
                        .fontWeight(.semibold)
                }
                Spacer()
                Button(action: onAddTapped) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.Colors.primary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: Theme.Spacing.sm) {
                chip(
                    value: data.weightKg.map { String(format: "%.1f", units.weightInput(from: $0)) },
                    label: "WEIGHT \(units.weightUnit.uppercased())",
                    color: Theme.Colors.primary
                )
                chip(
                    value: data.bodyFatPct.map { String(format: "%.1f%%", $0) },
                    label: "BODY FAT",
                    color: Theme.Colors.accent
                )
                chip(
                    value: data.lbmKg.map { String(format: "%.1f", units.weightInput(from: $0)) },
                    label: "LEAN \(units.weightUnit.uppercased())",
                    color: Theme.NutrientColor.fiber
                )
                chip(
                    value: waistCm.map { String(format: "%.1f", units.lengthInput(fromCm: $0)) },
                    label: "WAIST \(units.lengthUnit.uppercased())",
                    color: Theme.NutrientColor.water
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
        .card()
        // The whole card opens the hub; the + above stays its own button because it sits
        // on top of this gesture in the hit-test order.
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private func chip(value: String?, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value ?? "—")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(value != nil ? color : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.Colors.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.Colors.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
        }
    }
}
