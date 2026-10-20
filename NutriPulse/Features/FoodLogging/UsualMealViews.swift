import SwiftUI
import Supabase

struct SaveUsualMealSheet: View {
    let foods: [FoodLog]
    var existing: UsualMeal? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saving = false
    @State private var error: String?
    @State private var pending: UsualMeal?

    init(foods: [FoodLog], existing: UsualMeal? = nil) {
        self.foods = foods
        self.existing = existing
        _name = State(initialValue: existing?.name ?? UsualMeal.suggestedName(for: foods))
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SheetHeader(title: existing == nil ? "Save a usual meal" : "Rename usual meal", onClose: { dismiss() })
            Text("Give this combination a name so it’s easier to find next time.").font(Theme.Fonts.body(16))
            Text("Meal name").font(Theme.Fonts.body(14, .semibold))
            TextField("Name this meal", text: $name).textFieldStyle(.roundedBorder)
                .font(Theme.Fonts.body(17)).accessibilityLabel("Meal name")
            if let message = UsualMeal.nameValidationMessage(name) {
                Text(message).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            }
            if foods.count > 40 { Text("A usual meal can contain up to 40 entries.").foregroundStyle(Theme.Colors.danger) }
            ForEach(foods) { Text("\($0.displayName) · \($0.quantity.formatted()) servings").font(Theme.Fonts.body(14)) }
            Text("Review and adjust portions each time you log it.").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
            Button(saving ? "Saving…" : "Save usual meal") {
                saving = true
                Task {
                    defer { saving = false }
                    do {
                        guard let id = supabase.auth.currentSession?.user.id, let meal = foods.first?.meal else { throw URLError(.userAuthenticationRequired) }
                        if pending == nil { pending = existing ?? UsualMeal(userId: id, name: name, meal: meal, items: foods) }
                        pending?.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        try await UsualMealStore.shared.save(pending!)
                        dismiss()
                    } catch { self.error = "Couldn’t save this usual meal. Check your connection and try again." }
                }
            }.buttonStyle(.brandPrimary).disabled(saving || foods.isEmpty || foods.count > 40 || UsualMeal.nameValidationMessage(name) != nil)
            Spacer()
        }.padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground)
            .interactiveDismissDisabled(saving)
    }
}

struct UsualMealsSection: View {
    let date: Date
    let meal: Meal
    let onSaved: () -> Void
    @Environment(\.foodSaveUndo) private var undo
    @State private var selected: UsualMeal?
    @State private var renaming: UsualMeal?
    @State private var deleting: UsualMeal?
    @State private var error: String?
    @State private var showBreakfastSettings = false
    private var store: UsualMealStore { .shared }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !store.meals.isEmpty {
                Text("Your usual meals").font(Theme.Fonts.body(16, .bold))
                ForEach(store.meals) { usual in
                    Button { selected = usual } label: {
                        HStack { Text(usual.name); Spacer(); Image(systemName: "chevron.right") }
                            .font(Theme.Fonts.body(15)).frame(minHeight: 44)
                    }.buttonStyle(.plain)
                    .accessibilityAction(named: "Rename") { renaming = usual }
                    .accessibilityAction(named: "Delete") { deleting = usual }
                    .contextMenu {
                        Button("Rename") { renaming = usual }
                        Button("Delete", role: .destructive) { deleting = usual }
                    }
                }
            }
            if store.meals.contains(where: { $0.meal == .breakfast }) {
                Button("Set up simple breakfast check-ins") { showBreakfastSettings = true }
                    .font(Theme.Fonts.body(14, .semibold)).frame(minHeight: 44)
            }
            if store.loadFailed {
                Button("Couldn’t refresh usual meals. Retry") { Task { await store.load() } }
                    .font(Theme.Fonts.body(14)).frame(minHeight: 44)
            }
            if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .task {
                #if DEBUG
                if DebugLaunch.tour { store.preview(); return }
                #endif
                await store.load()
            }
            .sheet(isPresented: $showBreakfastSettings) {
                ScrollView { BreakfastCheckinSettings().padding(Theme.Spacing.page) }.background(Theme.Colors.ground)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selected) { usual in
                UsualMealReview(usual: usual, date: date, meal: meal, onSaved: onSaved).environment(\.foodSaveUndo, undo)
            }
            .sheet(item: $renaming) { usual in SaveUsualMealSheet(foods: usual.items, existing: usual) }
            .confirmationDialog("Delete this usual meal?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete usual meal", role: .destructive) {
                    guard let item = deleting else { return }
                    Task { do { try await store.delete(item) } catch { self.error = "Couldn’t delete this meal. Please try again." } }
                }
            }
    }
}

struct UsualMealReview: View {
    let usual: UsualMeal
    let date: Date
    let meal: Meal
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.foodSaveUndo) private var undo
    @State private var quantities: [UUID: Double] = [:]
    @State private var saving = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SheetHeader(title: usual.name, onClose: { dismiss() })
                Text("Review portions · \(meal.displayName) · \(date.formatted(date: .abbreviated, time: .omitted))").font(Theme.Fonts.body(15))
                ForEach(usual.items) { item in
                    Stepper(value: Binding(get: { quantities[item.id] ?? item.quantity }, set: { quantities[item.id] = $0 }), in: 0.25...20, step: 0.25) {
                        Text("\(item.displayName) · \((quantities[item.id] ?? item.quantity).formatted()) servings").font(Theme.Fonts.body(15))
                    }
                }
                if let error { Text(error).foregroundStyle(Theme.Colors.danger) }
                Button(saving ? "Saving…" : "Log this meal") {
                    saving = true
                    Task {
                        defer { saving = false }
                        do {
                            guard let owner = supabase.auth.currentSession?.user.id, owner == usual.userId else { throw URLError(.userAuthenticationRequired) }
                            try FoodSaveUndo.$current.withValue(undo) {
                                try LocalStore.shared.insertRepeatedMeal(usual.items, quantities: quantities, userId: owner, logDate: date.isoDateString, meal: meal)
                            }
                            SyncEngine.shared.refreshPendingCount(); Task { await SyncEngine.shared.pushPendingChanges() }
                            dismiss(); onSaved()
                        } catch { self.error = "Couldn’t save this meal. Please try again." }
                    }
                }.buttonStyle(.brandPrimary).disabled(saving)
            }.padding(Theme.Spacing.page)
        }.background(Theme.Colors.ground).interactiveDismissDisabled(saving)
    }
}
