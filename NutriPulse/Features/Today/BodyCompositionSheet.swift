import SwiftUI

struct BodyCompositionSheet: View {
    let current: BodyCompositionData
    let heightCm: Double?
    let onSave: (
        _ weightKg: Double?,
        _ bodyFatPct: Double?,
        _ bmi: Double?,
        _ lbmKg: Double?,
        _ measurementsCm: [MeasurementSite: Double],
        _ writeToHK: Bool
    ) async -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    // Form state — pre-populated from current display data
    @State private var weightText    = ""
    @State private var bodyFatText   = ""
    @State private var bmiText       = ""
    @State private var lbmText       = ""
    // Tape measurements, keyed by site. Waist renders as its own row; the rest live
    // behind a disclosure so the sheet stays as light as it is today.
    @State private var measurementTexts: [MeasurementSite: String] =
        Dictionary(uniqueKeysWithValues: MeasurementSite.allCases.map { ($0, "") })
    @State private var showMoreSites = false
    @State private var writeToHK     = false
    @State private var isSaving      = false
    @State private var errorMessage: String? = nil

    private let hkAvailable = HealthKitManager.shared.isAvailable

    var body: some View {
        NavigationStack {
            Form {
                Section("Body composition") {
                    LabeledContent("\(units.weightUnit.capitalized)") {
                        TextField("e.g. \(units == .metric ? "75.0" : "165.0")", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: weightText) { _, _ in recalculateBMI() }
                    }
                    LabeledContent("Body Fat %") {
                        TextField("e.g. 22.4", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("BMI") {
                        TextField("e.g. 24.5", text: $bmiText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Lean Body Mass (\(units.weightUnit))") {
                        TextField("e.g. \(units == .metric ? "58.0" : "128.0")", text: $lbmText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if heightCm != nil {
                    Section {
                        Text("BMI auto-calculates from your height and the weight you enter. You can override it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    measurementRow(.waist)
                    if showMoreSites {
                        ForEach(MeasurementSite.allCases.filter { $0 != .waist }) { site in
                            measurementRow(site)
                        }
                    } else {
                        Button("Also add hips, chest, arm, or thigh") {
                            showMoreSites = true
                        }
                        .font(.subheadline)
                    }
                } header: {
                    Text("Tape measurements")
                } footer: {
                    Text("Measurements move slowly — every few weeks is plenty.")
                }

                if hkAvailable {
                    Section("Apple Health") {
                        Toggle("Write to Apple Health", isOn: $writeToHK)
                    }
                }
            }
            .navigationTitle("Log Body Composition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving || allEmpty)
                }
            }
            .onAppear { prefill() }
            .alert("Check your numbers", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var allEmpty: Bool {
        weightText.trimmed.isEmpty && bodyFatText.trimmed.isEmpty &&
        bmiText.trimmed.isEmpty    && lbmText.trimmed.isEmpty &&
        measurementTexts.values.allSatisfy { $0.trimmed.isEmpty }
    }

    private func measurementRow(_ site: MeasurementSite) -> some View {
        LabeledContent("\(site.displayName) (\(units.lengthUnit))") {
            TextField(
                units == .metric ? "e.g. 96.5" : "e.g. 38.0",
                text: Binding(
                    get: { measurementTexts[site] ?? "" },
                    set: { measurementTexts[site] = $0 }
                )
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
    }

    private func prefill() {
        if let w = current.weightKg {
            weightText = String(format: "%.1f", units.weightInput(from: w))
        }
        if let bf = current.bodyFatPct { bodyFatText = String(format: "%.1f", bf) }
        if let b  = current.bmi        { bmiText     = String(format: "%.1f", b) }
        if let l  = current.lbmKg      { lbmText     = String(format: "%.1f", units.weightInput(from: l)) }
    }

    // `Double("75,5")` is nil. .decimalPad shows a comma for German, French, Spanish and
    // Brazilian users, so every value they typed parsed to nil, got silently dropped, and
    // the sheet dismissed as though it had saved. DecimalInput handles the locale's
    // separator (and strips a pasted "-").
    private func parse(_ text: String) -> Double? {
        let cleaned = DecimalInput.sanitize(text.trimmed)
        guard !cleaned.isEmpty else { return nil }
        return DecimalInput.value(from: cleaned)
    }

    private func recalculateBMI() {
        guard let h = heightCm, h > 0,
              let inputVal = parse(weightText), inputVal > 0 else { return }
        let kg      = units.kgFrom(inputVal)
        let heightM = h / 100
        let bmi     = kg / (heightM * heightM)
        bmiText = String(format: "%.1f", bmi)
    }

    // Plausibility bounds. Without them a fat-fingered "224" for body fat was stored as
    // 224% and charted, while the HealthKit write threw an out-of-range error that `try?`
    // swallowed — leaving Supabase and Apple Health silently disagreeing.
    private static let bodyFatRange = 1.0...75.0
    private static let bmiRange     = 8.0...100.0
    private static let weightKgRange = 20.0...500.0
    // Generous enough for any site from upper arm to hips; tight enough to catch a
    // fat-fingered "382" or a value typed in the wrong unit.
    private static let measurementCmRange = 15.0...250.0

    private func validationError() -> String? {
        if let bf = parse(bodyFatText), !Self.bodyFatRange.contains(bf) {
            return "Body fat should be between \(Int(Self.bodyFatRange.lowerBound))% and \(Int(Self.bodyFatRange.upperBound))%."
        }
        if let bmi = parse(bmiText), !Self.bmiRange.contains(bmi) {
            return "BMI should be between \(Int(Self.bmiRange.lowerBound)) and \(Int(Self.bmiRange.upperBound))."
        }
        for (text, label) in [(weightText, "Weight"), (lbmText, "Lean body mass")] {
            if let value = parse(text), !Self.weightKgRange.contains(units.kgFrom(value)) {
                return "\(label) looks out of range. Check the value and try again."
            }
        }
        for site in MeasurementSite.allCases {
            if let value = parse(measurementTexts[site] ?? ""),
               !Self.measurementCmRange.contains(units.cmFromLength(value)) {
                return "\(site.displayName) looks out of range. Check the value and try again."
            }
        }
        return nil
    }

    private func save() async {
        if let error = validationError() {
            errorMessage = error
            return
        }

        isSaving = true
        defer { isSaving = false }

        let weightKg   = parse(weightText).map { units.kgFrom($0) }
        let bodyFatPct = parse(bodyFatText)
        let bmi        = parse(bmiText)
        let lbmKg      = parse(lbmText).map   { units.kgFrom($0) }

        var measurementsCm: [MeasurementSite: Double] = [:]
        for site in MeasurementSite.allCases {
            if let value = parse(measurementTexts[site] ?? ""), value > 0 {
                measurementsCm[site] = units.cmFromLength(value)
            }
        }

        await onSave(weightKg, bodyFatPct, bmi, lbmKg, measurementsCm, writeToHK)
        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
