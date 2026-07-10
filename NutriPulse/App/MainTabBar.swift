import SwiftUI
import UIKit

enum MainTab: Hashable { case today, analytics, pulse, profile }

// Custom bottom bar: the four destinations plus a raised, gradient Log action in the center
// slot. Logging is the most frequent thing a GLP-1 user does and the hardest habit to keep, so
// it gets the most prominent control on the screen without costing a navigation destination.
struct MainTabBar: View {
    @Binding var selected: MainTab
    let onLog: () -> Void

    // The FAB rises above the bar surface; this is how far, and how much clear space the bar
    // reserves at the top so the raised button is never clipped.
    private let lift: CGFloat = 18

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tab(.today,     "Today",     "house.fill")
            tab(.analytics, "Analytics", "chart.line.uptrend.xyaxis")
            logButton
            tab(.pulse,     "Pulse",     "bubble.left.and.bubble.right.fill")
            tab(.profile,   "Profile",   "person.fill")
        }
        .padding(.horizontal, 10)
        .padding(.top, lift + 10)
        .padding(.bottom, 4)
        .background(alignment: .bottom) {
            // Bar surface fills everything BELOW the reserved lift zone, so the FAB floats
            // above a clean edge rather than sitting on it.
            Theme.Colors.surfaceCard
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.Colors.hairline).frame(height: 0.5)
                }
                .padding(.top, lift + 8)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tab(_ tab: MainTab, _ label: String, _ symbol: String) -> some View {
        let isOn = selected == tab
        return Button {
            guard selected != tab else { return }
            selected = tab
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isOn ? Theme.Colors.primary : Theme.Colors.textFaint)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var logButton: some View {
        Button {
            onLog()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.Colors.primaryGradient)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Theme.Colors.primary.opacity(0.45), radius: 10, y: 4)
                    .offset(y: -lift)
                Text("Log")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.primary)
                    .offset(y: -lift)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
