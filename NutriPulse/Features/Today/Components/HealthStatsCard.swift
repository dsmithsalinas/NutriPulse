import SwiftUI

struct HealthStatsCard: View {
    let activeCalories: Double?
    let netCalories: Double
    let restingHR: Double?
    let hrv: Double?
    let sleepHours: Double?
    // Whether the system permission sheet has already been shown. iOS presents it exactly
    // once per type, so once it has, "Connect Apple Health" can never do anything again.
    let hasRequestedAuthorization: Bool
    let onConnect: () -> Void
    let onOpenHealthApp: () -> Void

    private var hasActivityData: Bool { activeCalories != nil }
    private var hasVitalsData: Bool { restingHR != nil || hrv != nil || sleepHours != nil }
    private var hasAnyData: Bool { hasActivityData || hasVitalsData }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Today's signals")
                .font(.system(size: 13, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.Colors.textFaint)
                .textCase(.uppercase)

            // Three states, not two. Previously a user who denied Health access — or who
            // simply owns no Apple Watch — saw "Connect Apple Health" forever, and tapping
            // it visibly did nothing, because the only thing it could do was re-request a
            // permission iOS would never prompt for again.
            if hasAnyData {
                signalChips
            } else if hasRequestedAuthorization {
                noDataRow
            } else {
                connectRow
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    // MARK: Data view — compact chips, only for the signals we actually have.

    private var signalChips: some View {
        let items: [(icon: String, color: Color, value: String, label: String)] = [
            activeCalories.map { (icon: "flame.fill",         color: Color.orange, value: "\(Int($0.rounded()))", label: "ACTIVE") },
            sleepHours.map     { (icon: "moon.fill",          color: Color.indigo, value: formatSleep($0),        label: "SLEEP") },
            hrv.map            { (icon: "waveform.path.ecg",  color: Color.pink,   value: "\(Int($0))ms",         label: "HRV") },
            restingHR.map      { (icon: "heart.fill",         color: Color.red,    value: "\(Int($0))",           label: "RESTING") },
        ].compactMap { $0 }

        return HStack(spacing: Theme.Spacing.sm) {
            ForEach(items.indices, id: \.self) { i in
                signalChip(items[i])
            }
        }
    }

    private func signalChip(_ item: (icon: String, color: Color, value: String, label: String)) -> some View {
        VStack(spacing: 3) {
            Image(systemName: item.icon)
                .font(.system(size: 14))
                .foregroundStyle(item.color)
            Text(item.value)
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
            Text(item.label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.Colors.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
        }
    }

    // MARK: Connect prompt

    private var connectRow: some View {
        promptRow(
            title: "Connect Apple Health",
            subtitle: "See active calories, heart rate & sleep",
            action: onConnect
        )
    }

    // We asked, and got nothing back. That's either denied read access (HealthKit won't
    // tell us) or genuinely no data for this day — e.g. no Apple Watch. Say so, and give
    // the user the one place they can actually change it.
    private var noDataRow: some View {
        promptRow(
            title: "No Health data for this day",
            subtitle: "Check permissions in the Health app under Sharing → Apps",
            action: onOpenHealthApp
        )
    }

    private func promptRow(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func formatSleep(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}
