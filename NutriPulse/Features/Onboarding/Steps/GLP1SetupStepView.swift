import SwiftUI

struct GLP1SetupStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepLayout(
            step: 8,
            title: "GLP-1 medication",
            subtitle: "Pulse tracks your injection schedule and factors it into coaching. You can skip this and set it up later in Profile.",
            onContinue: onContinue
        ) {
            VStack(spacing: Theme.Spacing.lg) {
                Picker("", selection: $vm.isOnGLP1) {
                    Text("I'm on a GLP-1").tag(true)
                    Text("Skip for now").tag(false)
                }
                .pickerStyle(.segmented)

                if vm.isOnGLP1 {
                    VStack(spacing: Theme.Spacing.md) {
                        // Medication
                        LabeledPicker(label: "Medication") {
                            Picker("Medication", selection: $vm.glp1Medication) {
                                ForEach(GLP1Medication.allCases) { med in
                                    Text(med.rawValue).tag(med)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 110)
                            .clipped()
                        }
                        .onChange(of: vm.glp1Medication) { _, med in
                            vm.glp1DoseMg = med.availableDoses.first ?? 0.5
                        }

                        // Dose
                        LabeledPicker(label: "Dose") {
                            Picker("Dose", selection: $vm.glp1DoseMg) {
                                ForEach(vm.glp1Medication.availableDoses, id: \.self) { dose in
                                    Text(String(format: "%.2g mg", dose)).tag(dose)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 110)
                            .clipped()
                        }

                        // Last injection
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Last injection date")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            DatePicker(
                                "Last injection",
                                selection: $vm.glp1LastInjected,
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.35), value: vm.isOnGLP1)
        }
    }
}

private struct LabeledPicker<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content
                .padding(.horizontal)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
