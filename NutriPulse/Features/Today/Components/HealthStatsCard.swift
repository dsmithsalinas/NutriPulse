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
            Text("Activity & Health")
                .font(.headline)

            // Three states, not two. Previously a user who denied Health access — or who
            // simply owns no Apple Watch — saw "Connect Apple Health" forever, and tapping
            // it visibly did nothing, because the only thing it could do was re-request a
            // permission iOS would never prompt for again.
            if hasAnyData {
                dataRows
            } else if hasRequestedAuthorization {
                noDataRow
            } else {
                connectRow
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    // MARK: Data view

    @ViewBuilder
    private var dataRows: some View {
        if let activeCalories {
            HStack(spacing: 0) {
                statItem(
                    icon: "flame.fill", iconColor: .orange,
                    label: "Burned", value: "\(Int(activeCalories.rounded())) kcal"
                )
                Divider().frame(height: 36).padding(.horizontal, Theme.Spacing.sm)
                statItem(
                    icon: "arrow.up.arrow.down", iconColor: .secondary,
                    label: "Net", value: "\(Int(netCalories.rounded())) kcal"
                )
            }
        }

        if hasActivityData && hasVitalsData {
            Divider()
        }

        if hasVitalsData {
            HStack(spacing: Theme.Spacing.sm) {
                if let hr = restingHR {
                    vitalsItem(icon: "heart.fill", iconColor: .red, value: "\(Int(hr))", unit: "bpm")
                }
                if let hrv {
                    vitalsItem(icon: "waveform.path.ecg", iconColor: .pink, value: "\(Int(hrv))", unit: "ms HRV")
                }
                if let sleep = sleepHours {
                    vitalsItem(icon: "moon.fill", iconColor: .indigo, value: formatSleep(sleep), unit: "sleep")
                }
            }
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

    // MARK: Sub-views

    private func statItem(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func vitalsItem(icon: String, iconColor: Color, value: String, unit: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatSleep(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}
