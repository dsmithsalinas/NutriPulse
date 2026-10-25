import SwiftUI

enum PulseHealthDestination: String, Identifiable { case week, cycle, experiment; var id: String { rawValue } }

struct HealthMetricTile: View {
    let metric: HealthPatternMetric
    var fill: Color = Theme.Colors.surfaceCard
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            TileEyebrow(metric.title)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) { value; unit }
                VStack(alignment: .leading, spacing: 2) { value; unit }
            }
            Text(metric.caption).font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.tileSmall))
    }
    private var value: some View { Text(metric.value).font(Theme.Fonts.number(32)).foregroundStyle(Theme.Colors.textPrimary) }
    private var unit: some View { Text(metric.unit).font(Theme.Fonts.body(13, .semibold)).foregroundStyle(Theme.Colors.textSecondary) }
}

struct HealthSummaryCard: View {
    let title: String
    let headline: String
    let detail: String
    let symbol: String
    var featured = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary).frame(width: 42, height: 42)
                    .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 6) {
                    TileEyebrow(title, color: featured ? Theme.Colors.violetLabel : Theme.Colors.textSecondary)
                    Text(headline).font(Theme.Fonts.display(featured ? 22 : 18, .bold, relativeTo: .headline))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).padding(.top, 4)
            }.foregroundStyle(Theme.Colors.textPrimary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(featured ? Theme.Colors.violet : Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
        }.buttonStyle(.plain).accessibilityIdentifier("health-summary-\(title)")
    }
}

#if DEBUG
struct PulseHealthPreviewScreen: View {
    @State private var selected = MainTab.pulse
    @State private var barHeight: CGFloat = 0
    var body: some View {
        CoachView(isActive: true)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MainTabBar(selected: $selected, showsPulse: true, compact: false, onLog: {})
            }
            .onPreferenceChange(TabBarHeightKey.self) { barHeight = $0 }
            .environment(\.tabBarHeight, barHeight)
    }
}
#endif
