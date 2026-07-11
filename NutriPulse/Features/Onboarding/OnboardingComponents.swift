import SwiftUI

// Shared building blocks for the Pulse-led onboarding: the animatable ring mark, the Pulse
// avatar badge, the glowing advance arrow, progress dots, and the narrated-card shell every
// step is built on. Kept in one file so the visual language stays consistent across steps.

// MARK: - Drawable ring mark

/// The NutriPulse ring mark (indigo → violet arc to a terminal dot), with an animatable draw.
/// `drawProgress` 0→1 sweeps the arc in; `dotOpacity` fades the terminal dot. Both default to a
/// fully-drawn mark, so callers that don't animate get the static logo. Geometry mirrors
/// `PulseMark` (arc trims 0…0.694 from the top, dot sits at 160°).
struct DrawablePulseMark: View {
    var drawProgress: CGFloat = 1
    var dotOpacity: Double = 1
    var lineWidthRatio: CGFloat = 0.14

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let lw = s * lineWidthRatio
            let r = (s - lw) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let end = Angle.degrees(160)
            let dot = CGPoint(
                x: center.x + r * CGFloat(cos(end.radians)),
                y: center.y + r * CGFloat(sin(end.radians))
            )
            ZStack {
                Circle()
                    .stroke(lineWidth: lw)
                    .opacity(0.24)
                    .frame(width: 2 * r, height: 2 * r)
                    .position(center)
                Circle()
                    .trim(from: 0, to: 0.694 * drawProgress)
                    .stroke(style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 2 * r, height: 2 * r)
                    .position(center)
                Circle()
                    .frame(width: lw * 1.7, height: lw * 1.7)
                    .opacity(dotOpacity)
                    .position(dot)
            }
        }
    }
}

// MARK: - Pulse avatar badge

/// The Pulse mark on the brand gradient — the "coach is here" badge at the top of every step
/// and, larger, on the splash. Pass `drawProgress`/`dotOpacity` to animate the splash draw-in.
struct OnboardingPulseAvatar: View {
    var size: CGFloat = 46
    var drawProgress: CGFloat = 1
    var dotOpacity: Double = 1

    var body: some View {
        DrawablePulseMark(drawProgress: drawProgress, dotOpacity: dotOpacity)
            .foregroundStyle(.white)
            .padding(size * 0.29)
            .frame(width: size, height: size)
            .background(Theme.Colors.primaryGradient, in: Circle())
            .shadow(color: Theme.Colors.accent.opacity(0.4), radius: size * 0.17, y: size * 0.12)
    }
}

// MARK: - Glowing advance arrow

/// The signature advance control — a gradient circle that breathes a soft glow, replacing the
/// full-width "Continue" button. Disabled state dims and stops the pulse.
struct GlowingArrowButton: View {
    var enabled: Bool = true
    let action: () -> Void

    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.right")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(Theme.Colors.primaryGradient, in: Circle())
                .shadow(color: Theme.Colors.accent.opacity(enabled ? 0.55 : 0),
                        radius: pulsing ? 20 : 11, y: 10)
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .onAppear {
            guard !reduceMotion, enabled else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Progress dots

/// The step indicator — a row of capsules, the current one stretched. `current` is 1-based.
struct OnboardingProgressDots: View {
    let current: Int
    var total: Int = 6

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(fill(for: i))
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }

    private func fill(for i: Int) -> Color {
        if i == current { return Theme.Colors.primary }
        if i < current { return Theme.Colors.primary.opacity(0.5) }
        return Theme.Colors.hairline
    }
}

// MARK: - Narrated step shell

/// The shell every onboarding question is built on: a back control + progress dots, the Pulse
/// avatar, an optional eyebrow, the narrated question and subtitle, the step's content centered
/// in the space below, and the glowing arrow floating bottom-trailing. Back pops the nav stack.
struct NarratedStepLayout<Content: View>: View {
    let step: Int
    var totalSteps: Int = 6
    var eyebrow: String? = nil
    let question: String
    var subtitle: String? = nil
    var canAdvance: Bool = true
    let onAdvance: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Theme.Colors.ground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                            .background(Theme.Colors.surface, in: Circle())
                    }
                    .buttonStyle(.pressable)

                    OnboardingProgressDots(current: step, total: totalSteps)
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)

                OnboardingPulseAvatar(size: 46)
                    .padding(.top, 20)

                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(1.4)
                        .foregroundStyle(Theme.Colors.primary)
                        .padding(.top, 14)
                }

                Text(question)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, eyebrow == nil ? 16 : 8)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 9)
                }

                Spacer(minLength: 24)
                content()
                Spacer(minLength: 92)
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity, alignment: .leading)

            GlowingArrowButton(enabled: canAdvance, action: onAdvance)
                .padding(.trailing, 26)
                .padding(.bottom, 30)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
