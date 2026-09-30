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
                    TileEyebrow("Body")
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
                    .foregroundStyle(Theme.Colors.textFaint)
            }

            HStack(spacing: Theme.Spacing.sm) {
                chip(
                    value: data.weightKg.map { String(format: "%.1f", units.weightInput(from: $0)) },
                    label: "WEIGHT \(units.weightUnit.uppercased())",
                    spokenUnit: units.spokenWeightUnit,
                    color: Theme.Colors.primary
                )
                chip(
                    value: data.bodyFatPct.map { String(format: "%.1f%%", $0) },
                    label: "BODY FAT",
                    spokenUnit: "percent body fat",
                    color: Theme.Colors.accent
                )
                chip(
                    value: data.lbmKg.map { String(format: "%.1f", units.weightInput(from: $0)) },
                    label: "LEAN \(units.weightUnit.uppercased())",
                    spokenUnit: "\(units.spokenWeightUnit) lean mass",
                    color: Theme.NutrientColor.fiber
                )
                chip(
                    value: waistCm.map { String(format: "%.1f", units.lengthInput(fromCm: $0)) },
                    label: "WAIST \(units.lengthUnit.uppercased())",
                    spokenUnit: "\(units.spokenLengthUnit) waist",
                    color: Theme.NutrientColor.water
                )
            }

            if let date = data.latestDate, !Calendar.current.isDateInToday(date) {
                Text("Last updated \(date.formatted(.relative(presentation: .named)))")
                    .font(Theme.Fonts.body(11))
                    .foregroundStyle(Theme.Colors.textFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .tile(radius: Theme.Radius.tileSmall, padding: Theme.Spacing.md)
        // The whole card opens the hub; the + above stays its own button because it sits
        // on top of this gesture in the hit-test order.
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private func chip(value: String?, label: String, spokenUnit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value ?? "\u{2014}")
                .font(Theme.Fonts.number(14, .bold, relativeTo: .caption))
                .foregroundStyle(value != nil ? color : Theme.Colors.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.Fonts.body(9, .semibold))
                .foregroundStyle(Theme.Colors.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "\($0) \(spokenUnit)" } ?? "\(spokenUnit), no data")
    }
}
