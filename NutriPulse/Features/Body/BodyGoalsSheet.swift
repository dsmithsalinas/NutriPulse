import SwiftUI

// Set (or clear) body goals. Everything optional, no dates anywhere — the form asks
// "where", never "by when", and clearing a field removes the goal entirely.
struct BodyGoalsSheet: View {
    let current: BodyGoals?
    let onSave: (_ weightKgTarget: Double?, _ bodyFatPctTarget: Double?, _ leanMassKgFloor: Double?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    @State private var weightText  = ""
    @State private var bodyFatText = ""
    @State private var leanText    = ""
    @State private var isSaving    = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Weight (\(units.weightUnit))") {
                        TextField("Optional", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Body fat %") {
                        TextField("Optional", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Targets")
                } footer: {
                    Text("Where you're headed — no dates attached, and nothing in the app changes without you.")
                }

                Section {
                    LabeledContent("Lean mass (\(units.weightUnit))") {
                        TextField("Optional", text: $leanText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Floor")
                } footer: {
                    Text("A floor, not a target: the win is staying above it while the weight comes down.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.ground.ignoresSafeArea())
            .tint(Theme.Colors.primary)
            .navigationTitle("Body Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .onAppear(perform: prefill)
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

    private func prefill() {
        if let w = current?.weightKgTarget {
            weightText = String(format: "%.1f", units.weightInput(from: w))
        }
        if let bf = current?.bodyFatPctTarget {
            bodyFatText = String(format: "%.1f", bf)
        }
        if let l = current?.leanMassKgFloor {
            leanText = String(format: "%.1f", units.weightInput(from: l))
        }
    }

    private func parse(_ text: String) -> Double? {
        let cleaned = DecimalInput.sanitize(text.trimmingCharacters(in: .whitespaces))
        guard !cleaned.isEmpty else { return nil }
        return DecimalInput.value(from: cleaned)
    }

    // Same plausibility bands the check-in sheet uses — a typo guard, not a judgment.
    private static let weightKgRange = 20.0...500.0
    private static let bodyFatRange  = 1.0...75.0

    private func save() async {
        let weightKg = parse(weightText).map { units.kgFrom($0) }
        let bodyFat  = parse(bodyFatText)
        let leanKg   = parse(leanText).map { units.kgFrom($0) }

        for (value, label) in [(weightKg, "Weight"), (leanKg, "Lean mass")] {
            if let value, !Self.weightKgRange.contains(value) {
                errorMessage = "\(label) looks out of range. Check the value and try again."
                return
            }
        }
        if let bodyFat, !Self.bodyFatRange.contains(bodyFat) {
            errorMessage = "Body fat should be between 1% and 75%."
            return
        }

        isSaving = true
        defer { isSaving = false }
        await onSave(weightKg, bodyFat, leanKg)
        dismiss()
    }
}
