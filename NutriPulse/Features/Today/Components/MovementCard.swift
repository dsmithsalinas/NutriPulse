import SwiftUI

// Movement, not calorie-burning: the header leads with minutes, and there is no
// "earned back" framing anywhere — burn-to-earn mechanics are exactly the shaming
// pattern the product vision rules out. Calories, when present, are quiet row metadata.
struct MovementCard: View {
    let workouts: [WorkoutLog]
    let onLog: () -> Void
    let onDelete: (WorkoutLog) -> Void

    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    private var totalMinutes: Int {
        Int(workouts.reduce(0) { $0 + $1.durationMinutes }.rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(Theme.Colors.primary)
                    Text("Movement")
                        .fontWeight(.semibold)
                }
                Spacer()
                if totalMinutes > 0 {
                    Text("\(totalMinutes) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if workouts.isEmpty {
                emptyRow
            } else {
                ForEach(workouts) { workout in
                    workoutRow(workout)
                }
            }

            Button(action: onLog) {
                Text("+ Log workout")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.primary.opacity(0.12))
                    .foregroundStyle(Theme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    private func workoutRow(_ workout: WorkoutLog) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: workout.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(meta(for: workout))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            sourceBadge(workout.source)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Theme.Colors.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
        }
        .contextMenu {
            // An imported row only leaves NutriPulse — the workout stays in Apple
            // Health, and the tombstone stops the next import from resurrecting it.
            Button(role: .destructive) {
                onDelete(workout)
            } label: {
                Label(
                    workout.source == .healthkit ? "Remove from NutriPulse" : "Delete workout",
                    systemImage: "trash"
                )
            }
        }
    }

    private func sourceBadge(_ source: WorkoutSource) -> some View {
        Text(source == .healthkit ? "Health" : "Manual")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(source == .healthkit ? Color.pink : Theme.Colors.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((source == .healthkit ? Color.pink : Theme.Colors.primary).opacity(0.12))
            .clipShape(Capsule())
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nothing logged yet")
                .font(.subheadline)
                .fontWeight(.medium)
            Text(HealthKitManager.shared.isAvailable
                 ? "Workouts from Apple Health show up here automatically."
                 : "Log a walk, lift, ride, or run.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func meta(for workout: WorkoutLog) -> String {
        var parts = ["\(Int(workout.durationMinutes.rounded())) min"]
        parts.append(workout.startedAt.formatted(date: .omitted, time: .shortened))
        if let kcal = workout.activeCalories, kcal > 0 {
            parts.append("\(Int(kcal.rounded())) cal")
        }
        if let meters = workout.distanceMeters, meters > 0 {
            parts.append(distanceString(meters))
        }
        return parts.joined(separator: " · ")
    }

    private func distanceString(_ meters: Double) -> String {
        units == .imperial
            ? String(format: "%.1f mi", meters / 1609.344)
            : String(format: "%.1f km", meters / 1000)
    }
}
