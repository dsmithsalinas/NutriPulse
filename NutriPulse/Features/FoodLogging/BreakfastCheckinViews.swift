import SwiftUI

struct BreakfastCheckinSettings: View {
    private var store: BreakfastCheckinStore { .shared }
    @State private var error: String?
    private var breakfasts: [UsualMeal] { UsualMealStore.shared.meals.filter { $0.meal == .breakfast } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TileEyebrow("Lighter breakfast check-ins")
            Text("Choose a saved breakfast for a simple “Had my usual” check-in. No portions or nutrients are assumed.")
                .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            if breakfasts.isEmpty {
                Text("Save a usual breakfast from a logged meal to get started.").font(Theme.Fonts.body(14))
            }
            ForEach(breakfasts) { meal in
                Button {
                    Task { do { try await store.enable(meal); error = nil } catch { self.error = "Couldn’t save your choice. Please try again." } }
                } label: {
                    HStack { Text(meal.name); Spacer(); Image(systemName: store.preference?.usualMealId == meal.id ? "checkmark.circle.fill" : "circle") }
                        .font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44)
                }.buttonStyle(.plain).disabled(store.isSaving)
                    .accessibilityLabel("Use simple check-ins for \(meal.name)")
            }
            if store.preference != nil {
                Button("Turn off simple breakfast check-ins") {
                    Task { do { try await store.disable(); error = nil } catch { self.error = "Couldn’t save your choice. Please try again." } }
                }.font(Theme.Fonts.body(14)).frame(minHeight: 44).disabled(store.isSaving)
            }
            if store.loadFailed || UsualMealStore.shared.loadFailed {
                Button("Couldn’t refresh breakfast choices. Retry") { Task { await UsualMealStore.shared.load(); await store.load() } }.frame(minHeight: 44)
            }
            if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
            Text("Detailed logging is always available. Skipping a check-in creates no missed goal.")
                .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
        }.tile().tint(Theme.Colors.primary).task { await UsualMealStore.shared.load(); await store.load() }
    }
}

struct BreakfastCheckinCard: View {
    let date: Date
    let hasDetailedBreakfast: Bool
    let onLogDifferently: () -> Void
    private var store: BreakfastCheckinStore { .shared }
    @State private var error: String?
    private var record: BreakfastCheckin? { store.checkins.first { $0.localDay == date.isoDateString } }
    var body: some View {
        if record != nil || (date.isToday && store.usualBreakfast != nil && !hasDetailedBreakfast) {
            VStack(alignment: .leading, spacing: 12) {
                TileEyebrow("Breakfast · Simple check-in")
                if let record {
                    Text(record.name).font(Theme.Fonts.body(17, .semibold))
                    Text("Breakfast checked in. Amounts and nutrients unknown.").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    Button("Undo check-in") {
                        Task { do { try await store.undo(record); error = nil } catch { self.error = "Couldn’t undo this check-in. Please try again." } }
                    }.font(Theme.Fonts.body(14, .semibold)).frame(minHeight: 44).disabled(store.isSaving)
                } else if let meal = store.usualBreakfast {
                    Text(meal.name).font(Theme.Fonts.body(17, .semibold))
                    Button(store.isSaving ? "Saving…" : "Had my usual") {
                        Task { do { try await store.checkIn(meal, on: date); error = nil } catch { self.error = "Couldn’t save this check-in. It hasn’t been recorded yet." } }
                    }.buttonStyle(.brandPrimary).disabled(store.isSaving)
                    Button("Something different · Add a note or details", action: onLogDifferently)
                        .font(Theme.Fonts.body(14)).frame(minHeight: 44)
                    Text("Optional. No portions to enter and no goals inferred.").font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                }
                if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
            }.tile().tint(Theme.Colors.primary)
        }
    }
}
