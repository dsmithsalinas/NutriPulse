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
    var onAgree: (() async throws -> Void)? = nil
    /// Declines — turns Pulse off. `nil` outside the forced first-ask (see `title`).
    var onDecline: (() async throws -> Void)? = nil
    var onRevoke: (() async throws -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var owner = PulseProfileStore.shared.accountId

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
                        bullet("Your first name, units, goals, and weight trend")
                        bullet("Your food logs, recent history, meal notes, and qualitative breakfast check-ins")
                        bullet("Shot-cycle and dose info")
                        bullet("Health summaries — sleep, heart-rate variability, and workouts, when connected")
                        bullet("What you say in the Pulse tab")
                        bullet("What you've told Pulse about yourself — allergies, food preferences, and the rest of \u{201c}What Pulse knows\u{201d}")
                        bullet("Practical memories you approved, lighter-tracking context you chose, and your goals, experiments, or Strong Week answers when relevant")
                    }
                }
                .tile()

                Text("Footing sends it only so Pulse can write its replies. You can turn Pulse off any time in Profile.")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text("AI food logging asks for its own permission before sending a food description to Anthropic. You can manage it separately in Profile → AI food logging.")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textFaint)

                Link("Privacy Policy", destination: Config.privacyPolicyURL)
                    .font(Theme.Fonts.body(14, .semibold))
                    .foregroundStyle(Theme.Colors.primary)

                if let errorMessage {
                    Text(errorMessage).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger)
                }
                if onAgree != nil || onDecline != nil {
                    VStack(spacing: Theme.Spacing.sm) {
                        if let onAgree { agreeButton(action: onAgree) }
                        if let onDecline { declineButton(action: onDecline) }
                    }
                }
                if let onRevoke {
                    Button("Withdraw Pulse AI permission", role: .destructive) {
                        perform(onRevoke)
                    }
                    .font(Theme.Fonts.body(15, .semibold))
                    .disabled(isWorking)
                }
            }
            .padding(Theme.Spacing.page)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .interactiveDismissDisabled(isWorking)
        .onChange(of: PulseProfileStore.shared.accountId) { _, _ in dismiss() }
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

    private func perform(_ action: @escaping () async throws -> Void) {
        guard owner != nil, owner == PulseProfileStore.shared.accountId else { dismiss(); return }
        isWorking = true; errorMessage = nil
        Task {
            defer { isWorking = false }
            do { try await action() }
            catch { errorMessage = "Couldn’t save your choice. Check your connection and try again." }
        }
    }

    private func agreeButton(action: @escaping () async throws -> Void) -> some View {
        Button {
            perform(action)
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

    private func declineButton(action: @escaping () async throws -> Void) -> some View {
        Button {
            perform(action)
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
