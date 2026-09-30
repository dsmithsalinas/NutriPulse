import SwiftUI

// Content for the Today under-eating nudge. Built in TodayViewModel; see `nudge`.
struct DayNudge {
    let headline: String
    let body: String
    let cta: String
    let prompt: String
}


// Supportive, non-shaming prompt to finish the day strong, with the Pulse mark and a one-tap
// hand-off into the coach.
struct UnderEatingNudgeCard: View {
    let nudge: DayNudge
    // `nil` while Pulse can't actually take the hand-off (off, or not yet consented) — Today
    // hides the CTA rather than show an action that would silently do nothing. See PulseGate.
    let onAsk: (() -> Void)?

    // Daylight's Pulse strip: a white tile, the mark on a solid indigo square, and the hand-off
    // into the coach as its own full-width row.
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PulseMark()
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .frame(width: 40, height: 40)
                .background(Theme.Colors.hero, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(nudge.headline)
                    .font(Theme.Fonts.body(15, .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(nudge.body)
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onAsk {
                    Button(action: onAsk) {
                        HStack(spacing: 4) {
                            Text(nudge.cta)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .font(Theme.Fonts.body(14, .bold))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .tile(radius: Theme.Radius.tileSmall, padding: 14)
    }
}
