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
                    .background(Theme.Colors.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(opportunity.hasGap ? "Feed the work" : "Recovery covered")
                        .font(Theme.Fonts.body(17, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(opportunity.workoutName) \u{00B7} \(opportunity.durationMinutes) min")
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                TileEyebrow("Recovery", color: Theme.Colors.primaryText)
            }

            Text(detail)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if opportunity.hasGap {
                HStack(spacing: Theme.Spacing.sm) {
                    if opportunity.proteinGap > 0 {
                        Button("Close \(opportunity.proteinGap)g gap", action: onCloseGap)
                            .font(Theme.Fonts.body(14, .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(Theme.Colors.primary, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                    }
                    if opportunity.waterGapMl > 0 {
                        Button("+ Water") { onAddWater(min(Double(opportunity.waterGapMl), 500)) }
                            .font(Theme.Fonts.body(14, .semibold))
                            .foregroundStyle(Theme.Colors.skyAction)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(Theme.Colors.sky, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                    }
                }
            }
        }
        .tile(radius: Theme.Radius.tileSmall, padding: Theme.Spacing.md)
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
                        .font(Theme.Fonts.body(17, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Bring back a whole meal in one tap.")
                        .font(Theme.Fonts.body(13))
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
                                Text("\u{00B7} \(entry.itemCount)")
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .font(Theme.Fonts.body(14, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Theme.Colors.surfaceInset, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(busyMeal != nil)
                    }
                }
            }
        }
        .tile(radius: Theme.Radius.tileSmall, padding: Theme.Spacing.md)
    }
}
