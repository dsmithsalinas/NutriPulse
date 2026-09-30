import SwiftUI

// Today's Daylight tile grid (docs/daylight-redesign.md): protein as the liquid-filled hero,
// calories with the other macros, the shot cycle, water, and movement. Each tile is a plain
// view over values the view model already computes; tapping one opens the fuller surface.

// MARK: - Protein

struct ProteinTile: View {
    let proteinG: Double
    let goalG: Double?

    private var level: Double {
        guard let goalG, goalG > 0 else { return 0 }
        return min(proteinG / goalG, 1)
    }

    private var remaining: Int? {
        goalG.map { Int(($0 - proteinG).rounded()) }
    }

    private var status: String {
        guard let remaining else { return "No floor set" }
        return remaining > 0 ? "\(remaining)g to go" : "Floor cleared"
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                TileEyebrow("Protein", color: Theme.Colors.heroLabel)
                Spacer(minLength: 4)
                if let goalG {
                    Text("floor \(Int(goalG.rounded()))")
                        .font(Theme.Fonts.body(12, .semibold))
                        .foregroundStyle(Theme.Colors.heroLabel)
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    CountingNumber(value: Int(proteinG.rounded()), font: Theme.Fonts.number(60, relativeTo: .largeTitle))
                    Text("g")
                        .font(Theme.Fonts.display(22, relativeTo: .title2))
                }
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                Text(status)
                    .font(Theme.Fonts.body(14, .semibold))
                    .foregroundStyle(Theme.Colors.heroSubtext)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                Theme.Colors.heroDeep
                LiquidFill(level: level, color: Theme.Colors.hero)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(goalG.map { "Protein \(Int(proteinG.rounded())) of \(Int($0.rounded())) grams. \(status)" }
            ?? "Protein \(Int(proteinG.rounded())) grams")
    }
}

/// Liquid rising to `level` (0…1) with a slow travelling wave on its surface. The level springs
/// in on first appear and eases to new values after a log. Reduce Motion: a still, flat fill.
struct LiquidFill: View {
    let level: Double
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let period = 3.2
            let phase = reduceMotion ? 0
                : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
            WaveShape(level: shown, phase: phase, amplitude: reduceMotion || shown <= 0 ? 0 : 5)
                .fill(color)
        }
        .onAppear {
            guard !reduceMotion else { shown = level; return }
            withAnimation(Theme.Motion.fill.delay(0.3)) { shown = level }
        }
        .onChange(of: level) { _, new in
            withAnimation(reduceMotion ? nil : Theme.Motion.fill) { shown = new }
        }
        .accessibilityHidden(true)
    }
}

