import SwiftUI

struct HealthKitStepView: View {
    let onContinue: () -> Void

    @State private var isConnecting = false
    // nil = haven't asked yet. Set from the *outcome* of the request, not from
    // isHealthDataAvailable() — which is a device capability and true on every iPhone, so
    // denying every permission still produced a green "Apple Health connected" checkmark.
    @State private var didGrantAccess: Bool? = nil

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

                if let didGrantAccess {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: didGrantAccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(didGrantAccess ? .green : .orange)
                        Text(didGrantAccess
                             ? "Apple Health connected"
                             : "No Health access granted — you can enable it later in the Health app")
                            .fontWeight(.medium)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((didGrantAccess ? Color.green : Color.orange).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Button {
                        isConnecting = true
                        Task {
                            try? await HealthKitManager.shared.requestAuthorization()
                            // HealthKit never discloses read grants, so this reflects write
                            // access. A reads-only grant reads as "not connected" here —
                            // wrong, but far rarer than the deny-everything case this
                            // catches, and it no longer claims a connection that isn't there.
                            didGrantAccess = HealthKitManager.shared.isSharingAuthorized
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
