import SwiftUI

struct RecoveryContextCard: View {
    let context: RecoveryContext

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    TileEyebrow("Today's context", color: Theme.Colors.primaryText)
                    Text(context.headline)
                        .font(Theme.Fonts.body(17, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                Spacer()
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.primary)
            }

            ForEach(context.signals, id: \.self) { signal in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Theme.Colors.primary.opacity(0.65)).frame(width: 5, height: 5).padding(.top, 6)
                    Text(signal)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Text(context.suggestion)
                .font(Theme.Fonts.body(15, .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 2)
        }
        .tile(radius: Theme.Radius.tileSmall, padding: Theme.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}