private struct WaveShape: Shape {
    var level: Double
    var phase: Double
    var amplitude: CGFloat

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let surface = rect.maxY - rect.height * CGFloat(min(max(level, 0), 1))
        let wavelength = rect.width / 1.4
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: surface))
        var x = rect.minX
        while x <= rect.maxX {
            let angle = (Double(x / wavelength) + phase) * 2 * .pi
            path.addLine(to: CGPoint(x: x, y: surface + CGFloat(sin(angle)) * amplitude))
            x += 2
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Calories and macros

struct CaloriesTile: View {
    let calories: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let goal: DailyGoal?

    private var caloriesLine: (value: String, unit: String) {
        guard let goal, goal.calories > 0 else {
            return (Int(calories.rounded()).formatted(), "kcal")
        }
        let left = Int((goal.calories - calories).rounded())
        return left >= 0 ? (left.formatted(), "left") : ((-left).formatted(), "over")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    TileEyebrow("Calories")
                    Spacer(minLength: 4)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(caloriesLine.value)
                            .font(Theme.Fonts.number(20, .bold, relativeTo: .headline))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(caloriesLine.unit)
                            .font(Theme.Fonts.body(12, .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                if let goal, goal.calories > 0 {
                    MeterBar(progress: calories / goal.calories, color: Theme.NutrientColor.calories, height: 8)
                }
            }
            Spacer(minLength: 0)
            macro("Carbs", carbsG, goal?.carbsG, Theme.NutrientColor.carbs)
            macro("Fat", fatG, goal?.fatG, Theme.NutrientColor.fat)
            macro("Fiber", fiberG, goal?.fiberG, Theme.NutrientColor.fiber)
        }
        .tile(radius: Theme.Radius.tile, padding: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func macro(_ name: String, _ value: Double, _ target: Double?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(Theme.Fonts.body(12, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer(minLength: 4)
                HStack(spacing: 0) {
                    Text("\(Int(value.rounded()))")
                        .font(Theme.Fonts.body(12, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(target.map { " / \(Int($0.rounded()))g" } ?? "g")
                        .font(Theme.Fonts.body(12, .medium))
                        .foregroundStyle(Theme.Colors.textFaint)
                }
                .monospacedDigit()
            }
            if let target, target > 0 {
                MeterBar(progress: value / target, color: color, height: 5, delay: 0.6)
            }
        }
    }

    private var accessibilitySummary: String {
        let cal = "Calories \(caloriesLine.value) \(caloriesLine.unit)"
        func part(_ name: String, _ v: Double, _ t: Double?) -> String {
            t.map { "\(name) \(Int(v.rounded())) of \(Int($0.rounded())) grams" } ?? "\(name) \(Int(v.rounded())) grams"
        }
        return [cal, part("carbs", carbsG, goal?.carbsG), part("fat", fatG, goal?.fatG), part("fiber", fiberG, goal?.fiberG)]
            .joined(separator: ". ")
    }
}

// MARK: - Shot cycle

struct ShotCycleTile: View {
    /// Days since the last shot; 0 is shot day.
    let cycleDay: Int
    /// Days between shots, from the dose schedule (weekly for every current medication).
    var cycleLength: Int = 7
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    private var title: String {
        if cycleDay == 0 { return "Shot day" }
        if cycleDay >= cycleLength { return "Shot due" }
        return "Day \(cycleDay) of \(cycleLength)"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                TileEyebrow("Shot cycle", color: Theme.Colors.limeLabel)
                Spacer(minLength: 0)
                Text(title)
                    .font(Theme.Fonts.display(22, .bold, relativeTo: .title3))
                    .foregroundStyle(Theme.Colors.limeInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    ForEach(1...cycleLength, id: \.self) { day in
                        dot(day)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .tile(Theme.Colors.lime, radius: Theme.Radius.tile, padding: 14, shadow: false)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel("Shot cycle, \(title)")
        .accessibilityHint("Opens your shot cycle check-in")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulsing = true }
        }
    }

    @ViewBuilder
    private func dot(_ day: Int) -> some View {
        if day <= cycleDay {
            Circle()
                .fill(Theme.Colors.limeInk)
                .frame(width: 12, height: 12)
                .scaleEffect(day == cycleDay && pulsing ? 1.18 : 1)
        } else {
            Circle()
                .strokeBorder(Theme.Colors.limeLine, lineWidth: 2)
                .frame(width: 12, height: 12)
        }
    }
}

// MARK: - Water

struct WaterTile: View {
    let intakeMl: Double
    let goalMl: Double
    let unit: WaterUnit
    let usualMl: Double
    let onQuickAdd: () -> Void
    let onOpenPicker: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button(action: onOpenPicker) {
                VStack(alignment: .leading, spacing: 0) {
                    TileEyebrow("Water", color: Theme.Colors.skyInk)
                    Spacer(minLength: 8)
                    Text(unit.displayAmount(intakeMl))
                        .font(Theme.Fonts.number(24, .bold, relativeTo: .title2))
                        .foregroundStyle(Theme.Colors.skyInk)
                    Text("Tap for sizes")
                        .font(Theme.Fonts.body(12, .semibold))
                        .foregroundStyle(Theme.Colors.skyLabel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Water \(unit.displayAmount(intakeMl)) of \(unit.displayAmount(goalMl))")
            .accessibilityHint("Choose an amount")

            Button(action: onQuickAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.skyAction, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Add your usual \(unit.display(usualMl))")
        }
        .frame(minHeight: 84)
        .tile(Theme.Colors.sky, radius: Theme.Radius.tile, padding: 14, shadow: false)
    }
}

extension WaterUnit {
    /// The running total: litres to one place for metric, whole ounces for imperial.
    func displayAmount(_ ml: Double) -> String {
        switch self {
        case .ml: return String(format: "%.1f L", ml / 1000)
        case .oz: return display(ml)
        }
    }
}

// MARK: - Movement

struct MovedTile: View {
    let workouts: [WorkoutLog]
    let onTap: () -> Void

    private var minutes: Int {
        Int(workouts.reduce(0) { $0 + $1.durationMinutes }.rounded())
    }

    private var detail: String {
        guard let longest = workouts.max(by: { $0.durationMinutes < $1.durationMinutes }) else {
            return "Log a workout"
        }
        return workouts.count > 1 ? "\(longest.displayName) + \(workouts.count - 1)" : longest.displayName
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                TileEyebrow("Moved")
                Spacer(minLength: 8)
                Text(minutes > 0 ? "\(minutes) min" : "—")
                    .font(Theme.Fonts.number(24, .bold, relativeTo: .title2))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(detail)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .tile(radius: Theme.Radius.tile, padding: 14)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel(minutes > 0 ? "Moved \(minutes) minutes, \(detail)" : "Movement, nothing logged")
        .accessibilityHint("Shows today's workouts")
    }
}

/// The full movement list (and logging) behind the Moved tile.
struct MovementSheet: View {
    let vm: TodayViewModel
    @State private var showWorkoutSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                SheetHeader(title: "Movement", onClose: { dismiss() })
                MovementCard(
                    workouts: vm.workouts,
                    onLog: { showWorkoutSheet = true },
                    onDelete: { workout in Task { await vm.deleteWorkout(id: workout.id) } }
                )
            }
            .padding(Theme.Spacing.page)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showWorkoutSheet) {
            WorkoutEntrySheet { activity, minutes, calories, distanceMeters in
                await vm.addManualWorkout(
                    activity: activity,
                    durationMinutes: minutes,
                    calories: calories,
                    distanceMeters: distanceMeters
                )
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// Daylight sheet title row: display-font title and a white circular close button.
struct SheetHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.Fonts.display(28, .extraBold, relativeTo: .title))
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceCard, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Close")
        }
    }
}
