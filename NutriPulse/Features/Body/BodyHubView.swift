import SwiftUI
import Charts

// The Body hub — every body metric in one place, as list rows with sparklines. Pushed
// from Today's Body card. Deliberately NOT a body-silhouette screen: the list grammar
// matches the rest of the app, handles sparse data honestly, and needs no illustration.
struct BodyHubView: View {
    let todayVM: TodayViewModel
    let heightCm: Double?

    @State private var vm = BodyHubViewModel()
    @State private var showCheckIn = false
    @State private var showGoals = false
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                DaylightPageTitle("Body")

                Picker("Range", selection: $vm.selectedRange) {
                    ForEach(BodyHubViewModel.TimeRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                metricRow(
                    .weight,
                    series: vm.weightSeries,
                    fallbackValue: todayVM.bodyComp.weightKg,
                    order: 0
                )
                metricRow(
                    .bodyFat,
                    series: vm.bodyFatSeries,
                    fallbackValue: todayVM.bodyComp.bodyFatPct,
                    order: 1
                )
                metricRow(
                    .leanMass,
                    series: vm.leanSeries,
                    fallbackValue: todayVM.bodyComp.lbmKg,
                    order: 2
                )

                if !vm.trackedSites.isEmpty {
                    TileEyebrow("Measurements")
                        .padding(.top, Theme.Spacing.xs)

                    ForEach(Array(vm.trackedSites.enumerated()), id: \.element) { index, site in
                        metricRow(
                            .site(site),
                            series: vm.siteSeries(site),
                            fallbackValue: vm.latestPerSite[site]?.valueCm,
                            order: 3 + index
                        )
                    }
                }

                if !vm.untrackedSites.isEmpty {
                    Button {
                        showCheckIn = true
                    } label: {
                        Text("+ Track another · \(vm.untrackedSites.map { $0.displayName.lowercased() }.joined(separator: ", "))")
                            .font(Theme.Fonts.body(14, .semibold))
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous)
                                    .strokeBorder(Theme.Colors.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }
                    }
                    .buttonStyle(.pressable)
                }

                if let insight = vm.insightText {
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Theme.Colors.primary)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("More than the scale")
                                .font(Theme.Fonts.body(15, .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(insight)
                                .font(Theme.Fonts.body(13))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .tile(Theme.Colors.primarySoft, shadow: false)
                    .popIn(order: 3 + vm.trackedSites.count)
                }

                if !vm.milestones(units: units).isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        TileEyebrow("Meaningful changes")
                        ForEach(vm.milestones(units: units)) { milestone in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Theme.Colors.primary)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(milestone.title)
                                        .font(Theme.Fonts.body(14, .semibold))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text(milestone.detail)
                                        .font(Theme.Fonts.body(12))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .tile()
                        }
                    }
                }

                Button {
                    showCheckIn = true
                } label: {
                    Text("+ Log check-in")
                        .font(Theme.Fonts.body(15, .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.Colors.primarySoft)
                        .foregroundStyle(Theme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
            .padding(Theme.Spacing.page)
            .padding(.bottom, Theme.Spacing.xl)
            .opacity(vm.isLoading ? 0.5 : 1)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .daylightSubpage("Body")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showGoals = true
                } label: {
                    Image(systemName: "scope")
                        .foregroundStyle(Theme.Colors.primary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Body goals")
            }
        }
        .task(id: vm.selectedRange) {
            await vm.loadData()
        }
        .sheet(isPresented: $showGoals) {
            BodyGoalsSheet(current: vm.goals) { weightKg, bodyFatPct, leanKg in
                await vm.saveGoals(
                    weightKgTarget: weightKg,
                    bodyFatPctTarget: bodyFatPct,
                    leanMassKgFloor: leanKg
                )
            }
        }
        .sheet(isPresented: $showCheckIn) {
            BodyCompositionSheet(
                current: todayVM.bodyComp,
                heightCm: heightCm
            ) { weightKg, bodyFatPct, bmi, lbmKg, measurementsCm, writeToHK in
                await todayVM.saveBodyComposition(
                    weightKg: weightKg, bodyFatPct: bodyFatPct, bmi: bmi,
                    lbmKg: lbmKg, measurementsCm: measurementsCm, writeToHK: writeToHK
                )
                await vm.loadData()
            }
        }
    }

    // MARK: - Row

    private func metricRow(
        _ metric: BodyMetric,
        series: [(date: Date, value: Double)],
        fallbackValue: Double?,
        order: Int
    ) -> some View {
        NavigationLink {
            BodyMetricHistoryView(metric: metric)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(metric.color)
                    .frame(width: 32, height: 32)
                    .background(metric.color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.title)
                        .font(Theme.Fonts.body(15, .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    subline(metric, series: series)
                }

                Spacer()

                if series.count >= 2 {
                    sparkline(series, color: metric.color)
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text(currentText(metric, series: series, fallback: fallbackValue))
                        .font(Theme.Fonts.number(16, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    // Quiet by design: the goal is a caption, not a progress meter.
                    if let goal = vm.goalValue(for: metric) {
                        Text("\(metric.goalNoun) \(metric.format(goal, units: units))")
                            .font(Theme.Fonts.body(10, .semibold))
                            .foregroundStyle(Theme.Colors.textFaint)
                            .monospacedDigit()
                    }
                }
                .frame(minWidth: 56, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textFaint)
            }
            .frame(minHeight: 44)
            .tile(radius: Theme.Radius.tileSmall)
        }
        .buttonStyle(.pressable)
        .popIn(order: order)
    }

    private func sparkline(_ series: [(date: Date, value: Double)], color: Color) -> some View {
        Chart(Array(series.enumerated()), id: \.offset) { _, point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(width: 56, height: 24)
        .chartDrawIn()
        .accessibilityHidden(true)
    }

    private func currentText(_ metric: BodyMetric, series: [(date: Date, value: Double)], fallback: Double?) -> String {
        guard let value = series.last?.value ?? fallback else { return "—" }
        return metric.format(value, units: units)
    }

    @ViewBuilder
    private func subline(_ metric: BodyMetric, series: [(date: Date, value: Double)]) -> some View {
        if let delta = BodyHubViewModel.delta(series) {
            // Lean mass is a floor — held is the happy state, and it says so.
            if case .leanMass = metric,
               BodyHubViewModel.leanHeldSteady(deltaKg: delta, baselineKg: series.first?.value) == true {
                Text("holding steady")
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.NutrientColor.fiber)
            } else {
                Text(deltaText(metric, delta: delta))
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        } else if series.count == 1 {
            Text("1 entry \(vm.selectedRange.phrase)")
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Colors.textSecondary)
        } else {
            Text("No entries \(vm.selectedRange.phrase)")
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Colors.textFaint)
        }
    }

    private func deltaText(_ metric: BodyMetric, delta: Double) -> String {
        let arrow = delta < 0 ? "↓" : "↑"
        let magnitude = metric.formatDelta(abs(delta), units: units)
        return "\(arrow) \(magnitude) \(vm.selectedRange.phrase)"
    }
}
