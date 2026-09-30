import SwiftUI
import UIKit

enum MainTab: Hashable { case today, progress, pulse, profile }

// SwiftUI places `.safeAreaInset` content above the keyboard but does NOT inset the main
// content by it, so a pinned composer ends up underneath this bar (and under the raised Log
// button) whenever the keyboard is up. Screens with pinned bottom content read this height
// and add the clearance themselves. See CoachView.
struct TabBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TabBarHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tabBarHeight: CGFloat {
        get { self[TabBarHeightEnvironmentKey.self] }
        set { self[TabBarHeightEnvironmentKey.self] = newValue }
    }
}

// Daylight's floating bar: a dark capsule over the content with the four destinations and the
// lime Log action in the center slot. Logging is the most frequent thing a GLP-1 user does and
// the hardest habit to keep, so it gets the brightest control on the screen without costing a
// navigation destination. The selected tab grows into a labelled white pill.
struct MainTabBar: View {
    @Binding var selected: MainTab
    // Pulse turned off hides the tab entirely (docs/daylight-redesign.md step 8) — there's
    // nothing left to reach on it once it can't send anything to the AI provider. Consent (or
    // the lack of it) doesn't affect this: PulseConsentSheet shows instead once the user lands
    // there. Defaults true so every existing call site (and the tab-bar preview) keeps 5 tabs.
    var showsPulse: Bool = true
    /// Scrolled down: a narrower, shorter bar with icons only, so it covers less of the page.
    /// Scrolling back up (or switching tabs) brings the full bar back. See MainTabView.
    var compact: Bool = false
    let onLog: () -> Void

    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Icon {
        case symbol(String)
        case pulse
    }

    var body: some View {
        HStack(spacing: 0) {
            tab(.today,    "Today",    .symbol("square.grid.2x2.fill"))
            Spacer(minLength: 0)
            tab(.progress, "Progress", .symbol("chart.line.uptrend.xyaxis"))
            Spacer(minLength: 0)
            logButton
            Spacer(minLength: 0)
            if showsPulse {
                tab(.pulse, "Pulse", .pulse)
                Spacer(minLength: 0)
            }
            tab(.profile,  "Profile",  .symbol("person.fill"))
        }
        .padding(.horizontal, compact ? 6 : 8)
        .frame(height: compact ? 52 : 64)
        .background {
            RoundedRectangle(cornerRadius: compact ? 20 : 24, style: .continuous)
                .fill(Theme.Colors.ink)
                .shadow(color: Color(hex: 0x0F172A, opacity: 0.18), radius: 16, y: 8)
        }
        .animation(reduceMotion ? nil : Theme.Motion.tabSelect, value: selected)
        // Compact: the same bar, narrowed toward the middle so page content shows either side.
        .padding(.horizontal, compact ? 56 : Theme.Spacing.page)
        .padding(.top, 8)
        .padding(.bottom, compact ? 0 : 4)
        // A fixed height either way, so pages don't shift as the bar shrinks and grows.
        .frame(height: 76, alignment: .bottom)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: TabBarHeightKey.self, value: geo.size.height)
            }
        }
    }

    private func tab(_ tab: MainTab, _ label: String, _ icon: Icon) -> some View {
        let isOn = selected == tab
        return Button {
            guard selected != tab else { return }
            selected = tab
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 6) {
                iconView(icon, color: isOn ? Theme.Colors.ink : Theme.Colors.inkIcon)
                if isOn && !compact {
                    Text(label)
                        .font(Theme.Fonts.body(14, .bold, relativeTo: nil))
                        .foregroundStyle(Color(hex: 0x0F172A))
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                }
            }
            .padding(.horizontal, isOn && !compact ? 14 : 0)
            .frame(minWidth: compact ? 40 : 48, minHeight: compact ? 40 : 48)
            .background {
                if isOn {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white)
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder
    private func iconView(_ icon: Icon, color: Color) -> some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
        case .pulse:
            PulseMark(lineWidthRatio: 0.15)
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .frame(width: 22, height: 22)
        }
    }

    private var logButton: some View {
        Button {
            onLog()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .fill(Theme.Colors.lime)
                .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Theme.Colors.limeInk)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Log food")
    }
}

#Preview("Tab bar") {
    VStack {
        Spacer()
        MainTabBar(selected: .constant(.today), onLog: {})
    }
    .background(Theme.Colors.ground)
}
