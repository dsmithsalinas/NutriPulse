import SwiftUI

// A warm, on-brand empty state: a gradient-glyph medallion with an encouraging title and one
// line of guidance. Used wherever a screen has nothing to show yet, so "empty" reads as an
// invitation, not a dead end. The medallion breathes gently to keep the screen feeling alive.
struct BrandedEmptyState: View {
    let icon: String
    let title: String
    let message: String

    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.12))
                    .frame(width: 66, height: 66)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Theme.Colors.primaryGradient)
            }
            .scaleEffect(breathe ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                       value: breathe)
            .onAppear { breathe = true }

            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.md)
    }
}
