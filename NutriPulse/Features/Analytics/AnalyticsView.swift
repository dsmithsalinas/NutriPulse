import SwiftUI
import Charts

struct AnalyticsView: View {
    @State private var vm = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.md) {
                            Picker("Range", selection: $vm.selectedRange) {
                                ForEach(AnalyticsViewModel.TimeRange.allCases) { range in
                                    Text(range.label).tag(range)
                                }
                            }
                            .pickerStyle(.segmented)

                            CaloriesChartCard(
                                summaries:    vm.summaries,
                                goalCalories: vm.goalCalories,
                                average:      vm.averageCalories
                            )

                            MacrosChartCard(summaries: vm.summaries)

                            if !vm.weightLogs.isEmpty {
                                WeightChartCard(
                                    logs:   vm.weightLogs,
                                    change: vm.weightChange
                                )
                            }

                            if vm.loggedDays.isEmpty {
                                emptyState
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .task(id: vm.selectedRange) {
                await vm.loadData()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 44))
                .foregroundStyle(.quaternary)
            Text("No data yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Log food on the Today tab to see your trends here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Calories chart

private struct CaloriesChartCard: View {
    let summaries: [DailySummary]
    let goalCalories: Double?
    let average: Double

    private var xAxisStride: Int {
        switch summaries.count {
        case ..<8:  return 1
        case ..<15: return 2
        default:    return 7
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Calories")
                    .font(.headline)
                Spacer()
                if average > 0 {
                    Text("Avg \(Int(average)) kcal / day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Chart {
                ForEach(summaries) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("kcal", day.calories)
                    )
                    .foregroundStyle(Theme.NutrientColor.calories.gradient)
                    .cornerRadius(3)
                }
                if let goal = goalCalories {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .annotation(position: .topLeading) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) {
                    AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                }
            }
            .frame(height: 160)
        }
        .padding(Theme.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Macros chart

private struct MacrosChartCard: View {
    let summaries: [DailySummary]

    private struct MacroPoint: Identifiable {
        let id = UUID()
        let date: Date
        let macro: String
        let value: Double
    }

    private var chartData: [MacroPoint] {
        // Only include days where the user logged food
        summaries.filter(\.hasData).flatMap { day in [
            MacroPoint(date: day.date, macro: "Protein", value: day.proteinG),
            MacroPoint(date: day.date, macro: "Carbs",   value: day.carbsG),
            MacroPoint(date: day.date, macro: "Fat",     value: day.fatG),
        ]}
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Macros")
                .font(.headline)

            if chartData.isEmpty {
                Text("No data")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(chartData) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("g", point.value)
                    )
                    .foregroundStyle(by: .value("Macro", point.macro))
                    .interpolationMethod(.catmullRom)
                    .symbol(by: .value("Macro", point.macro))
                    .symbolSize(30)
                }
                .chartForegroundStyleScale([
                    "Protein": Theme.NutrientColor.protein,
                    "Carbs":   Theme.NutrientColor.carbs,
                    "Fat":     Theme.NutrientColor.fat,
                ])
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel("\(value.as(Double.self).map { Int($0) } ?? 0)g")
                        AxisGridLine()
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Weight chart

private struct WeightChartCard: View {
    let logs: [WeightLog]
    let change: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Weight")
                    .font(.headline)
                Spacer()
                if let change {
                    Text(String(format: "%+.1f kg", change))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(change <= 0 ? .green : .orange)
                }
            }

            Chart(logs) { log in
                LineMark(
                    x: .value("Date", log.loggedAt, unit: .day),
                    y: .value("kg", log.weightKg)
                )
                .foregroundStyle(Theme.NutrientColor.protein)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", log.loggedAt, unit: .day),
                    y: .value("kg", log.weightKg)
                )
                .foregroundStyle(Theme.NutrientColor.protein)
                .symbolSize(40)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 140)
        }
        .padding(Theme.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
