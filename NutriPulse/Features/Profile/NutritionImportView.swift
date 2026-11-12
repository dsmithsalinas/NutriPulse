import SwiftUI

struct NutritionImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    private var store: NutritionImportStore { .shared }
    @State private var requesting = false
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width >= 720 && typeSize < .xxxLarge {
                    HStack(alignment: .top, spacing: 24) {
                        ScrollView { VStack(alignment: .leading, spacing: 18) { introduction; guidance }.padding(18) }
                            .frame(maxWidth: .infinity)
                        ScrollView { choices(compact: true).padding(18) }
                            .accessibilityIdentifier("nutritionChoices").frame(maxWidth: .infinity)
                    }.daylightReadableWidth(1100)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            introduction; choices(compact: false); guidance
                        }.padding(Theme.Spacing.page).daylightReadableWidth(650)
                    }.accessibilityIdentifier("nutritionChoices")
                }
            }.background(Theme.Colors.ground)
                .navigationTitle("Nutrition sources").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .task { await store.discoverSources() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.discoverSources() } } }
        }.tint(Theme.Colors.primary)
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Log once. Choose where your numbers come from.")
                .font(Theme.Fonts.display(27, .bold, relativeTo: .title2))
            Text("Choose one source for each nutrient. Apple Health values replace Footing’s total for that nutrient; they are never added on top of your meals.")
                .font(Theme.Fonts.body(16))
            Button {
                requesting = true
                Task { await store.requestAccess(); requesting = false }
            } label: {
                Label(requesting ? "Requesting access…" : "Allow nutrition access", systemImage: "heart")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.borderedProminent).disabled(requesting || store.preview)
        }
    }
    private func choices(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 16) {
            ForEach(NutritionMacro.allCases) { macro in
                VStack(alignment: .leading, spacing: 4) {
                    if typeSize >= .xxxLarge {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(macro.title).font(Theme.Fonts.body(17, .bold))
                            sourcePicker(macro)
                        }
                    } else {
                        HStack {
                            Text(macro.title).font(Theme.Fonts.body(17, .bold))
                            Spacer(minLength: 8)
                            sourcePicker(macro)
                        }
                    }
                    if let source = store.selections[macro] {
                        let day = store.resolved(.init(date: .now, calories: 0, proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0))
                        Text(day.unavailableMacros.contains(macro)
                             ? "No data today from \(source.name)"
                             : "\(Int(macro.value(in: day).rounded()))\(macro == .calories ? " kcal" : "g") today · via Apple Health")
                            .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    } else if !compact {
                        Text("Uses food logged in Footing").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if macro != .fiber { Divider() }
                }
            }
        }.tile(padding: compact ? 12 : 16)
    }
    private func sourcePicker(_ macro: NutritionMacro) -> some View {
        Menu {
            Button("Footing") { store.select(nil, for: macro) }
                .accessibilityIdentifier("nutrition-choice-\(macro.rawValue)-footing")
            ForEach(sources(for: macro)) { source in
                Button(source.name) { store.select(source, for: macro) }
                    .accessibilityIdentifier("nutrition-choice-\(macro.rawValue)-\(source.id)")
            }
        } label: {
            HStack { Text(store.sourceName(for: macro)); Image(systemName: "chevron.up.chevron.down") }
                .font(Theme.Fonts.body(14, .semibold)).frame(minHeight: 44)
        }.accessibilityIdentifier("nutrition-source-\(macro.rawValue)")
    }
    private var guidance: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your meals stay in Footing. Selecting another source changes totals only, including past days. Use an app that records all of that nutrient for the day. Logging extra meals here will not increase a nutrient sourced elsewhere.")
            Text("Sources appear when Health has readable entries from the last 90 days. No data can mean no entries or no read permission. Review access in Health → your profile → Apps and Services → Footing. Missing values stay unknown; calories are not estimated from carbs.")
            Text("Nutrition stays on this iPhone. If you use Pulse with AI sharing enabled, its nutrition context uses your selected totals.")
            if let error = store.errorMessage { Text(error).foregroundStyle(Theme.Colors.danger) }
            Button(store.isLoading ? "Refreshing…" : "Refresh sources") { Task { await store.discoverSources() } }
                .frame(minHeight: 44).disabled(store.isLoading || store.preview)
        }.font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
    }
    private func sources(for macro: NutritionMacro) -> [NutritionSource] {
        var sources = store.availableSources[macro] ?? []
        if let selected = store.selections[macro], !sources.contains(where: { $0.id == selected.id }) { sources.append(selected) }
        return sources
    }
}

struct NutritionSourceSummary: View {
    let day: DailySummary
    var body: some View {
        if !day.nutritionSources.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Nutrition sources", systemImage: "heart.text.square").font(Theme.Fonts.body(14, .bold))
                ForEach(NutritionMacro.allCases.filter { day.nutritionSources[$0] != nil }) { macro in
                    Text("\(macro.title): \(day.unavailableMacros.contains(macro) ? "No data" : "\(Int(macro.value(in: day).rounded()))\(macro == .calories ? " kcal" : "g")") · \(day.nutritionSources[macro]!) · via Apple Health")
                        .font(Theme.Fonts.body(13)).fixedSize(horizontal: false, vertical: true)
                }
                Text("Selected sources replace Footing totals. Your meal diary may be partial.")
                    .font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
            }.frame(maxWidth: .infinity, alignment: .leading).tile(padding: 14)
        }
    }
}
