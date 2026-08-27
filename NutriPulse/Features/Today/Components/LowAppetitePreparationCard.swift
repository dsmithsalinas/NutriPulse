import SwiftUI

struct LowAppetitePreparationCard: View {
    let preparation: LowAppetitePreparation
    let onPlan: () -> Void
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
                Button("Plan a backup with Pulse", action: onPlan)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)

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
