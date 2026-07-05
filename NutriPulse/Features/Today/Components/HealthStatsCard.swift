import SwiftUI

struct HealthStatsCard: View {
    let activeCalories: Double
    let netCalories: Double
    let restingHR: Double?
    let hrv: Double?
    let sleepHours: Double?
    let onConnect: () -> Void

    private var hasActivityData: Bool { activeCalories > 0 }
    private var hasVitalsData: Bool { restingHR != nil || hrv != nil || sleepHours != nil }
    private var hasAnyData: Bool { hasActivityData || hasVitalsData }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Activity & Health")
                .font(.headline)

            if hasAnyData {
                dataRows
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
        if hasActivityData {
            HStack(spacing: 0) {
                statItem(
                    icon: "flame.fill", iconColor: .orange,
                    label: "Burned", value: "\(Int(activeCalories)) kcal"
                )
                Divider().frame(height: 36).padding(.horizontal, Theme.Spacing.sm)
                statItem(
                    icon: "arrow.up.arrow.down", iconColor: .secondary,
                    label: "Net", value: "\(Int(netCalories)) kcal"
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
        Button(action: onConnect) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Apple Health")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("See active calories, heart rate & sleep")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
