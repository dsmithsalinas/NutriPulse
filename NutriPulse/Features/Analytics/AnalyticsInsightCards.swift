import SwiftUI
import Charts

struct WeeklyReviewCard: View {
    let review: WeeklyReview

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Your week, from Pulse", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(Theme.Colors.primary)
            reviewRow("What went well", review.wentWell, "checkmark.circle.fill", .green)
            reviewRow("Where it got difficult", review.gotDifficult, "arrow.down.right.circle.fill", .orange)
            reviewRow("Pattern noticed", review.pattern, "waveform.path.ecg", Theme.Colors.primary)

            VStack(alignment: .leading, spacing: 3) {
                Text("ONE THING TO TRY")
                    .font(.system(size: 10, weight: .bold)).tracking(0.7)
                    .foregroundStyle(Theme.Colors.textFaint)
                Text(review.experiment)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.primary.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    private func reviewRow(_ title: String, _ detail: String, _ icon: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 18).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(detail).font(.subheadline)
            }
        }
    }
}

struct CycleAwareAnalyticsCard: View {
    let insights: [CycleDayInsight]
    let proteinGoal: Double?
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
            case .hydration: .blue
            case .appetite: .orange
            case .energy: .yellow
            case .nausea: .pink
            case .movement: .green
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
                Text("By day since dose").font(.headline)
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
                .font(.caption).foregroundStyle(.secondary)

            if !points.isEmpty {
                HStack(spacing: 7) {
                    Text(confidence.label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(confidence.color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(confidence.color.opacity(0.1), in: Capsule())
                    Text(confidence.detail)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textFaint)
                }
            }

            if points.isEmpty {
                ContentUnavailableView(
                    "No \(selectedMetric.rawValue.lowercased()) data yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text("This view fills in as you log across dose cycles.")
                )
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
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: insights.map(\.cycleDay)) { value in
                        AxisValueLabel { if let day = value.as(Int.self) { Text("D\(day)") } }
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(axisLabel(number))
                            }
                        }
                    }
                }
                .frame(height: 210)
            }

            if let notablePoint {
                Label(insightCopy(notablePoint), systemImage: "lightbulb.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.primary)
            }

            Text("Your pattern, not a readiness score or medical guidance.")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textFaint)
        }
        .padding(Theme.Spacing.md)
        .card()
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
