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
    // What the fields opened with, so an untouched field saves its stored value exactly.
    @State private var opened = BodyGoalsFields()
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
                    DaylightSectionHeader("Targets")
                } footer: {
                    DaylightSectionFooter("Where you're headed — no dates attached, and nothing in the app changes without you.")
                }
                .daylightSection()

                Section {
                    LabeledContent("Lean mass (\(units.weightUnit))") {
                        TextField("Optional", text: $leanText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    DaylightSectionHeader("Floor")
                } footer: {
                    DaylightSectionFooter("A floor, not a target: the win is staying above it while the weight comes down.")
                }
                .daylightSection()
            }
            .daylightForm()
            .navigationTitle("Body Goals")
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
        opened = BodyGoalsFields(goals: current, units: units)
        weightText = opened.weight
        bodyFatText = opened.bodyFat
        leanText = opened.lean
    }

    // Same plausibility bands the check-in sheet uses — a typo guard, not a judgment.
    private static let weightKgRange = 20.0...500.0
    private static let bodyFatRange  = 1.0...75.0

    private func save() async {
        let typed = BodyGoalsFields(weight: weightText, bodyFat: bodyFatText, lean: leanText)
        let changed = typed.changed(from: opened)
        let (weightKg, bodyFat, leanKg) = typed.values(opened: opened, stored: current, units: units)

        // Only what the user changed is checked; untouched values were checked when saved.
        for (value, label, isChanged) in [(weightKg, "Weight", changed.weight), (leanKg, "Lean mass", changed.lean)] {
            if isChanged, let value, !Self.weightKgRange.contains(value) {
                errorMessage = "\(label) looks out of range. Check the value and try again."
                return
            }
        }
        if changed.bodyFat, let bodyFat, !Self.bodyFatRange.contains(bodyFat) {
            errorMessage = "Body fat should be between 1% and 75%."
            return
        }

        isSaving = true
        defer { isSaving = false }
        await onSave(weightKg, bodyFat, leanKg)
        dismiss()
    }
}

/// The goals sheet's three fields as typed, in the user's units ("" when unset).
struct BodyGoalsFields: Equatable {
    var weight = ""
    var bodyFat = ""
    var lean = ""

    init(weight: String = "", bodyFat: String = "", lean: String = "") {
        self.weight = weight
        self.bodyFat = bodyFat
        self.lean = lean
    }

    /// The prefill: stored goals shown to one decimal in the user's units.
    init(goals: BodyGoals?, units: UnitSystem) {
        weight = goals?.weightKgTarget.map { String(format: "%.1f", units.weightInput(from: $0)) } ?? ""
        bodyFat = goals?.bodyFatPctTarget.map { String(format: "%.1f", $0) } ?? ""
        lean = goals?.leanMassKgFloor.map { String(format: "%.1f", units.weightInput(from: $0)) } ?? ""
    }

    func changed(from opened: BodyGoalsFields) -> (weight: Bool, bodyFat: Bool, lean: Bool) {
        (Self.trim(weight) != opened.weight, Self.trim(bodyFat) != opened.bodyFat, Self.trim(lean) != opened.lean)
    }

    /// What to save, in storage units. A field left as it opened keeps its stored value exactly
    /// (172.0 lb shown for 78 kg is never written back as 78.018 kg; 28.25% isn't rounded to
    /// 28.3); a changed field is parsed, and a cleared one removes that goal.
    func values(opened: BodyGoalsFields, stored: BodyGoals?, units: UnitSystem)
        -> (weightKg: Double?, bodyFatPct: Double?, leanKg: Double?) {
        let changed = changed(from: opened)
        return (
            changed.weight ? Self.parse(weight).map { units.kgFrom($0) } : stored?.weightKgTarget,
            changed.bodyFat ? Self.parse(bodyFat) : stored?.bodyFatPctTarget,
            changed.lean ? Self.parse(lean).map { units.kgFrom($0) } : stored?.leanMassKgFloor
        )
    }

    private static func trim(_ text: String) -> String { text.trimmingCharacters(in: .whitespaces) }

    private static func parse(_ text: String) -> Double? {
        let cleaned = DecimalInput.sanitize(trim(text))
        guard !cleaned.isEmpty else { return nil }
        return DecimalInput.value(from: cleaned)
    }
}
