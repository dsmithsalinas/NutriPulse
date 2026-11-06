import SwiftUI

struct RestaurantContextBar: View {
    var context: FoodLoggingContext
    var locked: Bool
    var onOpen: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button(action: onOpen) {
                    Label(context.restaurant.map { "Restaurant: \($0.name)" } ?? "Restaurant (optional)", systemImage: "storefront")
                        .font(Theme.Fonts.body(14, .semibold)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.accessibilityIdentifier("restaurantPickerOpen")
                if context.restaurant != nil {
                    Button { context.clear() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("Remove restaurant").accessibilityIdentifier("restaurantClear")
                }
            }.padding(.horizontal, 12).background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 14))
                .disabled(locked)
            if locked { Text("Finish this entry or start over before changing the restaurant.").font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary) }
        }.foregroundStyle(Theme.Colors.primaryText)
    }
}

struct RestaurantPickerView: View {
    var context: FoodLoggingContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isTyping: Bool
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 }
    private var suggestions: [String] { FoodLoggingContext.knownRestaurants.filter { name.isEmpty || $0.localizedCaseInsensitiveContains(name) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DaylightPageTitle("Choose a restaurant", subtitle: "Use it for Search and Talk in this meal.")
                    TextField("Restaurant name", text: $name)
                        .font(Theme.Fonts.body(17)).padding(14)
                        .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: 14))
                        .focused($isTyping).submitLabel(.done).onSubmit { isTyping = false }
                        .textInputAutocapitalization(.words).autocorrectionDisabled()
                        .accessibilityIdentifier("restaurantName")
                    if name.count > 80 { Text("Use 80 characters or fewer.").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger) }
                    VStack(spacing: 0) {
                        ForEach(suggestions, id: \.self) { restaurant in
                            Button { name = restaurant; isTyping = false } label: {
                                HStack {
                                    Text(restaurant); Spacer()
                                    if name == restaurant { Image(systemName: "checkmark.circle.fill") }
                                }.font(Theme.Fonts.body(17, .semibold)).frame(minHeight: 52).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("restaurantSuggestion-\(restaurant)")
                            if restaurant != suggestions.last { Divider() }
                        }
                    }.tile(padding: 16)
                    Text("Use any restaurant name, including local places. Restaurant selection helps find the right food; menu availability can vary.")
                        .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        Button(valid ? "Use \(name.trimmingCharacters(in: .whitespacesAndNewlines))" : "Choose restaurant") {
                            isTyping = false; context.select(name); dismiss()
                        }.buttonStyle(.brandPrimary).disabled(!valid).accessibilityIdentifier("restaurantUse")
                        Button("No restaurant") { isTyping = false; context.clear(); dismiss() }.frame(minHeight: 44)
                    }.padding(16).background(Theme.Colors.ground)
                }
                .daylightSubpage("Restaurant").tint(Theme.Colors.primary)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer(); Button("Done") { isTyping = false }.accessibilityIdentifier("restaurantKeyboardDone")
                    }
                }
                .onAppear { name = context.restaurant?.name ?? "" }
        }
    }
}

struct RestaurantClarificationView: View {
    var clarification: RestaurantClarification
    var onChoose: (RestaurantClarification.Choice) -> Void
    var onStartOver: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(clarification.message).font(Theme.Fonts.display(26, .bold)).accessibilityAddTraits(.isHeader)
            Text(clarification.detail).font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textSecondary)
            ForEach(clarification.choices) { choice in
                Button(choice.label) { onChoose(choice) }.buttonStyle(.brandPrimary)
                    .accessibilityIdentifier("restaurantChoice-\(choice.id)")
            }
            Button("Edit description", action: onStartOver).font(Theme.Fonts.body(16, .semibold)).frame(minHeight: 44)
            Text("We’ll confirm the food before you log it.").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
        }.tile(padding: 20)
    }
}

