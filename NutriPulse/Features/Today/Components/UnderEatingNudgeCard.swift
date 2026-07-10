import SwiftUI

// Content for the Today under-eating nudge. Built in TodayViewModel; see `nudge`.
struct DayNudge {
    let headline: String
    let body: String
    let cta: String
    let prompt: String
}

// The NutriPulse "Pulse" mark (mark-indigo.svg) drawn in SwiftUI so it tints with foreground
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

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            PulseMark()
                .foregroundStyle(.white)
                .padding(8)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(nudge.headline)
                    .font(.system(size: 14, weight: .bold))
                Text(nudge.body)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onAsk) {
                    HStack(spacing: 3) {
                        Text(nudge.cta)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 7)
            }

            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [Theme.Colors.primary.opacity(0.13), Theme.Colors.surfaceCard],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.Colors.primary.opacity(0.28), lineWidth: 1)
        }
    }
}
