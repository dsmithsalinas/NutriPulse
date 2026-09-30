import SwiftUI

// Daylight Search tab (docs/daylight-redesign.md): filter chips (All / Protein-dense / My
// foods), favorites-first results, a "+" that logs straight to the header meal, tapping a
// name that opens the confirm sheet, and manual entry moved here ("Can't find it? Enter it
// yourself").
struct FoodSearchView: View {
    @Bindable var vm: FoodSearchViewModel
    let date: Date
    let headerMeal: Meal
    let onLogged: (LogSource, _ keepOpen: Bool) -> Void
    let onEnterManually: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.tileGap) {
            searchField
            filterChips

            Group {
                if vm.searchQuery.isEmpty {
                    placeholder(icon: "magnifyingglass", text: "Search millions of foods from the FatSecret database")
                } else if vm.isSearching {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.filteredResults.isEmpty {
                    placeholder(icon: "questionmark.circle", text: emptyResultsText)
                } else {
                    resultsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            enterManuallyButton
            FatSecretAttribution()
        }
        .task { await vm.loadFavoritedExternalIds() }
        // SWIFT CONCEPT — .task(id:) re-runs the async block whenever `id` changes,
        // and cancels the previous run. Combined with Task.sleep this gives us
        // debounce without Combine — identical to useEffect with a cleanup fn in React.
        .task(id: vm.searchQuery) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await vm.search()
        }
        .sheet(item: $vm.selectedResult) { result in
            FoodDetailSheet(vm: vm, result: result, date: date, source: .search, onLogged: { source in
                onLogged(source, false)
            })
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

    private var emptyResultsText: String {
        vm.selectedFilter == .all
            ? "No results for \"\(vm.searchQuery)\""
            : "No \(vm.selectedFilter.rawValue.lowercased()) results for \"\(vm.searchQuery)\""
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.textSecondary)
            TextField("Search foods…", text: $vm.searchQuery)
                .font(Theme.Fonts.body(16, .semibold))
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel("Search foods")
            if !vm.searchQuery.isEmpty {
                Button { vm.searchQuery = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous)
                .strokeBorder(vm.searchQuery.isEmpty ? Theme.Colors.hairline : Theme.Colors.primary, lineWidth: 2)
        }
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(SearchFilter.allCases) { filter in
                let selected = vm.selectedFilter == filter
                Button { vm.selectedFilter = filter } label: {
                    HStack(spacing: 6) {
                        if filter == .proteinDense && !selected {
                            Circle().fill(Theme.Colors.primary).frame(width: 8, height: 8)
                        }
                        Text(filter.rawValue)
                    }
                    .font(Theme.Fonts.body(13, selected ? .bold : .semibold))
                    .foregroundStyle(selected ? .white : Theme.Colors.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(selected ? Theme.Colors.ink : Theme.Colors.surfaceCard, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(vm.filteredResults.enumerated()), id: \.element.id) { index, result in
                    SearchResultRow(
                        result: result,
                        isFavorited: vm.favoritedExternalIds.contains(result.id),
                        isQuickLogging: vm.quickLoggingID == result.id,
                        isQuickLogged: vm.quickLoggedIDs.contains(result.id),
                        onOpen: {
                            vm.selectedMeal = headerMeal
                            Task { await vm.loadDetail(for: result) }
                        },
                        onQuickLog: {
                            Task {
                                await vm.quickLog(result, meal: headerMeal, on: date)
                                onLogged(.search, true)
                            }
                        }
                    )
                    .popIn(order: index)
                    .onAppear {
                        guard result.id == vm.filteredResults.last?.id else { return }
                        Task { await vm.loadMoreResults() }
                    }
                }
                if vm.isLoadingMoreResults {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func placeholder(icon: String, text: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.textFaint)
            Text(text)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Manual entry link

    private var enterManuallyButton: some View {
        Button(action: onEnterManually) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                Text("Can't find it? Enter it yourself")
            }
            .font(Theme.Fonts.body(14, .bold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.tileSmall, style: .continuous)
                    .strokeBorder(Theme.Colors.textFaint, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }
        }
        .buttonStyle(.pressable)
    }
}

// ─── Result row ───────────────────────────────────────────────────────────────

private struct SearchResultRow: View {
    let result: FoodSearchResult
    let isFavorited: Bool
    let isQuickLogging: Bool
    let isQuickLogged: Bool
    let onOpen: () -> Void
    let onQuickLog: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.name)
                        .font(Theme.Fonts.body(15, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if isFavorited {
                            Text("★ Favorite")
                                .font(Theme.Fonts.body(11, .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                // A Tailwind amber-100/900 pairing (also used by the mockups) for
                                // the accessible contrast a plain `.yellow` tint can't guarantee —
                                // a one-off badge, not a recurring need, so it isn't a Theme token.
                                .background(Color(hex: 0xFEF3C7), in: Capsule())
                                .foregroundStyle(Color(hex: 0x92400E))
                        }
                        Text(subtitle)
                            .font(Theme.Fonts.body(12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let macros = FoodSearchMacros.parse(result.description) {
                Text("\(Int(macros.proteinG.rounded()))g")
                    .font(Theme.Fonts.number(15))
                    .foregroundStyle(Theme.Colors.primaryText)
            }

            Button(action: onQuickLog) {
                Group {
                    if isQuickLogging {
                        ProgressView().tint(plusForeground)
                    } else if isQuickLogged {
                        Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                    } else {
                        Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(plusForeground)
                .frame(width: 44, height: 44)
                .background(plusBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(isQuickLogging || isQuickLogged)
            .accessibilityLabel(isQuickLogged ? "\(result.name) added to log" : "Log \(result.name)")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 68)
        .tile(radius: Theme.Radius.row, padding: 0)
    }

    private var plusForeground: Color { isFavorited ? .white : Theme.Colors.primaryText }
    private var plusBackground: Color { isFavorited ? Theme.Colors.primary : Theme.Colors.surfaceInset }

    private var subtitle: String {
        var parts: [String] = [result.brand ?? "Generic"]
        if let macros = FoodSearchMacros.parse(result.description) {
            parts.append("\(Int(macros.calories.rounded())) cal")
        }
        return parts.joined(separator: " · ")
    }
}

// ─── Detail sheet ─────────────────────────────────────────────────────────────
// Shown after tapping a search result's name. Lets the user pick a serving, quantity,
// and meal before logging.
struct FoodDetailSheet: View {
    @Bindable var vm: FoodSearchViewModel
    let result: FoodSearchResult
    let date: Date
    // FoodDetailSheet is shared by the regular search flow and the barcode
    // scan flow — each caller hardcodes which one it is.
    let source: LogSource
    let onLogged: (LogSource) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingDetail {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail = vm.detail {
                    detailForm(detail: detail)
                } else {
                    // Reached whenever the load failed. Without this branch the sheet
                    // rendered empty — no macros, no Log button, no error, no way out
                    // but Cancel.
                    loadFailedView
                }
            }
            .navigationTitle(result.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.cancelDetail()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        vm.wantsToFavorite.toggle()
                    } label: {
                        Image(systemName: vm.wantsToFavorite ? "star.fill" : "star")
                            .foregroundStyle(vm.wantsToFavorite ? Color.yellow : Theme.Colors.textPrimary)
                    }
                    .accessibilityLabel(vm.wantsToFavorite ? "Remove from favorites" : "Add \(result.name) to favorites")
                }
            }
            // Must live inside the sheet. Bound to the presenting view, this alert never
            // appeared: a failed "Log Food" just stopped the spinner and did nothing.
            .alert("Couldn't log food", isPresented: Binding(
                get: { vm.logError != nil },
                set: { if !$0 { vm.logError = nil } }
            )) {
                Button("OK") { vm.logError = nil }
            } message: {
                Text(vm.logError ?? "")
            }
        }
        .tint(Theme.Colors.primary)
    }

    private var loadFailedView: some View {
        VStack(spacing: 12) {
            BrandedEmptyState(
                icon: "wifi.exclamationmark",
                title: "Couldn't load this food",
                message: vm.detailError ?? "Something went wrong."
            )
            Button("Try Again") {
                Task { await vm.loadDetail(for: result) }
            }
            .buttonStyle(.brandPrimary)
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.ground.ignoresSafeArea())
    }

    @ViewBuilder
    private func detailForm(detail: FoodDetail) -> some View {
        Form {
            // ── Serving picker ────────────────────────────────────────────
            if detail.servings.count > 1 {
                Section {
                    Picker("Serving", selection: $vm.selectedServing) {
                        ForEach(detail.servings) { serving in
                            Text(serving.description).tag(Optional(serving))
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    DaylightSectionHeader("Serving size")
                }
                .daylightSection()
            }

            // ── Meal + quantity ───────────────────────────────────────────
            Section {
                Picker("Meal", selection: $vm.selectedMeal) {
                    ForEach(Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { meal in
                        Label(meal.displayName, systemImage: meal.icon).tag(meal)
                    }
                }
                HStack {
                    Text("Servings").font(Theme.Fonts.body(16))
                    Spacer()
                    Text(vm.quantity.formatted())
                        .font(Theme.Fonts.body(16))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Stepper("", value: $vm.quantity, in: 0.25...20, step: 0.25)
                        .labelsHidden()
                }
            }
            .daylightSection()

            // ── Macro preview ─────────────────────────────────────────────
            if let preview = vm.macroPreview {
                Section {
                    MacroPreviewRow(label: "Calories",  value: preview.calories,  unit: "kcal", color: Theme.NutrientColor.calories)
                    MacroPreviewRow(label: "Protein",   value: preview.proteinG,  unit: "g",    color: Theme.NutrientColor.protein)
                    MacroPreviewRow(label: "Carbs",     value: preview.carbsG,    unit: "g",    color: Theme.NutrientColor.carbs)
                    MacroPreviewRow(label: "Fat",       value: preview.fatG,      unit: "g",    color: Theme.NutrientColor.fat)
                    MacroPreviewRow(label: "Fiber",     value: preview.fiberG,    unit: "g",    color: Theme.NutrientColor.fiber)
                } header: {
                    DaylightSectionHeader("Nutrition (\(vm.quantity.formatted()) × \(vm.selectedServing?.description ?? ""))")
                }
                .daylightSection()
            }

            // FatSecret attribution — this sheet displays their nutrition data (from search
            // and barcode scans alike).
            Section {
                FatSecretAttribution()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .daylightForm()
        .safeAreaInset(edge: .bottom) { logButton }
    }

    private var logButton: some View {
        Button {
            Task {
                do {
                    try await vm.logFood(on: date)
                    vm.selectedResult = nil
                    onLogged(source)
                } catch {
                    vm.logError = error.localizedDescription
                }
            }
        } label: {
            if vm.isLogging {
                ProgressView().tint(.white)
            } else {
                Text("Log Food")
            }
        }
        .buttonStyle(.brandPrimary)
        .disabled(vm.isLogging || vm.selectedServing == nil)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
        .background(.bar)
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
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text(String(format: "%.1f %@", value, unit))
                .font(Theme.Fonts.body(15, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
        }
    }
}
