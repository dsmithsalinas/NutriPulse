import SwiftUI

struct ProteinRescueSheet: View {
    let date: Date
    let proteinGap: Int
    let calorieRoom: Int
    let onLogged: () -> Void
    let onBuildMyOwn: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var favorites: [FavoriteQuickAdd] = []
    @State private var isLoading = true
    @State private var loggingOptionID: String?
    // If a two-food option partially saves, retry only the remaining row. Without this,
    // a transient failure on item two would duplicate item one under a fresh log UUID.
    @State private var loggedFoodIDs: Set<UUID> = []
    @State private var errorMessage: String?
    private let repository = FavoriteRepository()

    private var options: [ProteinRescueOption] {
        ProteinRescuePlanner.options(
            favorites: favorites,
            proteinGap: proteinGap,
            calorieRoom: calorieRoom
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Close the floor")
                            .font(Theme.Fonts.display(24, .bold, relativeTo: .title))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("You're about \(proteinGap)g short. These use foods you already trust and log the whole option in one tap.")
                            .font(Theme.Fonts.body(14))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    if isLoading {
                        ProgressView("Finding your easiest options…")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else if options.isEmpty {
                        BrandedEmptyState(
                            icon: "fork.knife.circle",
                            title: "Build your first rescue",
                            message: "Favorite a few protein foods and Footing will combine them here. For now, tell Pulse what sounds manageable."
                        )
                    } else {
                        ForEach(options) { option in
                            rescueRow(option)
                        }
                    }

                    Button("Build my own") {
                        dismiss()
                        onBuildMyOwn()
                    }
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(Theme.Spacing.page)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationTitle("Protein rescue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Theme.Colors.primary)
        .task { await loadFavorites() }
        .alert("Couldn't log that", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func rescueRow(_ option: ProteinRescueOption) -> some View {
        Button {
            Task { await log(option) }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(Theme.Fonts.body(15, .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text("\(option.proteinG)g protein · \(option.calories) kcal")
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                if loggingOptionID == option.id {
                    ProgressView()
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .contentShape(Rectangle())
            .tile(radius: Theme.Radius.row)
        }
        .buttonStyle(.plain)
        .disabled(loggingOptionID != nil)
    }

    private func loadFavorites() async {
        defer { isLoading = false }
        favorites = (try? await repository.fetchQuickAdds()) ?? []
    }

    private func log(_ option: ProteinRescueOption) async {
        loggingOptionID = option.id
        defer { loggingOptionID = nil }
        do {
            for food in option.foods {
                guard !loggedFoodIDs.contains(food.foodItemId) else { continue }
                try await repository.quickLog(food, on: date, meal: .current)
                loggedFoodIDs.insert(food.foodItemId)
            }
            Telemetry.proteinRescueLogged(itemCount: option.foods.count)
            onLogged()
            dismiss()
        } catch {
            errorMessage = "Your foods are still here. Check your connection and try again."
        }
    }
}
