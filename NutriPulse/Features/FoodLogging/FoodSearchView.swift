import SwiftUI

struct FoodSearchView: View {
    @Bindable var vm: FoodSearchViewModel
    let date: Date
    let onLogged: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Search bar ────────────────────────────────────────────────
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search foods…", text: $vm.searchQuery)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !vm.searchQuery.isEmpty {
                    Button { vm.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Theme.Spacing.sm)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            // ── Results ───────────────────────────────────────────────────
            Group {
                if vm.searchQuery.isEmpty {
                    if !vm.quickAdds.isEmpty {
                        FavoritesQuickAddList(quickAdds: vm.quickAdds, date: date, onLogged: onLogged)
                    } else {
                        placeholder(
                            icon: "magnifyingglass",
                            text: "Search millions of foods from the FatSecret database"
                        )
                    }
                } else if vm.isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.results.isEmpty {
                    placeholder(
                        icon: "questionmark.circle",
                        text: "No results for \"\(vm.searchQuery)\""
                    )
                } else {
                    List(vm.results) { result in
                        Button {
                            Task { await vm.loadDetail(for: result) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if let brand = result.brand {
                                    Text(brand)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(result.description)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .task { await vm.loadQuickAdds() }
        // SWIFT CONCEPT — .task(id:) re-runs the async block whenever `id` changes,
        // and cancels the previous run. Combined with Task.sleep this gives us
        // debounce without Combine — identical to useEffect with a cleanup fn in React.
        .task(id: vm.searchQuery) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await vm.search()
        }
        .sheet(item: $vm.selectedResult) { result in
            FoodDetailSheet(vm: vm, result: result, date: date, onLogged: onLogged)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func placeholder(icon: String, text: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.quaternary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ─── Detail sheet ─────────────────────────────────────────────────────────────
// Shown after tapping a search result. Lets the user pick a serving, quantity,
// and meal before logging.
struct FoodDetailSheet: View {
    @Bindable var vm: FoodSearchViewModel
    let result: FoodSearchResult
    let date: Date
    let onLogged: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingDetail {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail = vm.detail {
                    detailForm(detail: detail)
                }
            }
            .navigationTitle(result.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.selectedResult = nil
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        vm.wantsToFavorite.toggle()
                    } label: {
                        Image(systemName: vm.wantsToFavorite ? "star.fill" : "star")
                            .foregroundStyle(vm.wantsToFavorite ? Color.yellow : Color.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailForm(detail: FoodDetail) -> some View {
        Form {
            // ── Serving picker ────────────────────────────────────────────
            if detail.servings.count > 1 {
                Section("Serving size") {
                    Picker("Serving", selection: $vm.selectedServing) {
                        ForEach(detail.servings) { serving in
                            Text(serving.description).tag(Optional(serving))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // ── Meal + quantity ───────────────────────────────────────────
            Section {
                Picker("Meal", selection: $vm.selectedMeal) {
                    ForEach(Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { meal in
                        Label(meal.displayName, systemImage: meal.icon).tag(meal)
                    }
                }
                HStack {
                    Text("Servings")
                    Spacer()
                    Text(vm.quantity.formatted())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("", value: $vm.quantity, in: 0.25...20, step: 0.25)
                        .labelsHidden()
                }
            }

            // ── Macro preview ─────────────────────────────────────────────
            if let preview = vm.macroPreview {
                Section("Nutrition (\(vm.quantity.formatted()) × \(vm.selectedServing?.description ?? ""))") {
                    MacroPreviewRow(label: "Calories",  value: preview.calories,  unit: "kcal", color: Theme.NutrientColor.calories)
                    MacroPreviewRow(label: "Protein",   value: preview.proteinG,  unit: "g",    color: Theme.NutrientColor.protein)
                    MacroPreviewRow(label: "Carbs",     value: preview.carbsG,    unit: "g",    color: Theme.NutrientColor.carbs)
                    MacroPreviewRow(label: "Fat",       value: preview.fatG,      unit: "g",    color: Theme.NutrientColor.fat)
                    MacroPreviewRow(label: "Fiber",     value: preview.fiberG,    unit: "g",    color: Theme.NutrientColor.fiber)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { logButton }
    }

    private var logButton: some View {
        Button {
            Task {
                do {
                    try await vm.logFood(on: date)
                    vm.selectedResult = nil
                    onLogged()
                } catch {
                    vm.errorMessage = error.localizedDescription
                }
            }
        } label: {
            Group {
                if vm.isLogging {
                    ProgressView()
                } else {
                    Text("Log Food")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.NutrientColor.calories)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(vm.isLogging || vm.selectedServing == nil)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
        .background(.bar)
    }
}

// ─── Favorites quick-add section ─────────────────────────────────────────────

private struct FavoritesQuickAddList: View {
    let quickAdds: [FavoriteQuickAdd]
    let date: Date
    let onLogged: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(quickAdds) { fav in
                    FavoriteQuickAddRow(fav: fav, date: date, onLogged: onLogged)
                }
            } header: {
                Label("Favorites", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct FavoriteQuickAddRow: View {
    let fav: FavoriteQuickAdd
    let date: Date
    let onLogged: () -> Void

    @State private var isLogging = false
    private let repo = FavoriteRepository()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(fav.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(servingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: Theme.Spacing.sm) {
                Text("\(Int(fav.totalCalories)) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await logIt() }
                } label: {
                    Group {
                        if isLogging {
                            ProgressView().scaleEffect(0.75)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.NutrientColor.calories)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(isLogging)
            }
        }
        .padding(.vertical, 2)
    }

    private var servingText: String {
        let qty = fav.quantity == fav.quantity.rounded() ? "\(Int(fav.quantity))" : String(format: "%.1f", fav.quantity)
        let desc = fav.servingDesc ?? "serving"
        return "\(qty) × \(desc)"
    }

    private func logIt() async {
        isLogging = true
        defer { isLogging = false }
        do {
            try await repo.quickLog(fav, on: date)
            onLogged()
        } catch {}
    }
}

// ─── Macro preview row ────────────────────────────────────────────────────────

struct MacroPreviewRow: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
            Spacer()
            Text(String(format: "%.1f %@", value, unit))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}
