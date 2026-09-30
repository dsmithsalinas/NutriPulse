import SwiftUI

// Content for the Today under-eating nudge. Built in TodayViewModel; see `nudge`.
struct DayNudge {
    let headline: String
    let body: String
    let cta: String
    let prompt: String
}

// The Footing "Pulse" mark (mark-indigo.svg) drawn in SwiftUI so it tints with foreground
// style — a track ring, a ~250° progress arc, and the dot where the arc ends.
struct PulseMark: View {
    var lineWidthRatio: CGFloat = 0.14

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let lw = s * lineWidthRatio
            let r = (s - lw) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            // The arc (trim 0…0.694 from the top, clockwise) ends at 160°; the dot sits there.
            let end = Angle.degrees(160)
            let dot = CGPoint(
                x: center.x + r * CGFloat(cos(end.radians)),
                y: center.y + r * CGFloat(sin(end.radians))
            )
            ZStack {
                Circle()
                    .stroke(lineWidth: lw)
                    .opacity(0.28)
                    .frame(width: 2 * r, height: 2 * r)
                    .position(center)
                Circle()
                    .trim(from: 0, to: 0.694)
                    .stroke(style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 2 * r, height: 2 * r)
                    .position(center)
                Circle()
                    .frame(width: lw * 1.7, height: lw * 1.7)
                    .position(dot)
            }
        }
    }
}

// Supportive, non-shaming prompt to finish the day strong, with the Pulse mark and a one-tap
// hand-off into the coach.
struct UnderEatingNudgeCard: View {
    let nudge: DayNudge
    let onAsk: () -> Void

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

            Spacer(minLength: 0)
        }
        .tile(radius: Theme.Radius.tileSmall, padding: 14)
    }
}
