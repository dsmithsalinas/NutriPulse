import SwiftUI

// A warm, on-brand empty state: a soft indigo glyph tile with an encouraging title and one
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
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.Colors.primarySoft)
                    .frame(width: 66, height: 66)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            .scaleEffect(breathe ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                       value: breathe)
            .onAppear { breathe = true }

            Text(title)
                .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 4)
            Text(message)
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.md)
    }
}
