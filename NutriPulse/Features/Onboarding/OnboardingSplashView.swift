import SwiftUI

// The first thing a new user sees after creating an account: Pulse introducing itself. The ring
// mark draws in, then "Hi, I'm Pulse." types out, then the subtitle fades up — so the coach is
// present before a single question. Reduced-motion users get the finished state immediately.
struct OnboardingSplashView: View {
    let onContinue: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var dotOpacity: Double = 0
    @State private var typed = ""
    @State private var showSubtitle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let title = "Hi, I'm Pulse."
    // "crush this" failed the persona's no-hype rule (docs/pulse-persona.md §5) — Pulse is
    // steady, not a hype machine.
    private let subtitle = "Let's start with a few quick questions so I can get to know you — and be useful from day one."

    var body: some View {
        ZStack {
            Theme.Colors.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                OnboardingPulseAvatar(size: 112, drawProgress: ringProgress, dotOpacity: dotOpacity)

                // A hidden full-length copy reserves the line height so the avatar doesn't jump
                // as the title types in.
                Text(title)
                    .font(Theme.Fonts.display(32, .extraBold, relativeTo: .largeTitle))
                    .opacity(0)
                    .overlay(alignment: .top) {
                        Text(typed)
                            .font(Theme.Fonts.display(32, .extraBold, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .padding(.top, 26)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300)
                    .padding(.top, 10)
                    .opacity(showSubtitle ? 1 : 0)

                Spacer()
                Spacer()

                Button("Let's go", action: onContinue)
                    .buttonStyle(.daylightPrimary)
                    .padding(.top, 8)
                    .opacity(showSubtitle ? 1 : 0)
                    .disabled(!showSubtitle)
                    .accessibilityHidden(!showSubtitle)
            }
            .padding(.horizontal, Theme.Spacing.page)
            .frame(maxWidth: .infinity)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await runIntro() }
    }

    private func runIntro() async {
        guard !reduceMotion else {
            ringProgress = 1; dotOpacity = 1; typed = title; showSubtitle = true
            return
        }
        withAnimation(.easeOut(duration: 1.0)) { ringProgress = 1 }
        try? await Task.sleep(for: .milliseconds(850))
        withAnimation(.easeIn(duration: 0.3)) { dotOpacity = 1 }
        try? await Task.sleep(for: .milliseconds(320))
        for index in title.indices {
            typed = String(title[title.startIndex...index])
            try? await Task.sleep(for: .milliseconds(58))
        }
        typed = title
        withAnimation(.easeIn(duration: 0.5)) { showSubtitle = true }
    }
}
