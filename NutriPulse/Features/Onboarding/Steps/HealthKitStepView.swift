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
                                .font(Theme.Fonts.body(15, .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(item.detail)
                                .font(Theme.Fonts.body(13))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
                    }
                }

                if let didGrantAccess {
                    HStack(spacing: 8) {
                        Image(systemName: didGrantAccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(didGrantAccess ? Theme.Colors.limeLine : Theme.NutrientColor.fat)
                        Text(didGrantAccess
                             ? "Apple Health connected"
                             : "No Health access granted — you can enable it later in the Health app.")
                            .font(Theme.Fonts.body(14, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((didGrantAccess ? Theme.Colors.lime : Theme.NutrientColor.fat).opacity(didGrantAccess ? 0.4 : 0.12),
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
                        }
                    }
                    .buttonStyle(.brandPrimary)
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
        .init(icon: "flame.fill",     color: Theme.NutrientColor.calories, label: "Active calories",  detail: "Counts toward your net calorie goal"),
        .init(icon: "moon.zzz.fill",  color: Theme.Colors.primary,         label: "Sleep",             detail: "Recovery data Pulse uses in coaching"),
        .init(icon: "heart.fill",     color: Theme.Colors.listening,       label: "Resting HR & HRV",  detail: "Signals for recovery and stress"),
        .init(icon: "scalemass.fill", color: Theme.NutrientColor.water,    label: "Weight",            detail: "Syncs weigh-ins you log in Footing"),
    ]
}
