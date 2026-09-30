import SwiftUI

// Shared Daylight building blocks for onboarding and sign-in: the animatable ring mark, the
// Pulse avatar badge, the primary Continue button, progress dots, and the narrated-step shell
// every step is built on. Kept in one file so the visual language stays consistent across steps.
// (Also used by Features/Auth, the other half of "the first thing new users see".)

// Continue and other CTAs use the app-wide `.brandPrimary` (Theme.swift).

// MARK: - Drawable ring mark

/// The Footing ring mark (indigo → violet arc to a terminal dot), with an animatable draw.
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

/// The Pulse mark on a flat indigo fill — the "coach is here" badge at the top of every step
/// and, larger, on the splash. Pass `drawProgress`/`dotOpacity` to animate the splash draw-in.
/// Daylight fills are flat (Theme.swift), so this uses `hero` rather than the retired gradient.
struct OnboardingPulseAvatar: View {
    var size: CGFloat = 46
    var drawProgress: CGFloat = 1
    var dotOpacity: Double = 1

    var body: some View {
        DrawablePulseMark(drawProgress: drawProgress, dotOpacity: dotOpacity)
            .foregroundStyle(.white)
            .padding(size * 0.29)
            .frame(width: size, height: size)
            .background(Theme.Colors.hero, in: Circle())
    }
}

// MARK: - Progress dots

/// The Daylight step indicator — a row of capsules, the current one stretched indigo.
/// `current` is 1-based.
struct OnboardingProgressDots: View {
    let current: Int
    var total: Int = 9

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(fill(for: i))
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }

    private func fill(for i: Int) -> Color {
        if i == current { return Theme.Colors.primary }
        if i < current { return Theme.Colors.primary.opacity(0.5) }
        return Theme.Colors.hairline
    }
}

// MARK: - Narrated step shell

/// The shell every onboarding question is built on: a back control + Daylight progress dots, the
/// Pulse avatar, an optional eyebrow, a big Bricolage question with a Figtree helper line, the
/// step's content, and a pinned Continue button. Back pops the nav stack. Everything above the
/// button pops in with `.popIn` on first appear.
struct NarratedStepLayout<Content: View>: View {
    let step: Int
    var totalSteps: Int = 9
    var eyebrow: String? = nil
    var eyebrowGlow: Bool = false
    let question: String
    var subtitle: String? = nil
    var canAdvance: Bool = true
    var continueTitle: String = "Continue"
    let onAdvance: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.Colors.ground.ignoresSafeArea()
            if eyebrowGlow {
                OnboardingAuroraWash().ignoresSafeArea()
            }

            VStack(alignment: .leading, spacing: 0) {
                // Fixed top bar — back + progress dots stay put while content below can scroll.
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.Colors.surfaceCard, in: Circle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Back")

                    OnboardingProgressDots(current: step, total: totalSteps)
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
                .padding(.horizontal, Theme.Spacing.page)

                // Content region: centered when short, scrolls when it overflows.
                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            OnboardingPulseAvatar(size: 46)
                                .padding(.top, 20)
                                .popIn(order: 0)

                            if let eyebrow {
                                Text(eyebrow.uppercased())
                                    .font(Theme.Fonts.body(12, .bold))
                                    .tracking(Theme.Typography.eyebrowTracking)
                                    .foregroundStyle(Theme.Colors.primaryText)
                                    .padding(.top, 14)
                                    .popIn(order: 1)
                            }

                            Text(question)
                                .font(Theme.Fonts.display(28, .extraBold, relativeTo: .title))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, eyebrow == nil ? 16 : 8)
                                .accessibilityAddTraits(.isHeader)
                                .popIn(order: 1)

                            if let subtitle {
                                Text(subtitle)
                                    .font(Theme.Fonts.body(15))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 9)
                                    .popIn(order: 2)
                            }

                            Spacer(minLength: 24)
                            content()
                                .popIn(order: 3)
                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, Theme.Spacing.page)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .leading)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                }

                Button(continueTitle, action: onAdvance)
                    .buttonStyle(.brandPrimary)
                    .disabled(!canAdvance)
                    .padding(.horizontal, Theme.Spacing.page)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Selectable option card (sex, activity, goal)

/// A tappable choice row, styled as a white Daylight tile: title, optional detail line, an
/// indigo border + tint plus a checkmark when selected.
struct OnboardingOptionCard: View {
    let title: String
    var detail: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.Fonts.body(16, .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if let detail {
                        Text(detail)
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Colors.primary)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .frame(minHeight: 44, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.Colors.primary.opacity(0.08) : Theme.Colors.surfaceCard,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Colors.primary : Theme.Colors.hairline,
                                  lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: Color(hex: 0x0F172A, opacity: isSelected ? 0 : 0.05), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Pill (GLP-1 medication / dose, allergies, eating patterns)

/// A chip matching AboutYouView's `ToggleChip` — the same selected/unselected language used
/// everywhere else Daylight offers a fixed set of tappable options.
struct OnboardingPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(isSelected ? Theme.Colors.primaryText : Theme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(isSelected ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.surfaceInset,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Theme.Colors.primary.opacity(0.55) : .clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Segmented control (imperial/metric, yes/no)

/// A pill-track segmented control matching the onboarding surface language. `selection` is the
/// index of the active option.
struct OnboardingSegmented: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = i }
                } label: {
                    Text(options[i])
                        .font(Theme.Fonts.body(14, .semibold))
                        .foregroundStyle(selection == i ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selection == i {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.Colors.surfaceCard)
                                    .shadow(color: Color(hex: 0x0F172A, opacity: 0.1), radius: 4, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Aurora wash (GLP-1 step)

/// The ambient brand wash for the GLP-1 step — light from the top of the screen fading down,
/// masked so there's no hard edge. Anchored to the top safe-area, sized generously.
struct OnboardingAuroraWash: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.Colors.accent.opacity(0.24), Theme.Colors.primary.opacity(0.1), .clear],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 340)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .blur(radius: 20)
        .allowsHitTesting(false)
    }
}
