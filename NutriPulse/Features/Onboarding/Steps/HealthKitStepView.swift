import SwiftUI

struct HealthKitStepView: View {
    let onContinue: () -> Void

    @State private var isConnecting = false
    @State private var isConnected = false

    var body: some View {
        OnboardingStepLayout(
            step: 7,
            title: "Connect Apple Health",
            subtitle: "Pulse reads your activity and recovery data to give smarter coaching.",
            continueLabel: "Continue",
            onContinue: onContinue
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(dataPoints, id: \.label) { item in
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: item.icon)
                            .font(.title3)
                            .foregroundStyle(item.color)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.subheadline.weight(.medium))
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if isConnected {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Apple Health connected")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Button {
                        isConnecting = true
                        Task {
                            try? await HealthKitManager.shared.requestAuthorization()
                            isConnected = HealthKitManager.shared.isAvailable
                            isConnecting = false
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            if isConnecting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "heart.fill")
                            }
                            Text(isConnecting ? "Requesting…" : "Connect Apple Health")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isConnecting)
                }

                Text("You can always adjust permissions later in Settings → Privacy → Health.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private struct DataPoint {
        let icon: String
        let color: Color
        let label: String
        let detail: String
    }

    private let dataPoints: [DataPoint] = [
        .init(icon: "flame.fill",        color: .orange, label: "Active Calories",          detail: "Counts toward your net calorie goal"),
        .init(icon: "moon.zzz.fill",     color: .indigo, label: "Sleep",                    detail: "Recovery data used by Pulse in coaching"),
        .init(icon: "heart.fill",        color: .red,    label: "Resting HR & HRV",         detail: "Signals for recovery and stress levels"),
        .init(icon: "scalemass.fill",    color: .blue,   label: "Weight",                   detail: "Syncs weigh-ins you log in NutriPulse"),
    ]
}
