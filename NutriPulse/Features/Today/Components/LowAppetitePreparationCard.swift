import SwiftUI

struct LowAppetitePreparationCard: View {
    let preparation: LowAppetitePreparation
    // `nil` while Pulse can't take the hand-off (off, or not yet consented) — hides the "Plan a
    // backup with Pulse" button and keeps "I'm prepared", which never leaves the device. See
    // PulseGate.
    let onPlan: (() -> Void)?
    let onPrepared: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 42, height: 42)
                    .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        TileEyebrow("Prep for tomorrow", color: Theme.Colors.primaryText)
                        Text(preparation.confidence.rawValue)
                            .font(Theme.Fonts.body(9, .bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Theme.Colors.primarySoft, in: Capsule())
                            .foregroundStyle(Theme.Colors.primaryText)
                    }
                    Text(preparation.headline)
                        .font(Theme.Fonts.body(17, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }

            Text(preparation.detail)
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Colors.textSecondary)

            Text("Put one small protein-dense option you already tolerate within reach today.")
                .font(Theme.Fonts.body(15, .medium))
                .foregroundStyle(Theme.Colors.textPrimary)

            VStack(spacing: Theme.Spacing.xs) {
                if let onPlan {
                    Button("Plan a backup with Pulse", action: onPlan)
                        .buttonStyle(.brandPrimary)
                }

                Button("I'm prepared", systemImage: "checkmark.circle", action: onPrepared)
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                    .accessibilityHint("Hides this preparation card and cancels its notification")
            }
        }
        .tile(radius: Theme.Radius.tileSmall, padding: Theme.Spacing.md)
    }
}

struct ShotCycleCheckInCard: View {
    let cycleDay: Int
    let onCheckIn: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.lime)
                    .frame(width: 38, height: 38)
                    .background(Theme.Colors.limeInk, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    TileEyebrow("Post-shot check-in", color: Theme.Colors.limeLabel)
                    Text("How are you feeling after your shot?")
                        .font(Theme.Fonts.body(17, .bold))
                        .foregroundStyle(Theme.Colors.limeInk)
                }

                Spacer()

                Text("Day \(cycleDay)")
                    .font(Theme.Fonts.body(10, .bold))
                    .foregroundStyle(Theme.Colors.limeInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.limeInk.opacity(0.1), in: Capsule())
            }

            Text(detail)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.limeLabel)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.sm) {
                Button("Check in", action: onCheckIn)
                    .font(Theme.Fonts.body(14, .bold))
                    .foregroundStyle(Theme.Colors.lime)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Theme.Colors.limeInk, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))

                Button("Not now", action: onNotNow)
                    .font(Theme.Fonts.body(14, .bold))
                    .foregroundStyle(Theme.Colors.limeInk)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Theme.Colors.limeInk.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                    .accessibilityHint("Hides this check-in for today")
            }
        }
        .tile(Theme.Colors.lime, radius: Theme.Radius.tileSmall, padding: Theme.Spacing.md, shadow: false)
    }

    private var detail: String {
        switch cycleDay {
        case 1:
            "A 30-second check-in captures the early part of this shot cycle."
        case 3:
            "Check appetite, fullness, nausea, energy, and digestion as the week settles in."
        case 6:
            "One last check-in helps compare how you feel near the end of this shot cycle."
        default:
            "Five quick signals help Footing learn your shot-cycle pattern."
        }
    }
}
