import SwiftUI

// Daylight Favorites tab (docs/daylight-redesign.md): a favorites grid, then "Recents from the
// last 72 hours" grouped by day. Every "+" logs straight to the header meal; the star on a
// Recents row favorites that food (which then drops out of Recents).
struct FavoritesView: View {
    @Bindable var vm: FavoritesViewModel
    let date: Date
    let headerMeal: Meal
    let onLogged: (LogSource, _ keepOpen: Bool) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if vm.isEmpty {
                    BrandedEmptyState(
                        icon: "star",
                        title: "No favorites yet",
                        message: "Star a food from Search, or log something — it'll show up here so you can log it again in one tap."
                    )
                } else {
                    if !vm.favorites.isEmpty {
                        sectionHeader("Favorites")
                        favoritesGrid
                    }
                    if !vm.recentSections.isEmpty {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Recents")
                                .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer(minLength: 0)
                            Text("Last 72 hours")
                                .font(Theme.Fonts.body(13, .semibold))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .padding(.top, vm.favorites.isEmpty ? 0 : 6)

                        ForEach(vm.recentSections) { section in
                            TileEyebrow(section.label, color: Theme.Colors.textFaint)
                                .padding(.top, 2)
                            ForEach(section.logs) { log in
                                RecentRow(
                                    log: log,
                                    onStar: { await vm.addToFavorites(log) },
                                    onLogAgain: {
                                        let ok = await vm.logAgain(log, meal: headerMeal, date: date)
                                        if ok { onLogged(.favorite, true) }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .task { await vm.load() }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
            .foregroundStyle(Theme.Colors.textPrimary)
    }

    private var favoritesGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(vm.favorites.enumerated()), id: \.element.id) { index, fav in
                FavoriteTile(fav: fav) {
                    let ok = await vm.logFavorite(fav, meal: headerMeal, date: date)
                    if ok { onLogged(.favorite, true) }
                }
                .popIn(order: index)
            }
        }
    }
}

// MARK: - Favorite grid tile

private struct FavoriteTile: View {
    let fav: FavoriteQuickAdd
    let onLog: () async -> Void

    @State private var isLogging = false
    @State private var didLog = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fav.name)
                    .font(Theme.Fonts.body(14, .bold))
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text("\(Int((fav.proteinGSnapshot * fav.quantity).rounded()))g")
                    .font(Theme.Fonts.display(22, .extraBold, relativeTo: .title2))
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            Spacer(minLength: 4)
            Button {
                guard !isLogging, !didLog else { return }
                Task {
                    isLogging = true
                    await onLog()
                    isLogging = false
                    didLog = true
                }
            } label: {
                Group {
                    if isLogging {
                        ProgressView().tint(.white)
                    } else if didLog {
                        Image(systemName: "checkmark")
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.Colors.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.pressable)
            .disabled(isLogging || didLog)
            .accessibilityLabel(didLog ? "\(fav.name) added to log" : "Log \(fav.name)")
        }
        .padding(12)
        .frame(height: 96, alignment: .topLeading)
        .tile(radius: Theme.Radius.tileSmall, padding: 0)
    }
}

// MARK: - Recents row

private struct RecentRow: View {
    let log: FoodLog
    let onStar: () async -> Void
    let onLogAgain: () async -> Void

    @State private var isStarring = false
    @State private var starred = false
    @State private var isLogging = false
    @State private var didLog = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.displayName)
                    .font(Theme.Fonts.body(14, .bold))
                    .lineLimit(1)
                Text(detailLine)
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            Text("\(Int(log.totalProteinG.rounded()))g")
                .font(Theme.Fonts.number(14))
                .foregroundStyle(Theme.Colors.primaryText)

            Button {
                guard !isStarring, !starred else { return }
                Task {
                    isStarring = true
                    await onStar()
                    isStarring = false
                    starred = true
                }
            } label: {
                Group {
                    if isStarring {
                        ProgressView()
                    } else {
                        Image(systemName: starred ? "star.fill" : "star")
                    }
                }
                .foregroundStyle(starred ? Color.yellow : Theme.Colors.textSecondary)
                .frame(width: 40, height: 40)
                .background(starred ? Color.yellow.opacity(0.18) : Theme.Colors.surfaceInset,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.pressable)
            .disabled(isStarring || starred)
            .accessibilityLabel("Add \(log.displayName) to favorites")

            Button {
                guard !isLogging, !didLog else { return }
                Task {
                    isLogging = true
                    await onLogAgain()
                    isLogging = false
                    didLog = true
                }
            } label: {
                Group {
                    if isLogging {
                        ProgressView()
                    } else if didLog {
                        Image(systemName: "checkmark")
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(width: 40, height: 40)
                .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.pressable)
            .disabled(isLogging || didLog)
            .accessibilityLabel(didLog ? "\(log.displayName) added to log" : "Log \(log.displayName) again")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 58)
        .tile(radius: Theme.Radius.row, padding: 0)
        // Starring hides this row on the next load; fading it first avoids a jarring pop.
        .opacity(starred ? 0.4 : 1)
    }

    private var detailLine: String {
        let time = log.loggedAt.formatted(date: .omitted, time: .shortened)
        let servings = log.quantity == 1 ? "1 serving" : "\(log.quantity.formatted()) servings"
        return "\(log.meal.displayName) · \(time) · \(servings)"
    }
}
