import SwiftUI

/// Secondary help, directly below water logging in both regular and lighter tracking.
struct HomeSupportActions: View {
    var showsLighterTracking: Bool
    let onOffScript: () -> Void
    let onTools: () -> Void
    let onLighterTracking: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            row("Today went sideways", detail: "Help with right now, or just leave a note.",
                symbol: "arrow.triangle.branch", identifier: "today.offScript", action: onOffScript)
            Divider().overlay(Theme.Colors.hairline)
            row("Make today easier", detail: "Experiments, leftovers and one less decision.",
                symbol: "sparkles", identifier: "today.everydayTools", action: onTools)
            if showsLighterTracking {
                Divider().overlay(Theme.Colors.hairline)
                row("Take it easier", detail: "Pause goal reminders for a few days or longer.",
                    symbol: "leaf", identifier: "today.lighterTracking", action: onLighterTracking)
            }
        }.tile(padding: Theme.Spacing.md)
            .accessibilityIdentifier("today.supportActions")
    }

    private func row(_ title: String, detail: String, symbol: String, identifier: String,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 24).foregroundStyle(Theme.Colors.primaryText)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(Theme.Fonts.body(15, .semibold)).foregroundStyle(Theme.Colors.primaryText)
                    Text(detail).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 10)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
    }
}
