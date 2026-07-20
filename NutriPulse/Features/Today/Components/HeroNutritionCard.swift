import SwiftUI

// The Today screen's centerpiece. Protein is the hero — for a GLP-1 user "did I hit protein?"
// is the daily question — so it owns a large gradient ring. Calories are a strong secondary
// meter, and carbs/fat/fiber are quiet supporting chips. Replaces the old four-equal-rings card.
struct HeroNutritionCard: View {
    let calories: Double
    let proteinG: Double
    let carbsG:   Double
    let fatG:     Double
    let fiberG:   Double
    let goal:     DailyGoal?

    @State private var animatedPct = 0.0

    private var proteinGoal: Double { goal?.proteinG ?? 150 }
    private var calorieGoal: Double { goal?.calories ?? 2000 }

    private var proteinPct: Double { proteinGoal > 0 ? min(proteinG / proteinGoal, 1) : 0 }
    private var proteinToGo: Int { max(Int((proteinGoal - proteinG).rounded()), 0) }
    private var caloriePct: Double { calorieGoal > 0 ? min(calories / calorieGoal, 1) : 0 }
    private var caloriesLeft: Int { Int((calorieGoal - calories).rounded()) }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            proteinRing
            calorieMeter
            macroChips
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Theme.Colors.surfaceCard
                // The one brand "hero glow" — a soft indigo bloom behind the ring.
                RadialGradient(
                    colors: [Theme.Colors.primary.opacity(0.22), .clear],
                    center: UnitPoint(x: 0.5, y: 0.30),
                    startRadius: 6, endRadius: 240
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
        }
        // Ambient animation so the numeric-text rolls when totals change (e.g. after logging).
        .animation(.snappy, value: proteinG)
        .animation(.snappy, value: calories)
    }

    // MARK: Protein hero ring

    private var proteinRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.ringTrack, lineWidth: 16)

            // `animatedPct` starts at 0 and springs to the real value on appear (and on any
            // change), so the ring fills in rather than snapping — the screen feels alive.
            Circle()
                .trim(from: 0, to: animatedPct)
                .stroke(Theme.Colors.primaryGradient,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.Colors.primary.opacity(0.45), radius: 7)

            VStack(spacing: 2) {
                Text("PROTEIN")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.Colors.primary)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(Int(proteinG))")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: proteinG))
                    Text("/\(Int(proteinGoal))g")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text(proteinToGo > 0
                     ? "\(proteinToGo)g to go · \(Int(proteinPct * 100))%"
                     : "Goal reached 🎯")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 210, height: 210)
        .padding(.top, Theme.Spacing.xs)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) { animatedPct = proteinPct }
        }
        .onChange(of: proteinPct) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { animatedPct = newValue }
        }
        .animation(.snappy, value: proteinG)
    }

    // MARK: Calorie meter

    private var calorieMeter: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 4) {
                    Text("Calories")
                        .foregroundStyle(.secondary)
                    Text("\(Int(calories))")
                        .fontWeight(.bold)
                        .contentTransition(.numericText(value: calories))
                    Text("/ \(Int(calorieGoal))")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 14))
                .monospacedDigit()
                Spacer()
                Text(caloriesLeft >= 0 ? "\(caloriesLeft) left" : "\(-caloriesLeft) over")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.NutrientColor.calories)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(caloriesLeft)))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.ringTrack)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: 0xFB923C), Theme.NutrientColor.calories],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.width * caloriePct, caloriePct > 0 ? 10 : 0))
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: caloriePct)
                }
            }
            .frame(height: 9)
        }
    }

    // MARK: Macro chips

    private var macroChips: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Carbs and fat are ceilings; fiber is a floor. The distinction only shows
            // at 100%+: a ceiling bar caps and dims (the number above already says how
            // far over — the bar declines to dramatize it), a full floor bar stays its
            // own color, quietly complete.
            chip("Carbs", carbsG, goal?.carbsG, Theme.NutrientColor.carbs, isCeiling: true)
            chip("Fat",   fatG,   goal?.fatG,   Theme.NutrientColor.fat,   isCeiling: true)
            chip("Fiber", fiberG, goal?.fiberG, Theme.NutrientColor.fiber, isCeiling: false)
        }
    }

    private func chip(
        _ label: String,
        _ value: Double,
        _ target: Double?,
        _ color: Color,
        isCeiling: Bool
    ) -> some View {
        // No goal row, or this macro's goal is 0 → the chip renders exactly as it
        // used to: no "of —g", no empty track.
        let target = target.flatMap { $0 > 0 ? $0 : nil }
        let pct = target.map { min(value / $0, 1) } ?? 0
        let dimmed = isCeiling && target.map { value > $0 } == true

        return VStack(spacing: 1) {
            Text("\(Int(value))g")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
            if let target {
                Text("of \(Int(target))g")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.textFaint)
                    .monospacedDigit()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Colors.ringTrack)
                        Capsule()
                            .fill(color)
                            .opacity(dimmed ? 0.45 : 1)
                            .frame(width: max(geo.size.width * pct, pct > 0 ? 4 : 0))
                            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: pct)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Theme.Colors.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.Colors.hairline, lineWidth: 1)
        }
    }
}
