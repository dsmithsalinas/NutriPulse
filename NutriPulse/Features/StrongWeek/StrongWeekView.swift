import SwiftUI

struct StrongWeekCard: View {
    let vm: StrongWeekViewModel
    let open: () -> Void

    private var pulseActive: Bool { PulseProfileStore.shared.pulseActive }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TileEyebrow("Your strong week", color: Theme.Colors.violetLabel)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.violetLabel)
                }
                Spacer(minLength: 0)
                if vm.isLoading && vm.current == nil {
                    ProgressView().controlSize(.small)
                } else if vm.loadFailed {
                    Text("Couldn't load your week. Tap to try again.")
                        .font(Theme.Fonts.body(14))
                        .foregroundStyle(Theme.Colors.violetInk.opacity(0.75))
                } else if let outlook = vm.current?.outlook {
                    Text(outlook.observation)
                        .font(Theme.Fonts.display(18, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Theme.Colors.violetInk)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(vm.needsRefresh ? "Update with your latest data" : "Food, movement & recovery")
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.violetLabel)
                } else if vm.current != nil, !pulseActive {
                    // Context is saved (the weekly plan input keeps working); there's just
                    // nothing to write the outlook with while Pulse is off.
                    Text("Your context is saved.")
                        .font(Theme.Fonts.display(18, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Theme.Colors.violetInk)
                    Text("Turn on Pulse in Profile for a written outlook.")
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.violetLabel)
                } else {
                    Text(vm.previousNeedsConfirmation
                        ? "Does what you shared last time still apply?"
                        : "Anything coming up that should shape your week?")
                        .font(Theme.Fonts.display(18, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Theme.Colors.violetInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(vm.current == nil ? "Build your outlook" : "Finish your outlook")
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.violetLabel)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .tile(Theme.Colors.violet, shadow: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }
}

struct StrongWeekView: View {
    @Bindable var vm: StrongWeekViewModel
    let profile: UserProfile?
    var isPreview = false
    @Environment(\.dismiss) private var dismiss
    @State private var showAdjustments = false
    @State private var showFoodPreferences = false
    @State private var adjustments: Set<WeekAdjustment> = []
    private var pulseActive: Bool { PulseProfileStore.shared.pulseActive }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Week of \(StrongWeekWindow.start().formatted(date: .abbreviated, time: .omitted))")
                            .font(Theme.Fonts.body(12, .semibold))
                            .foregroundStyle(Theme.Colors.textFaint)
                        Text("Food, movement, and room for real life.")
                            .font(Theme.Fonts.body(14))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if vm.loadFailed {
                        loadFailedTile
                    } else if vm.isLoading {
                        ProgressView("Loading your week…")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else if vm.editing || vm.current == nil {
                        checkIn
                    } else if let outlook = vm.current?.outlook {
                        outlookTile("This week", text: outlook.observation, symbol: "sun.horizon.fill",
                                    fill: Theme.Colors.violet, iconFill: Theme.Colors.violetInk,
                                    label: Theme.Colors.violetLabel, ink: Theme.Colors.violetInk)
                        outlookTile("Food focus", text: outlook.foodFocus, symbol: "fork.knife",
                                    fill: Theme.Colors.lime, iconFill: Theme.Colors.limeInk,
                                    label: Theme.Colors.limeLabel, ink: Theme.Colors.limeInk)
                        outlookTile("Movement & recovery", text: outlook.movementFocus, symbol: "figure.walk",
                                    fill: Theme.Colors.surfaceCard, iconFill: Theme.Colors.primary,
                                    label: Theme.Colors.textSecondary, ink: Theme.Colors.textPrimary)
                        if let week = vm.current {
                            if !week.note.isEmpty || !week.circumstances.isEmpty {
                                sharedTile(week)
                            }
                            if let generated = week.generatedAt {
                                Text("Updated \(generated.formatted(date: .abbreviated, time: .shortened))")
                                    .font(Theme.Fonts.body(12))
                                    .foregroundStyle(Theme.Colors.textFaint)
                            }
                        }
                        if let savedAdjustments = vm.current?.adjustments, !savedAdjustments.isEmpty {
                            Text("Adjusted for you: " + savedAdjustments.map(\.title).joined(separator: " · "))
                                .font(Theme.Fonts.body(12))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        if let week = vm.current, let generatedAt = week.generatedAt {
                            StrongWeekFeedbackView(week: week, readOnly: isPreview)
                                .id("\(week.id)-\(generatedAt.timeIntervalSince1970)")
                                .tile()
                        }
                        if pulseActive {
                            linkButton("Adjust this for me") {
                                adjustments = Set(vm.current?.adjustments ?? [])
                                showAdjustments = true
                            }
                        }
                        Button("Update my week") { vm.beginEditing() }
                            .buttonStyle(.brandPrimary)
                        if pulseActive {
                            linkButton("Refresh with latest data") {
                                Task { await vm.generate(profile: profile, updateContext: false) }
                            }
                            Text("Your outlook stays here until you refresh it. New logs and check-ins help Pulse adjust it.")
                                .font(Theme.Fonts.body(12))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        } else {
                            Text("Turn on Pulse in Profile to refresh this outlook.")
                                .font(Theme.Fonts.body(12))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    } else if pulseActive {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your context is saved. Let's finish your outlook.")
                                .font(Theme.Fonts.display(19, .bold, relativeTo: .headline))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Button("Generate outlook") { Task { await vm.generate(profile: profile, updateContext: false) } }
                                .buttonStyle(.brandPrimary)
                            linkButton("Edit what I shared") { vm.beginEditing() }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your context is saved.")
                                .font(Theme.Fonts.display(19, .bold, relativeTo: .headline))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("Turn on Pulse in Profile for a written outlook.")
                                .font(Theme.Fonts.body(14))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            linkButton("Edit what I shared") { vm.beginEditing() }
                        }
                    }
                    foodPreferencesRow
                    if vm.isGenerating {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Pulse is putting your week together…")
                                .font(Theme.Fonts.body(14, .semibold))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    if let error = vm.error, !vm.loadFailed {
                        Text(error)
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Colors.danger)
                    }
                }
                .padding(Theme.Spacing.page)
                .disabled(vm.isGenerating)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationTitle("Your strong week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(Theme.Colors.primary)
        .interactiveDismissDisabled(vm.isGenerating)
        .onReceive(NotificationCenter.default.publisher(for: .foodAccessChanged)) { _ in
            vm.foodPreferencesChanged()
        }
        .sheet(isPresented: $showFoodPreferences) { FoodAccessPreferencesView() }
        .sheet(isPresented: $showAdjustments) { adjustmentSheet }
    }

    // MARK: - Load failure

    private var loadFailedTile: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.error ?? "Couldn't load your week.")
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.textSecondary)
            Button("Try again") { Task { await vm.load() } }
                .buttonStyle(.brandPrimary)
        }
        .tile()
    }

    // MARK: - Adjust sheet

    private var adjustmentSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("What would make this week's suggestions fit better?")
                        .font(Theme.Fonts.body(14))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    ForEach(WeekAdjustment.allCases) { choice in
                        Toggle(isOn: Binding(
                            get: { adjustments.contains(choice) },
                            set: { selected in
                                if selected { adjustments.insert(choice) }
                                else { adjustments.remove(choice) }
                            })) {
                            Text(choice.title).font(Theme.Fonts.body(15))
                        }
                    }
                } header: {
                    DaylightSectionHeader("This week only")
                } footer: {
                    DaylightSectionFooter("These choices apply this week. Pulse keeps the circumstances and activity limits you've already shared.")
                }
                .daylightSection()

                Section {
                    Button {
                        showAdjustments = false
                        vm.beginEditing()
                    } label: {
                        Text("Something about my week changed")
                            .font(Theme.Fonts.body(15, .semibold))
                            .foregroundStyle(Theme.Colors.primaryText)
                    }
                } footer: {
                    DaylightSectionFooter("Update travel plans, injuries, or other circumstances in your weekly check-in.")
                }
                .daylightSection()
            }
            .daylightForm()
            .safeAreaInset(edge: .bottom) {
                Button("Apply & refresh outlook") {
                    let selected = adjustments
                    showAdjustments = false
                    Task { await vm.adjust(selected, profile: profile) }
                }
                .buttonStyle(.brandPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle("Adjust this for me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showAdjustments = false } } }
        }
        .tint(Theme.Colors.primary)
    }

    // MARK: - Check-in

    private var checkIn: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Anything coming up that should shape your week?")
                    .font(Theme.Fonts.display(20, .bold, relativeTo: .title3))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Travel, a busy schedule, how you're feeling—anything you'd like Pulse to account for. Sharing is optional.")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            if vm.previousNeedsConfirmation, let previous = vm.previous {
                previousCircumstanceTile(previous)
            }
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(WeekCircumstance.allCases) { choice in
                    CircumstanceChip(title: choice.title, isSelected: vm.draft.circumstances.contains(choice)) {
                        vm.draft.toggle(choice)
                        if choice == .usual { vm.didConfirmPrevious = true }
                    }
                }
            }
            TextField("Anything else? For example, traveling Tuesday–Friday", text: $vm.draft.note, axis: .vertical)
                .font(Theme.Fonts.body(14))
                .lineLimit(3...6)
                .padding(12)
                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: vm.draft.note) { _, value in vm.draft.note = String(value.prefix(1000)) }
            if vm.draft.circumstances.contains(.injury) || !vm.draft.activityRestrictions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Any activity limits your clinician has given you?")
                        .font(Theme.Fonts.body(15, .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    TextField("Optional—leave blank if you're unsure", text: $vm.draft.activityRestrictions, axis: .vertical)
                        .font(Theme.Fonts.body(14))
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onChange(of: vm.draft.activityRestrictions) { _, value in vm.draft.activityRestrictions = String(value.prefix(500)) }
                    Text("Pulse can work around limits you share; it won't prescribe injury treatment or clear you to exercise.")
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            if !vm.draft.circumstances.isEmpty && vm.draft.circumstances != [.usual] || !vm.draft.note.isEmpty {
                Toggle(isOn: $vm.draft.ongoing) {
                    Text("Check whether this still applies next week")
                        .font(Theme.Fonts.body(14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            Text("For a tailored week, this outlook replaces generic coaching nudges. Your shot reminders keep their own settings.")
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Colors.textSecondary)
            if !pulseActive {
                Text("Turn on Pulse in Profile for a written outlook from this. Your answers are still saved either way.")
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Button(pulseActive ? "Build my outlook" : "Save this week's plan") {
                Task { await vm.generate(profile: profile, updateContext: true) }
            }
            .buttonStyle(.brandPrimary)
            .disabled(vm.previousNeedsConfirmation && !vm.didConfirmPrevious)
            if vm.current == nil && !vm.previousNeedsConfirmation {
                linkButton(pulseActive ? "Use my data without a check-in" : "Save without a check-in") {
                    vm.draft = .init()
                    Task { await vm.generate(profile: profile, updateContext: true) }
                }
            }
        }
        .tile()
    }

    private func previousCircumstanceTile(_ previous: StrongWeek) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TileEyebrow("Previously marked as ongoing", color: Theme.Colors.primaryText)
            Text(([previous.circumstances.map(\.title).joined(separator: " · "), previous.note, previous.activityRestrictions])
                .filter { !$0.isEmpty }.joined(separator: "\n"))
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Colors.textSecondary)
            if vm.didConfirmPrevious {
                Text("Updated for this week")
                    .font(Theme.Fonts.body(12, .semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            HStack(spacing: 10) {
                Button { vm.confirmPrevious() } label: {
                    Text("Still applies")
                        .font(Theme.Fonts.body(14, .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.pressable)
                Button { vm.clearPrevious() } label: {
                    Text("No longer applies")
                        .font(Theme.Fonts.body(14, .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(12)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Outlook tiles

    private func outlookTile(_ title: String, text: String, symbol: String, fill: Color, iconFill: Color, label: Color, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(iconFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                TileEyebrow(title, color: label)
            }
            Text(text)
                .font(Theme.Fonts.body(15))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tile(fill, shadow: fill == Theme.Colors.surfaceCard)
    }

    private func sharedTile(_ week: StrongWeek) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TileEyebrow("What you shared", color: Theme.Colors.textFaint)
            Text(week.circumstances.map(\.title).joined(separator: " · "))
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Colors.textSecondary)
            if !week.note.isEmpty {
                Text(week.note)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            if !week.activityRestrictions.isEmpty {
                Text(week.activityRestrictions)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .tile()
    }

    private var foodPreferencesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { showFoodPreferences = true } label: {
                Label("Food preferences", systemImage: "fork.knife")
                    .font(Theme.Fonts.body(15, .bold))
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44, alignment: .leading)
            Text("Make food suggestions fit your kitchen, budget, and routine.")
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.body(15, .bold))
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

/// A tappable chip for a weekly circumstance — selected state is a filled/tinted look plus the
/// VoiceOver `.isSelected` trait, matching AboutYouView's allergy/eating-pattern chips.
private struct CircumstanceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(Theme.Fonts.body(14, .semibold))
            }
            .foregroundStyle(isSelected ? Theme.Colors.primaryText : Theme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(isSelected ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.surfaceInset,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Colors.primary.opacity(0.55) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel(title)
    }
}

#if DEBUG
// Read-only visual fixture: no sign-in, model call, or database writes.
struct StrongWeekPreview: View {
    @State private var vm = StrongWeekViewModel()
    var body: some View {
        StrongWeekView(vm: vm, profile: nil, isPreview: true)
            .task {
                vm.isLoading = false
                if ProcessInfo.processInfo.arguments.contains("--outlook") {
                    vm.current = .init(id: UUID(), userId: UUID(), weekStart: StrongWeekWindow.key(),
                        circumstances: [.travel], note: "Traveling Tuesday–Friday, with no kitchen.", activityRestrictions: "", ongoing: false,
                        contextRevision: UUID(), outlook: .init(
                            observation: "With travel Tuesday through Friday, make meals predictable wherever you are. Your logged protein has been consistent, while sleep has been shorter than your usual pattern.",
                            foodFocus: "Keep a familiar protein-rich option within reach. Choose a reliable breakfast and a convenient meal you can find without a kitchen.",
                            movementFocus: "Leave room for easier days while traveling. A walk can fit around your schedule; decide about your next familiar lift based on how you feel, without making up for missed activity."),
                        generatedAt: .now, updatedAt: .now)
                }
            }
    }
}
#endif
