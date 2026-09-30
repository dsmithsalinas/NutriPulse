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
                    .background(Theme.Colors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("PREP FOR TOMORROW")
                            .font(.system(size: 10, weight: .bold)).tracking(0.8)
                            .foregroundStyle(Theme.Colors.primary)
                        Text(preparation.confidence.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Theme.Colors.primary.opacity(0.1), in: Capsule())
                    }
                    Text(preparation.headline)
                        .font(.headline)
                }
            }

            Text(preparation.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Put one small protein-dense option you already tolerate within reach today.")
                .font(.subheadline.weight(.medium))

            VStack(spacing: Theme.Spacing.xs) {
                if let onPlan {
                    Button("Plan a backup with Pulse", action: onPlan)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Colors.primary)
                        .frame(maxWidth: .infinity)
                }

                Button("I'm prepared", systemImage: "checkmark.circle", action: onPrepared)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint("Hides this preparation card and cancels its notification")
            }
        }
        .padding(Theme.Spacing.md)
        .background {
            LinearGradient(
                colors: [Theme.Colors.primary.opacity(0.12), Theme.Colors.surfaceCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.Colors.hairline) }
    }
}

struct ShotCycleCheckInCard: View {
    let cycleDay: Int
    let onCheckIn: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.Colors.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("POST-SHOT CHECK-IN")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.Colors.primary)
                    Text("How are you feeling after your shot?")
                        .font(Theme.Typography.headline)
                }

                Spacer()

                Text("DAY \(cycleDay)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.primary.opacity(0.1), in: Capsule())
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.sm) {
                Button("Check in", action: onCheckIn)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colors.primary)

                Button("Not now", action: onNotNow)
                    .buttonStyle(.bordered)
                    .accessibilityHint("Hides this check-in for today")
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(Theme.Spacing.md)
        .background {
            LinearGradient(
                colors: [Theme.Colors.primary.opacity(0.12), Theme.Colors.surfaceCard],
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
