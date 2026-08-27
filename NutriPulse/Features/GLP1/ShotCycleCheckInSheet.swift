import SwiftUI

struct ShotCycleCheckInSheet: View {
    let cycleDay: Int
    let existing: ShotCycleCheckIn?
    let onSave: (ShotCycleCheckInDraft) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ShotCycleCheckInDraft()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day \(cycleDay) check-in")
                            .font(Theme.Typography.title)
                        Text("Five quick signals help Footing learn your pattern. This tracks your experience; it doesn't change or recommend your dose.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    CheckInScale(label: "Appetite", low: "Low", high: "High", value: $draft.appetite)
                    CheckInScale(label: "Fullness", low: "Empty", high: "Very full", value: $draft.fullness)
                    CheckInScale(label: "Nausea", low: "None", high: "Strong", value: $draft.nausea)
                    CheckInScale(label: "Energy", low: "Low", high: "High", value: $draft.energy)
                    CheckInScale(label: "Digestion", low: "Unsettled", high: "Comfortable", value: $draft.digestion)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Anything worth remembering?")
                            .font(.subheadline.weight(.semibold))
                        TextField("Optional note", text: $draft.note, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(Theme.Colors.surfaceInset)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        Task {
                            isSaving = true
                            if await onSave(draft) { dismiss() }
                            isSaving = false
                        }
                    } label: {
                        if isSaving { ProgressView().tint(.white) }
                        else { Text(existing == nil ? "Save check-in" : "Update check-in") }
                    }
                    .buttonStyle(.brandPrimary)
                    .disabled(isSaving)
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationTitle("How are you feeling?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            guard let existing else { return }
            draft = ShotCycleCheckInDraft(
                appetite: existing.appetite,
                fullness: existing.fullness,
                nausea: existing.nausea,
                energy: existing.energy,
                digestion: existing.digestion,
                note: existing.note ?? ""
            )
        }
    }
}

private struct CheckInScale: View {
    let label: String
    let low: String
    let high: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(label).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value) / 5")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primary)
            }
            Picker(label, selection: $value) {
                ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption2)
            .foregroundStyle(Theme.Colors.textFaint)
        }
        .padding(Theme.Spacing.md)
        .card()
    }
}

struct ShotCyclePlanCard: View {
    let plan: ShotCyclePlan
    let hasCheckIn: Bool
    let onCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.phase.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(Theme.Colors.primary)
                    Text(plan.headline)
                        .font(Theme.Typography.headline)
                }
                Spacer()
                Button(hasCheckIn ? "Update" : "Check in", action: onCheckIn)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
            }

            if let pattern = plan.learnedPattern {
                Label(pattern, systemImage: "waveform.path.ecg")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            ForEach(Array(plan.actions.enumerated()), id: \.offset) { index, action in
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Theme.Colors.primary, in: Circle())
                    Text(action)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }
}
