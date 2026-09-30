import SwiftUI

// Quick-add first: activity + a duration tap is a complete log. Calories and
// distance are optional detail for users who want it, never a requirement.
struct WorkoutEntrySheet: View {
    let onSave: (ManualActivityType, Double, Double?, Double?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    @State private var activity: ManualActivityType = .walk
    // nil selects the "Other" pill, which reveals the free minutes field.
    @State private var durationPreset: Int? = 30
    @State private var customMinutes = ""
    @State private var caloriesText = ""
    @State private var distanceText = ""
    @State private var isSaving = false

    private static let presets = [15, 30, 45, 60]

    private var resolvedMinutes: Double? {
        if let preset = durationPreset { return Double(preset) }
        guard let minutes = Double(customMinutes.replacingOccurrences(of: ",", with: ".")),
              minutes > 0 else { return nil }
        return minutes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(ManualActivityType.allCases, id: \.self) { option in
                            choicePill(
                                label: option.displayName,
                                symbol: option.symbolName,
                                isSelected: activity == option
                            ) { activity = option }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: { DaylightSectionHeader("Activity") }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 8)], spacing: 8) {
                        ForEach(Self.presets, id: \.self) { preset in
                            choicePill(label: "\(preset) min", isSelected: durationPreset == preset) {
                                durationPreset = preset
                            }
                        }
                        choicePill(label: "Other", isSelected: durationPreset == nil) {
                            durationPreset = nil
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if durationPreset == nil {
                        HStack {
                            Text("Minutes")
                            Spacer()
                            TextField("45", text: $customMinutes)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                } header: { DaylightSectionHeader("Duration") }
                .daylightSection()

                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Optional", text: $caloriesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text(units == .imperial ? "Distance (mi)" : "Distance (km)")
                        Spacer()
                        TextField("Optional", text: $distanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                } header: { DaylightSectionHeader("Details") }
                  footer: { DaylightSectionFooter("Both optional — leave blank to keep it quick.") }
                .daylightSection()
            }
            .daylightForm()
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let minutes = resolvedMinutes else { return }
                        Task {
                            isSaving = true
                            await onSave(activity, minutes, parsedCalories, parsedDistanceMeters)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(resolvedMinutes == nil || isSaving)
                }
            }
        }
    }

    private var parsedCalories: Double? {
        guard let kcal = Double(caloriesText.replacingOccurrences(of: ",", with: ".")),
              kcal > 0 else { return nil }
        return kcal
    }

    // Entered in the display unit (km or mi), stored in meters like everything else.
    private var parsedDistanceMeters: Double? {
        guard let value = Double(distanceText.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        return units == .imperial ? value * 1609.344 : value * 1000
    }

    private func choicePill(
        label: String,
        symbol: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 13))
                }
                Text(label)
                    .font(Theme.Fonts.body(15, .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Theme.Colors.primary : Theme.Colors.surfaceInset,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
