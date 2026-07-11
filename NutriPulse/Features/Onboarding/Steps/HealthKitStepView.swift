import SwiftUI

struct HealthKitStepView: View {
    let onContinue: () -> Void

    @State private var isConnecting = false
    // nil = haven't asked yet. Set from the *outcome* of the request, not from
    // isHealthDataAvailable() — a device capability true on every iPhone, so denying every
    // permission would otherwise still show a green "connected" state.
    @State private var didGrantAccess: Bool? = nil

    var body: some View {
        NarratedStepLayout(
            step: 7,
            question: "Want to connect Apple Health?",
            subtitle: "It lets me factor your activity, sleep, and recovery into coaching.",
            onAdvance: onContinue
        ) {
            VStack(spacing: 10) {
                ForEach(dataPoints, id: \.label) { item in
                    HStack(spacing: 14) {
                        Image(systemName: item.icon)
                            .font(.system(size: 17))
                            .foregroundStyle(item.color)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.system(size: 15, weight: .medium))
                            Text(item.detail)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let didGrantAccess {
                    HStack(spacing: 8) {
                        Image(systemName: didGrantAccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(didGrantAccess ? .green : .orange)
                        Text(didGrantAccess
                             ? "Apple Health connected"
                             : "No Health access granted — you can enable it later in the Health app.")
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((didGrantAccess ? Color.green : Color.orange).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Button(action: connect) {
                        HStack(spacing: 8) {
                            if isConnecting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "heart.fill")
                            }
                            Text(isConnecting ? "Requesting…" : "Connect Apple Health")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.Colors.primaryGradient,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.pressable)
                    .disabled(isConnecting)
                    .padding(.top, 2)
                }
            }
        }
    }

    private func connect() {
        isConnecting = true
        Task {
            try? await HealthKitManager.shared.requestAuthorization()
            // HealthKit never discloses read grants, so this reflects write access — a
            // reads-only grant reads as "not connected", rarer than the deny-everything case.
            didGrantAccess = HealthKitManager.shared.isSharingAuthorized
            isConnecting = false
        }
    }

    private struct DataPoint {
        let icon: String
        let color: Color
        let label: String
        let detail: String
    }

    private let dataPoints: [DataPoint] = [
        .init(icon: "flame.fill",     color: .orange, label: "Active calories",     detail: "Counts toward your net calorie goal"),
        .init(icon: "moon.zzz.fill",  color: .indigo, label: "Sleep",               detail: "Recovery data Pulse uses in coaching"),
        .init(icon: "heart.fill",     color: .red,    label: "Resting HR & HRV",    detail: "Signals for recovery and stress"),
        .init(icon: "scalemass.fill", color: .blue,   label: "Weight",              detail: "Syncs weigh-ins you log in NutriPulse"),
    ]
}
