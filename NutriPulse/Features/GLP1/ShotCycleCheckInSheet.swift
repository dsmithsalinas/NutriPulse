import SwiftUI

// Daylight sheet styling (docs/daylight-redesign.md): SheetHeader, white tiles on the cool
// neutral ground, lime accents for the save action. Opened from Today's shot-cycle tile; the
// check-in logic (draft, save, prefill from an existing entry) is unchanged.
struct ShotCycleCheckInSheet: View {
    let cycleDay: Int
    let existing: ShotCycleCheckIn?
    let onSave: (ShotCycleCheckInDraft) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ShotCycleCheckInDraft()
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SheetHeader(title: "Day \(cycleDay) check-in", onClose: { dismiss() })

                Text("Five quick signals help Footing learn your pattern. This tracks your experience; it doesn\u{2019}t change or recommend your dose.")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.textSecondary)

                CheckInScale(label: "Appetite", low: "Low", high: "High", value: $draft.appetite)
                CheckInScale(label: "Fullness", low: "Empty", high: "Very full", value: $draft.fullness)
                CheckInScale(label: "Nausea", low: "None", high: "Strong", value: $draft.nausea)
                CheckInScale(label: "Energy", low: "Low", high: "High", value: $draft.energy)
                CheckInScale(label: "Digestion", low: "Unsettled", high: "Comfortable", value: $draft.digestion)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Anything worth remembering?")
                        .font(Theme.Fonts.body(15, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    TextField("Optional note", text: $draft.note, axis: .vertical)
                        .font(Theme.Fonts.body(15))
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .tile()

                saveButton
            }
            .padding(Theme.Spacing.page)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
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

    private var saveButton: some View {
        Button {
            Task {
                isSaving = true
                if await onSave(draft) { dismiss() }
                isSaving = false
            }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(Theme.Colors.limeInk)
                } else {
                    Text(existing == nil ? "Save check-in" : "Update check-in")
                        .font(Theme.Fonts.body(16, .bold))
                }
            }
            .foregroundStyle(Theme.Colors.limeInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.Colors.lime, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(.pressable)
        .disabled(isSaving)
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
                Text(label)
                    .font(Theme.Fonts.body(15, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(value) / 5")
                    .font(Theme.Fonts.body(13, .bold))
                    .foregroundStyle(Theme.Colors.limeLine)
            }
            Picker(label, selection: $value) {
                ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .tint(Theme.Colors.limeInk)
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(Theme.Fonts.body(11, .medium))
            .foregroundStyle(Theme.Colors.textFaint)
        }
        .tile()
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
                    .font(Theme.Fonts.body(13, .semibold, relativeTo: .caption))
                    .buttonStyle(.bordered)
            }

            if let pattern = plan.learnedPattern {
                Label(pattern, systemImage: "point.3.connected.trianglepath.dotted")
                    .font(Theme.Fonts.body(13, relativeTo: .caption))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            ForEach(Array(plan.actions.enumerated()), id: \.offset) { index, action in
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Text("\(index + 1)")
                        .font(Theme.Fonts.body(11, .bold, relativeTo: .caption2))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Theme.Colors.primary, in: Circle())
                    Text(action)
                        .font(Theme.Fonts.body(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }
}
