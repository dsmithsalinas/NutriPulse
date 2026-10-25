import SwiftUI

struct HealthPatternsView: View {
    let model: PulseHealthInsightsModel
    let kind: PulseHealthDestination
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showLighter = false
    @State private var showRecipe = false
    private var fit: CycleFitChoice? {
        guard let day = model.cycleDay, let owner = model.owner, EverydayToolsStore.shared.accountId == owner else { return nil }
        return EverydayToolsStore.shared.data.cycleFit(on: Date.now.isoDateString, cycleDay: day)
    }
    private var isCycle: Bool { kind == .cycle }
    private var lines: [HealthPatternLine] { isCycle ? model.cycle : model.weekly }
    private var metrics: [HealthPatternMetric] { lines.flatMap(\.metrics) }
    private var ownsScreen: Bool { model.isPreview || (model.owner != nil && model.owner == appState.session?.user.id && model.ownsScreen) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: isCycle ? "Your shot-cycle picture" : "Beyond the scale", onClose: { dismiss() })
                if ownsScreen {
                    VStack(alignment: .leading, spacing: 12) {
                        TileEyebrow(isCycle ? "Your experience" : "Last seven complete days", color: isCycle ? Theme.Colors.limeLabel : Theme.Colors.violetLabel)
                        Text(isCycle ? (fit == .different ? "Today comes first." : "A little context for today.") : "Your week is more than a number.")
                            .font(Theme.Fonts.display(30, .extraBold, relativeTo: .title)).fixedSize(horizontal: false, vertical: true)
                        Text(isCycle ? "Cycle day \(model.cycleDay ?? 0) · Your earlier check-ins, together." : "Movement, rest, and how you’ve been feeling.")
                            .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
                    }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                        .background(isCycle ? Theme.Colors.lime : Theme.Colors.violet, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
                    if isCycle && !lines.isEmpty, let owner = model.owner, let day = model.cycleDay {
                        CycleFitCard(owner: owner, cycleDay: day, preview: model.isPreview, onRecipe: { showRecipe = true }, onTellPulse: { choice in
                            guard !model.isPreview, appState.session?.user.id == owner else { return }
                            dismiss()
                            appState.askPulse("I reviewed my shot-cycle snapshot and said: \(choice.title). Start with how I feel today, ahead of historical patterns. Ask one useful question about my current experience before offering one manageable option. Don’t infer a symptom, change medication advice, or save a memory.")
                        })
                    }
                    if model.loading && lines.isEmpty { ProgressView("Gathering your observations…").frame(maxWidth: .infinity, minHeight: 80) }
                    if !metrics.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                            ForEach(metrics) { metric in
                                HealthMetricTile(metric: metric, fill: metric.id.lowercased().contains("sleep") ? Theme.Colors.sky : Theme.Colors.surfaceCard)
                            }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            TileEyebrow(isCycle ? "A snapshot, in context" : "Room for real life")
                            Text(isCycle ? "These are earlier experiences you shared. How you feel today can be different." : "Recorded days are part of the picture. Blank days don’t erase the movement or rest you’ve had.")
                                .font(Theme.Fonts.body(16)).fixedSize(horizontal: false, vertical: true)
                        }.tile()
                    } else if !model.loading {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("There’s room for this to grow.").font(Theme.Fonts.display(22, .bold, relativeTo: .headline))
                            Text(isCycle ? (model.interrupted ? "This cycle includes a skipped dose, so it won’t be compared with uninterrupted cycles." : "We need check-ins on this day from three completed cycles at the same medication and dose. Start with how you feel today.") : "Available Health observations and your check-ins will build this picture over time. There’s nothing to catch up on.")
                        }.font(Theme.Fonts.body(15)).tile()
                    }
                    if !model.isPreview && !HealthKitManager.shared.hasRequestedAuthorization {
                        Button("Use Apple Health observations") { Task { await model.load(force: true, requestAccess: true) } }
                            .buttonStyle(.brandPrimary).disabled(model.loading)
                    }
                    if let error = model.error { Text(error).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger) }
                    if isCycle && !lines.isEmpty {
                        Button("Choose a lighter few days") { showLighter = true }.buttonStyle(.brandPrimary)
                    }
                    DisclosureGroup("How Footing worked this out") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(lines) { Text($0.text) }
                            Text(isCycle ? "Matches the same cycle day across at least three completed cycles at the same medication and dose. Current, interrupted and different-dose cycles are excluded. Up to six earlier cycles and 84 days of check-ins are considered. These observations don’t establish a medication effect or predict symptoms." : "Uses the last seven complete days. Coverage appears beside each number. Sleep, steps and energy need at least three observations. Missing data is not a rest day or a missed goal.")
                            Text("Computed on this phone. These observations aren’t sent to Pulse or saved as a memory. Source-conflicting or implausible sleep readings are excluded.")
                            if let message = model.accessMessage { Text(message) }
                            Button("Refresh observations") { Task { await model.load(force: true) } }.frame(minHeight: 44).disabled(model.loading)
                            Button("Choose Apple Health access") { Task { await model.load(force: true, requestAccess: true) } }.frame(minHeight: 44).disabled(model.loading)
                        }.font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary).padding(.top, 12)
                    }.font(Theme.Fonts.body(14, .semibold)).padding(18)
                        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tileSmall))
                }
            }.foregroundStyle(Theme.Colors.textPrimary).padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground).tint(Theme.Colors.primary)
        .task { await model.load() }
        .onChange(of: appState.session?.user.id) { _, _ in if !model.isPreview { dismiss() } }
        .sheet(isPresented: $showLighter) { LighterTrackingSheet() }
        .sheet(isPresented: $showRecipe) { if let owner = model.owner { EasierDayRecipeView(owner: owner, preview: model.isPreview) } }
    }
}

#if DEBUG
struct HealthPatternsPreviewPage: View {
    @State private var model = PulseHealthInsightsModel()
    var body: some View {
        HealthPatternsView(model: model, kind: ProcessInfo.processInfo.arguments.contains("--cycle-detail") ? .cycle : .week)
            .task { model.configure(owner: AppStoreScreenshotPreview.sampleUser); await model.load() }
    }
}
#endif
