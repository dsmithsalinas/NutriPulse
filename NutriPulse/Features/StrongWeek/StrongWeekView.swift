import SwiftUI

struct StrongWeekCard: View {
    let vm: StrongWeekViewModel
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sun.horizon.fill").foregroundStyle(Theme.Colors.primary)
                    Text("Your strong week").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                if vm.isLoading && vm.current == nil {
                    ProgressView().controlSize(.small)
                } else if vm.loadFailed {
                    Text("Couldn't load your week. Tap to try again.").font(.subheadline).foregroundStyle(.secondary)
                } else if let outlook = vm.current?.outlook {
                    Text(outlook.observation).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                    Text(vm.needsRefresh ? "Update with your latest data" : "Food, movement & recovery")
                        .font(.caption.weight(.medium)).foregroundStyle(Theme.Colors.primary)
                } else {
                    Text(vm.previousNeedsConfirmation
                        ? "Does what you shared last time still apply?"
                        : "Anything coming up that should shape your week?")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(vm.current == nil ? "Build your outlook" : "Finish your outlook")
                        .font(.caption.weight(.medium)).foregroundStyle(Theme.Colors.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md).card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Week of \(StrongWeekWindow.start().formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Food, movement, and room for real life.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if vm.loadFailed {
                        Text(vm.error ?? "Couldn't load your week.").foregroundStyle(.secondary)
                        Button("Try again") { Task { await vm.load() } }
                    } else if vm.isLoading {
                        ProgressView("Loading your week…")
                    } else if vm.editing || vm.current == nil {
                        checkIn
                    } else if let outlook = vm.current?.outlook {
                        outlookSection("This week", text: outlook.observation, symbol: "sun.horizon")
                        outlookSection("Food focus", text: outlook.foodFocus, symbol: "fork.knife")
                        outlookSection("Movement & recovery", text: outlook.movementFocus, symbol: "figure.walk")
                        if let week = vm.current {
                            if !week.note.isEmpty || !week.circumstances.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("What you shared").font(.subheadline.weight(.semibold))
                                    Text(week.circumstances.map(\.title).joined(separator: " · ")).font(.footnote)
                                    if !week.note.isEmpty { Text(week.note).font(.footnote) }
                                    if !week.activityRestrictions.isEmpty { Text(week.activityRestrictions).font(.footnote) }
                                }.foregroundStyle(.secondary)
                            }
                            if let generated = week.generatedAt {
                                Text("Updated \(generated.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let savedAdjustments = vm.current?.adjustments, !savedAdjustments.isEmpty {
                            Text("Adjusted for you: " + savedAdjustments.map(\.title).joined(separator: " · "))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if let week = vm.current, let generatedAt = week.generatedAt {
                            StrongWeekFeedbackView(week: week, readOnly: isPreview)
                                .id("\(week.id)-\(generatedAt.timeIntervalSince1970)")
                        }
                        Button("Adjust this for me") {
                            adjustments = Set(vm.current?.adjustments ?? [])
                            showAdjustments = true
                        }.buttonStyle(.borderedProminent)
                        Button("Update my week") { vm.beginEditing() }.buttonStyle(.borderedProminent)
                        Button("Refresh with latest data") { Task { await vm.generate(profile: profile, updateContext: false) } }
                        Text("Your outlook stays here until you refresh it. New logs and check-ins help Pulse adjust it.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Your context is saved. Let's finish your outlook.").font(.headline)
                        Button("Generate outlook") { Task { await vm.generate(profile: profile, updateContext: false) } }
                            .buttonStyle(.borderedProminent)
                        Button("Edit what I shared") { vm.beginEditing() }
                    }
                    Button { showFoodPreferences = true } label: {
                        Label("Food preferences", systemImage: "fork.knife")
                    }
                    Text("Make food suggestions fit your kitchen, budget, and routine.")
                        .font(.caption).foregroundStyle(.secondary)
                    if vm.isGenerating { ProgressView("Pulse is putting your week together…") }
                    if let error = vm.error, !vm.loadFailed {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(Theme.Spacing.md)
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

    private var adjustmentSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("What would make this week's suggestions fit better?")
                    ForEach(WeekAdjustment.allCases) { choice in
                        Toggle(choice.title, isOn: Binding(
                            get: { adjustments.contains(choice) },
                            set: { selected in
                                if selected { adjustments.insert(choice) }
                                else { adjustments.remove(choice) }
                            }))
                    }
                } footer: {
                    Text("These choices apply this week. Pulse keeps the circumstances and activity limits you've already shared.")
                }
                Section {
                    Button("Something about my week changed") {
                        showAdjustments = false
                        vm.beginEditing()
                    }
                } footer: {
                    Text("Update travel plans, injuries, or other circumstances in your weekly check-in.")
                }
                Section {
                    Button("Apply & refresh outlook") {
                        let selected = adjustments
                        showAdjustments = false
                        Task { await vm.adjust(selected, profile: profile) }
                    }.buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Adjust this for me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showAdjustments = false } } }
        }
        .tint(Theme.Colors.primary)
    }

    private var checkIn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Anything coming up that should shape your week?").font(.title3.weight(.semibold))
            Text("Travel, a busy schedule, how you're feeling—anything you'd like Pulse to account for. Sharing is optional.")
                .font(.subheadline).foregroundStyle(.secondary)
            if vm.previousNeedsConfirmation, let previous = vm.previous {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Previously marked as ongoing").font(.subheadline.weight(.semibold))
                    Text(([previous.circumstances.map(\.title).joined(separator: " · "), previous.note, previous.activityRestrictions])
                        .filter { !$0.isEmpty }.joined(separator: "\n")).font(.footnote)
                    if vm.didConfirmPrevious { Text("Updated for this week").font(.caption).foregroundStyle(Theme.Colors.primary) }
                    HStack {
                        Button("Still applies") { vm.confirmPrevious() }
                        Button("No longer applies") { vm.clearPrevious() }
                    }.buttonStyle(.bordered)
                }.padding().background(Theme.Colors.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }
            ForEach(WeekCircumstance.allCases) { choice in
                Button { vm.draft.toggle(choice); if choice == .usual { vm.didConfirmPrevious = true } } label: {
                    HStack {
                        Text(choice.title)
                        Spacer()
                        Image(systemName: vm.draft.circumstances.contains(choice) ? "checkmark.circle.fill" : "circle")
                    }
                    .padding(12)
                    .background(vm.draft.circumstances.contains(choice) ? Theme.Colors.primary.opacity(0.10) : Theme.Colors.surfaceCard,
                                in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            TextField("Anything else? For example, traveling Tuesday–Friday", text: $vm.draft.note, axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.roundedBorder)
                .onChange(of: vm.draft.note) { _, value in vm.draft.note = String(value.prefix(1000)) }
            if vm.draft.circumstances.contains(.injury) || !vm.draft.activityRestrictions.isEmpty {
                Text("Any activity limits your clinician has given you?").font(.subheadline.weight(.semibold))
                TextField("Optional—leave blank if you're unsure", text: $vm.draft.activityRestrictions, axis: .vertical)
                    .lineLimit(2...4).textFieldStyle(.roundedBorder)
                    .onChange(of: vm.draft.activityRestrictions) { _, value in vm.draft.activityRestrictions = String(value.prefix(500)) }
                Text("Pulse can work around limits you share; it won't prescribe injury treatment or clear you to exercise.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !vm.draft.circumstances.isEmpty && vm.draft.circumstances != [.usual] || !vm.draft.note.isEmpty {
                Toggle("Check whether this still applies next week", isOn: $vm.draft.ongoing).font(.subheadline)
            }
            Text("For a tailored week, this outlook replaces generic coaching nudges. Your shot reminders keep their own settings.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Build my outlook") { Task { await vm.generate(profile: profile, updateContext: true) } }
                .buttonStyle(.borderedProminent)
            .disabled(vm.previousNeedsConfirmation && !vm.didConfirmPrevious)
            if vm.current == nil && !vm.previousNeedsConfirmation {
                Button("Use my data without a check-in") {
                    vm.draft = .init()
                    Task { await vm.generate(profile: profile, updateContext: true) }
                }
            }
        }
    }

    private func outlookSection(_ title: String, text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(Theme.Colors.primary)
            Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(Theme.Spacing.md).card()
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
