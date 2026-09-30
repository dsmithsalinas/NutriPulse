import SwiftUI

// Shown once, before Pulse ever sends anything to the AI provider: when
// `PulseProfileStore.needsConsent` is true and the user opens the Pulse tab, or something asks
// Pulse a question from elsewhere in the app (a Today nudge, a goal question, "Ask Pulse about
// today" — see `PulseGate.Handoff` and `AppState.pendingCoachPrompt`). Also reopened read-only
// (or to opt back in) from Profile's "AI data sharing" row.
//
// Daylight sheet styling to match ShotCycleCheckInSheet: SheetHeader, white tiles on the cool
// neutral ground, a lime primary action.
struct PulseConsentSheet: View {
    /// Turns Pulse on and records consent. `nil` for the read-only presentation (already agreed).
    var onAgree: (() async -> Void)? = nil
    /// Declines — turns Pulse off. `nil` outside the forced first-ask (see `title`).
    var onDecline: (() async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false

    // "Not now" only exists on the forced first-ask (declining there is a real decision — it
    // turns Pulse off). Reopened from Profile there's nothing to decline: it's either read-only
    // (already agreed) or a lone way back in (declined earlier), so the title reads as the
    // settings row it came from rather than a fresh ask.
    private var title: String { onDecline != nil ? "Before Pulse replies" : "AI data sharing" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SheetHeader(title: title, onClose: { dismiss() })

                VStack(alignment: .leading, spacing: 10) {
                    Text("To write a reply, Pulse sends some of your Footing data to Anthropic, the company whose AI model it runs on:")
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        bullet("Your name and goals")
                        bullet("Your food logs and recent history")
                        bullet("Shot-cycle and dose info")
                        bullet("Health summaries — sleep, heart-rate variability, and workouts, when connected")
                        bullet("What you say in the Pulse tab")
                        bullet("What you've told Pulse about yourself — allergies, food preferences, and the rest of \u{201c}What Pulse knows\u{201d}")
                    }
                }
                .tile()

                Text("This is used only to write Pulse's replies. You can turn Pulse off any time in Profile.")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text("Talk to Log's food parsing also uses AI to read what you type or say. That's separate from this setting and keeps working either way.")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textFaint)

                Link("Privacy Policy", destination: Config.privacyPolicyURL)
                    .font(Theme.Fonts.body(14, .semibold))
                    .foregroundStyle(Theme.Colors.primary)

                if onAgree != nil || onDecline != nil {
                    VStack(spacing: Theme.Spacing.sm) {
                        if let onAgree { agreeButton(action: onAgree) }
                        if let onDecline { declineButton(action: onDecline) }
                    }
                }
            }
            .padding(Theme.Spacing.page)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .interactiveDismissDisabled(isWorking)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.Colors.primary)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private func agreeButton(action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                isWorking = true
                await action()
                isWorking = false
            }
        } label: {
            Group {
                if isWorking {
                    ProgressView().tint(Theme.Colors.limeInk)
                } else {
                    Text("Turn on Pulse")
                        .font(Theme.Fonts.body(16, .bold))
                }
            }
            .foregroundStyle(Theme.Colors.limeInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.Colors.lime, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(.pressable)
        .disabled(isWorking)
        .accessibilityHint("Sends your Footing data to Anthropic so Pulse can reply")
    }

    private func declineButton(action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                isWorking = true
                await action()
                isWorking = false
            }
        } label: {
            Text("Not now")
                .font(Theme.Fonts.body(15, .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityHint("Turns Pulse off")
    }
}

#Preview("Pulse consent") {
    PulseConsentSheet(onAgree: {}, onDecline: {})
}

#Preview("AI data sharing (already agreed)") {
    PulseConsentSheet()
}
