import SwiftUI

struct BodyCompositionSheet: View {
    let current: BodyCompositionData
    let heightCm: Double?
    let onSave: (_ weightKg: Double?, _ bodyFatPct: Double?, _ bmi: Double?, _ lbmKg: Double?, _ writeToHK: Bool) async -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    // Form state — pre-populated from current display data
    @State private var weightText    = ""
    @State private var bodyFatText   = ""
    @State private var bmiText       = ""
    @State private var lbmText       = ""
    @State private var writeToHK     = false
    @State private var isSaving      = false

    private let hkAvailable = HealthKitManager.shared.isAvailable

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurements") {
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
        }
    }

    private var allEmpty: Bool {
        weightText.trimmed.isEmpty && bodyFatText.trimmed.isEmpty &&
        bmiText.trimmed.isEmpty    && lbmText.trimmed.isEmpty
    }

    private func prefill() {
        if let w = current.weightKg {
            weightText = String(format: "%.1f", units.weightInput(from: w))
        }
        if let bf = current.bodyFatPct { bodyFatText = String(format: "%.1f", bf) }
        if let b  = current.bmi        { bmiText     = String(format: "%.1f", b) }
        if let l  = current.lbmKg      { lbmText     = String(format: "%.1f", units.weightInput(from: l)) }
    }

    private func recalculateBMI() {
        guard let h = heightCm, h > 0,
              let inputVal = Double(weightText.trimmed), inputVal > 0 else { return }
        let kg      = units.kgFrom(inputVal)
        let heightM = h / 100
        let bmi     = kg / (heightM * heightM)
        bmiText = String(format: "%.1f", bmi)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let weightKg   = Double(weightText.trimmed).map  { units.kgFrom($0) }
        let bodyFatPct = Double(bodyFatText.trimmed)
        let bmi        = Double(bmiText.trimmed)
        let lbmKg      = Double(lbmText.trimmed).map     { units.kgFrom($0) }

        await onSave(weightKg, bodyFatPct, bmi, lbmKg, writeToHK)
        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
