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
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Picker("Range", selection: $vm.selectedRange) {
                    ForEach(BodyHubViewModel.TimeRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                metricRow(
                    .weight,
                    series: vm.weightSeries,
                    fallbackValue: todayVM.bodyComp.weightKg
                )
                metricRow(
                    .bodyFat,
                    series: vm.bodyFatSeries,
                    fallbackValue: todayVM.bodyComp.bodyFatPct
                )
                metricRow(
                    .leanMass,
                    series: vm.leanSeries,
                    fallbackValue: todayVM.bodyComp.lbmKg
                )

                if !vm.trackedSites.isEmpty {
                    Text("MEASUREMENTS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.Colors.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Theme.Spacing.xs)

                    ForEach(vm.trackedSites) { site in
                        metricRow(
                            .site(site),
                            series: vm.siteSeries(site),
                            fallbackValue: vm.latestPerSite[site]?.valueCm
                        )
                    }
                }

                if !vm.untrackedSites.isEmpty {
                    Button {
                        showCheckIn = true
                    } label: {
                        Text("+ Track another · \(vm.untrackedSites.map { $0.displayName.lowercased() }.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Theme.Colors.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }
                    }
                    .buttonStyle(.plain)
                }

                if let insight = vm.insightText {
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Theme.Colors.primary)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("More than the scale")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(insight)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button {
                    showCheckIn = true
                } label: {
                    Text("+ Log check-in")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.primary.opacity(0.12))
                        .foregroundStyle(Theme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
            .opacity(vm.isLoading ? 0.5 : 1)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
        .toolbar(.visible, for: .navigationBar)
        .task(id: vm.selectedRange) {
            await vm.loadData()
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
        fallbackValue: Double?
    ) -> some View {
        NavigationLink {
            BodyMetricHistoryView(metric: metric)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 17))
                    .foregroundStyle(metric.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    subline(metric, series: series)
                }

                Spacer()

                if series.count >= 2 {
                    sparkline(series, color: metric.color)
                }

                Text(currentText(metric, series: series, fallback: fallbackValue))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(minWidth: 56, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.md)
            .card()
        }
        .buttonStyle(.plain)
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
                    .font(.caption)
                    .foregroundStyle(Theme.NutrientColor.fiber)
            } else {
                Text(deltaText(metric, delta: delta))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if series.count == 1 {
            Text("1 entry \(vm.selectedRange.phrase)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("No entries \(vm.selectedRange.phrase)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func deltaText(_ metric: BodyMetric, delta: Double) -> String {
        let arrow = delta < 0 ? "↓" : "↑"
        let magnitude = metric.formatDelta(abs(delta), units: units)
        return "\(arrow) \(magnitude) \(vm.selectedRange.phrase)"
    }
}
