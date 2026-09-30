import SwiftUI
import Charts

// A gold accent for "Energy" in the by-day-since-dose chart — distinct from the amber used for
// Appetite (Theme.NutrientColor.fat) and from Nausea's rose (Theme.Colors.listening).
private extension Theme.Colors {
    static let energyGold = Color(hex: 0xCA8A04)
}


// The chart inside the "How do shot days change my eating?" question. No outer `.tile()` or
// question heading here — AnalyticsQuestionCard (AnalyticsView.swift) supplies both, along with
// the takeaway line, so this only owns the metric picker and the chart itself.
struct CycleAwareAnalyticsCard: View {
    let insights: [CycleDayInsight]
    let proteinGoal: Double?
    /// The question's plain-English takeaway, read out as the chart's accessibility summary.
    let accessibilitySummary: String
    @State private var selectedMetric: Metric = .protein

    private enum Metric: String, CaseIterable, Identifiable {
        case protein = "Protein"
        case hydration = "Hydration"
        case appetite = "Appetite"
        case energy = "Energy"
        case nausea = "Nausea"
        case movement = "Movement"

        var id: Self { self }
        var unit: String {
            switch self {
            case .protein: "g"
            case .hydration: "ml"
            case .appetite, .energy, .nausea: "/5"
            case .movement: "min"
            }
        }
        var color: Color {
            switch self {
            case .protein: Theme.NutrientColor.protein
            case .hydration: Theme.NutrientColor.water
            case .appetite: Theme.NutrientColor.fat
            case .energy: Theme.Colors.energyGold
            case .nausea: Theme.Colors.listening
            case .movement: Theme.NutrientColor.fiber
            }
        }
        var explanation: String {
            switch self {
            case .protein: "Average protein logged on each day after your shot."
            case .hydration: "Average water logged on each day after your shot."
            case .appetite: "Average appetite check-in, from low to high."
            case .energy: "Average energy check-in, from low to high."
            case .nausea: "Average nausea check-in, from low to high."
            case .movement: "Average workout minutes on each day after your shot."
            }
        }
    }

    private struct Point: Identifiable {
        let day: Int
        let value: Double
        let sampleCount: Int
        var id: Int { day }
    }

    private var points: [Point] {
        insights.compactMap { day in
            let value: Double? = switch selectedMetric {
            case .protein: day.averageProteinG
            case .hydration: day.averageWaterMl
            case .appetite: day.averageAppetite
            case .energy: day.averageEnergy
            case .nausea: day.averageNausea
            case .movement: day.averageWorkoutMinutes
            }
            let sampleCount = switch selectedMetric {
            case .protein: day.nutritionSampleCount
            case .hydration: day.hydrationSampleCount
            case .appetite, .energy, .nausea: day.checkInSampleCount
            case .movement: day.movementSampleCount
            }
            return value.map { .init(day: day.cycleDay, value: $0, sampleCount: sampleCount) }
        }
    }

    private var confidence: (label: String, detail: String, color: Color) {
        let minimum = points.map(\.sampleCount).min() ?? 0
        let samples = points.reduce(0) { $0 + $1.sampleCount }
        let label: String
        let color: Color
        switch minimum {
        case 3...: label = "Stronger pattern"; color = .green
        case 2: label = "Growing pattern"; color = Theme.Colors.primary
        default: label = "Early pattern"; color = .orange
        }
        let noun = selectedMetric == .appetite || selectedMetric == .energy || selectedMetric == .nausea
            ? "check-ins" : "logged days"
        return (label, "Based on \(samples) \(noun) across \(points.count) cycle days.", color)
    }

    private var notablePoint: Point? {
        switch selectedMetric {
        case .nausea, .energy, .movement, .protein, .hydration:
            points.max(by: { $0.value < $1.value })
        case .appetite:
            points.min(by: { $0.value < $1.value })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("By day since dose")
                    .font(Theme.Fonts.body(13, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(Metric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.primary)
            }
            Text(selectedMetric.explanation)
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Colors.textSecondary)

            if !points.isEmpty {
                HStack(spacing: 7) {
                    Text(confidence.label)
                        .font(Theme.Fonts.body(11, .bold))
                        .foregroundStyle(confidence.color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(confidence.color.opacity(0.1), in: Capsule())
                    Text(confidence.detail)
                        .font(Theme.Fonts.body(11))
                        .foregroundStyle(Theme.Colors.textFaint)
                }
            }

            if points.isEmpty {
                BrandedEmptyState(icon: "chart.xyaxis.line", title: "No \(selectedMetric.rawValue.lowercased()) data yet", message: "This view fills in as you log across dose cycles.")
                .frame(height: 210)
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Cycle day", point.day),
                            y: .value(selectedMetric.rawValue, point.value)
                        )
                        .foregroundStyle(selectedMetric.color)
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                    }

                    if selectedMetric == .protein, let proteinGoal {
                        RuleMark(y: .value("Protein goal", proteinGoal))
                            .foregroundStyle(Theme.Colors.textFaint)
                            .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal")
                                    .font(Theme.Fonts.body(11))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: insights.map(\.cycleDay)) { value in
                        AxisValueLabel { if let day = value.as(Int.self) { Text("D\(day)") } }
                            .foregroundStyle(Theme.Colors.textFaint)
                        AxisGridLine().foregroundStyle(Theme.Colors.hairline)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Theme.Colors.hairline)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(axisLabel(number))
                            }
                        }
                        .foregroundStyle(Theme.Colors.textFaint)
                    }
                }
                .frame(height: 210)
                .chartDrawIn()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Chart of \(selectedMetric.rawValue.lowercased()) by day since dose")
                .accessibilityValue(accessibilitySummary)
            }

            if let notablePoint {
                Label(insightCopy(notablePoint), systemImage: "lightbulb.fill")
                    .font(Theme.Fonts.body(13, .semibold))
                    .foregroundStyle(Theme.Colors.primary)
            }

            Text("Your pattern, not a readiness score or medical guidance.")
                .font(Theme.Fonts.body(11))
                .foregroundStyle(Theme.Colors.textFaint)
        }
    }

    private func axisLabel(_ value: Double) -> String {
        switch selectedMetric {
        case .hydration where value >= 1000:
            return "\((value / 1000).formatted(.number.precision(.fractionLength(0...1))))L"
        case .appetite, .energy, .nausea:
            return value.formatted(.number.precision(.fractionLength(0...1)))
        default:
            return "\(Int(value.rounded()))"
        }
    }

    private func insightCopy(_ point: Point) -> String {
        let value = axisLabel(point.value)
        return switch selectedMetric {
        case .appetite: "Appetite has been lowest around cycle day \(point.day) (\(value)/5)."
        case .nausea: "Nausea has been highest around cycle day \(point.day) (\(value)/5)."
        case .energy: "Energy has been highest around cycle day \(point.day) (\(value)/5)."
        case .hydration: "Your highest hydration has been around cycle day \(point.day) (\(value))."
        case .protein: "Your highest protein has been around cycle day \(point.day) (\(value)g)."
        case .movement: "Your highest movement has been around cycle day \(point.day) (\(value) min)."
        }
    }
}