struct RestaurantIngredientChecklist: View {
    @Bindable var vm: TalkToLogViewModel
    var onReview: () -> Void
    var onBack: () -> Void
    var onFocusChanged: (Bool) -> Void = { _ in }
    @State private var extra = ""
    @State private var extraDishID: String?
    @FocusState private var isTyping: Bool
    private var selectedCount: Int { vm.dishes.reduce(0) { $0 + $1.ingredients.filter { $0.state == "included" }.count } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DaylightPageTitle("Finish your meal", subtitle: "We filled in what you said. Add anything else you had.")
                Text(vm.inputText).font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
                ForEach($vm.dishes) { $dish in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(dish.name).font(Theme.Fonts.display(22, .bold))
                        ForEach($dish.ingredients) { $ingredient in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top) {
                                    Button {
                                        ingredient.state = ingredient.state == "included" ? "excluded" : "included"
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: ingredient.state == "included" ? "checkmark.square.fill" : (ingredient.state == "excluded" ? "minus.square" : "plus.square"))
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(ingredient.name).font(Theme.Fonts.body(16, .semibold))
                                                Text(ingredient.state == "excluded" ? "Excluded" : ingredient.state == "included" ? (ingredient.fromDescription ? "From your description" : "Added by you") : "Optional · not added")
                                                    .font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
                                            }
                                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                                    }.buttonStyle(.plain).accessibilityIdentifier("ingredient-\(ingredient.name)")
                                }
                                if ingredient.state == "included" {
                                    Stepper("\(ingredient.quantity.formatted()) servings", value: $ingredient.quantity, in: 0.25...10, step: 0.25)
                                        .font(Theme.Fonts.body(14)).accessibilityLabel("Servings of \(ingredient.name)")
                                    if ingredient.uncertain { Text("Type or portion unclear · review as an estimate, or choose a specific option below.").font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary) }
                                }
                            }
                            Divider()
                        }
                        Button { extraDishID = dish.id; isTyping = true } label: { Label("Something else", systemImage: "plus").frame(minHeight: 44) }
                            .accessibilityIdentifier("ingredientSomethingElse")

                    }.tile(padding: 16)
                }
                Text("Nothing else is added unless you choose it. Portions are confirmed next; no food is logged yet.")
                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                Button("Edit description", action: onBack).frame(minHeight: 44)
            }.padding(.vertical, 8)
        }.scrollDismissesKeyboard(.interactively)
            .onChange(of: isTyping) { _, focused in onFocusChanged(focused) }
            .onDisappear { onFocusChanged(false) }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if extraDishID != nil {
                        HStack(spacing: 8) {
                            TextField("Another ingredient", text: $extra).focused($isTyping).submitLabel(.done)
                                .onSubmit { addExtra() }.padding(12)
                                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityIdentifier("ingredientCustomName")
                            Button("Add") { addExtra() }.frame(minWidth: 44, minHeight: 44)
                                .disabled(extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || extra.count > 120)
                                .accessibilityLabel("Add ingredient").accessibilityIdentifier("ingredientCustomAdd")
                        }
                    }
                    Button("Review food & portions") { if extraDishID != nil && !extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { addExtra() }; isTyping = false; onReview() }
                        .buttonStyle(.brandPrimary).disabled(selectedCount == 0 || selectedCount > 16 || vm.isParsing)
                        .accessibilityIdentifier("ingredientReview")
                }.padding(.vertical, 8).background(Theme.Colors.ground)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Done") { isTyping = false }.accessibilityIdentifier("ingredientKeyboardDone")
                }
            }
    }
    private func addExtra() {
        let name = extra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 120, let id = extraDishID,
              let index = vm.dishes.firstIndex(where: { $0.id == id }), vm.dishes[index].ingredients.count < 40 else { return }
        vm.dishes[index].ingredients.append(.init(id: UUID().uuidString, name: name, state: "included", quantity: 1, fromDescription: false, uncertain: false))
        extra = ""; extraDishID = nil; isTyping = false
    }
}
