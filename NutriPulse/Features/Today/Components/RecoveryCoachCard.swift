import SwiftUI

struct RecoveryCoachCard: View {
    let opportunity: RecoveryOpportunity
    let onCloseGap: () -> Void
    let onAddWater: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.Colors.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(opportunity.hasGap ? "Feed the work" : "Recovery covered")
                        .font(Theme.Typography.headline)
                    Text("\(opportunity.workoutName) · \(opportunity.durationMinutes) min")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Text("RECOVERY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Colors.primary)
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if opportunity.hasGap {
                HStack(spacing: Theme.Spacing.sm) {
                    if opportunity.proteinGap > 0 {
                        Button("Close \(opportunity.proteinGap)g gap", action: onCloseGap)
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.Colors.primary)
                    }
                    if opportunity.waterGapMl > 0 {
                        Button("+ Water") { onAddWater(min(Double(opportunity.waterGapMl), 500)) }
                            .buttonStyle(.bordered)
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(Theme.Spacing.md)
        .background {
            LinearGradient(
                colors: [Theme.Colors.primary.opacity(0.11), Theme.Colors.surfaceCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.Colors.primary.opacity(0.22), lineWidth: 1)
        }
    }

    private var detail: String {
        if !opportunity.hasGap {
            return "Your protein floor and hydration are already handled. The session has what it needs."
        }
        let protein = opportunity.proteinGap > 0 ? "\(opportunity.proteinGap)g protein" : nil
        let water = opportunity.waterGapMl > 0 ? "\(opportunity.waterGapMl) ml water" : nil
        return "You put the work in. " + [protein, water].compactMap { $0 }.joined(separator: " and ") + " closes today's recovery gap."
    }
}

struct RepeatYesterdayCard: View {
    let meals: [(meal: Meal, itemCount: Int)]
    let busyMeal: Meal?
    let onRepeat: (Meal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Same as yesterday?")
                        .font(Theme.Typography.headline)
                    Text("Bring back a whole meal in one tap.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Theme.Colors.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(meals, id: \.meal) { entry in
                        Button {
                            onRepeat(entry.meal)
                        } label: {
                            HStack(spacing: 6) {
                                if busyMeal == entry.meal {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: entry.meal.icon)
                                }
                                Text(entry.meal.displayName)
                                Text("· \(entry.itemCount)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Theme.Colors.surfaceInset)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(busyMeal != nil)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }
}
