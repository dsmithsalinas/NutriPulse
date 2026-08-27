import SwiftUI

struct RecoveryContextCard: View {
    let context: RecoveryContext

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TODAY'S CONTEXT")
                        .font(.system(size: 10, weight: .bold)).tracking(0.8)
                        .foregroundStyle(Theme.Colors.primary)
                    Text(context.headline).font(.headline)
                }
                Spacer()
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.title2).foregroundStyle(Theme.Colors.primary)
            }

            ForEach(context.signals, id: \.self) { signal in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Theme.Colors.primary.opacity(0.65)).frame(width: 5, height: 5).padding(.top, 6)
                    Text(signal).font(.caption).foregroundStyle(.secondary)
                }
            }

            Text(context.suggestion)
                .font(.subheadline.weight(.medium))
                .padding(.top, 2)
        }
        .padding(Theme.Spacing.md)
        .background {
            LinearGradient(
                colors: [Theme.Colors.primary.opacity(0.11), Theme.Colors.surfaceCard],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.Colors.hairline) }
        .accessibilityElement(children: .combine)
    }
}
