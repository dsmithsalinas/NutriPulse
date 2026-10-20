import SwiftUI
import Supabase

// Daylight Log sheet (docs/daylight-redesign.md): a header showing the meal everything logs to
// ("Adding to Dinner ▾") plus a close button, and Talk / Search / Scan / Favorites tabs beneath
// it. Manual entry moved inside Search ("Can't find it? Enter it yourself"); Favorites replaces
// the old Manual tab.
struct FoodLoggingView: View {
    let selectedDate: Date
    let initialTab: FoodLoggingViewModel.LogTab?

    // SWIFT CONCEPT — @Environment(\.dismiss) gives any view the ability to close itself
    // when it's presented as a sheet or navigation push. It's like calling
    // router.back() or closing a modal in React — no prop drilling needed.
    @Environment(\.dismiss) private var dismiss
    @State private var vm = FoodLoggingViewModel()
    @State private var searchVM = FoodSearchViewModel()
    @State private var talkVM = TalkToLogViewModel()
    @State private var favoritesVM = FavoritesViewModel()
    @State private var showManualEntry = false
    @State private var saved = false
    @State private var undo = FoodSaveUndo()
    @State private var familiar: [FoodLog] = []
    @State private var reviewFood: FoodLog?
    @State private var returning = false
    @State private var showSaveUsual = false
    @State private var showMealNote = ProcessInfo.processInfo.arguments.contains("--meal-note-preview")


    init(selectedDate: Date, initialTab: FoodLoggingViewModel.LogTab? = nil) {
        self.selectedDate = selectedDate
        self.initialTab = initialTab
        _vm = State(initialValue: FoodLoggingViewModel(selectedTab: initialTab ?? LogMethodPreference.read(userId: supabase.auth.currentSession?.user.id)))
        #if DEBUG
        if AppStoreScreenshotMode.active {
            _talkVM = State(initialValue: AppStoreScreenshotPreview.foodModel())
        }
        #endif
    }

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Theme.Colors.hairline)
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            LogSheetHeader(meal: $vm.selectedMeal, onClose: { dismiss() })

            if saved {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle").font(.system(size: 36)).foregroundStyle(Theme.Colors.primaryText)
                    Text(selectedDate.isToday ? "Saved for today" : "Saved for \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(Theme.Fonts.display(26, .bold, relativeTo: .title2))
                    if let note = undo.note, MealNoteStore.shared.isPending(note.id) {
                        Text("Saved on this phone · Waiting to sync").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if returning { Text("No need to fill in previous days.").font(Theme.Fonts.body(16)) }
                    if !undo.savedFoods.isEmpty {
                        Button("Save as a usual meal") { showSaveUsual = true }.frame(minHeight: 44).disabled(undo.isUndoing)
                    }
                    if undo.canUndo {
                        Button(undo.isUndoing ? "Undoing…" : "Undo") {
                            Task { if await undo.undo() { talkVM.reset(); searchVM.resetQuickLogState(); saved = false } }
                        }.frame(minHeight: 44).disabled(undo.isUndoing)
                    }
                    if let error = undo.error { Text(error).foregroundStyle(Theme.Colors.danger) }
                    Button("Done") { dismiss() }.buttonStyle(.brandPrimary).disabled(undo.isUndoing)
                    Button("Add something else") { undo.reset(); talkVM.reset(); searchVM.resetQuickLogState(); saved = false }
                        .disabled(undo.isUndoing)
                        .font(Theme.Fonts.body(16, .semibold)).frame(minHeight: 44)
                }.padding(Theme.Spacing.md).frame(maxHeight: .infinity)
            } else {
            Button { showMealNote = true } label: {
                Label("Just leave a meal note", systemImage: "square.and.pencil")
                    .font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44)
            }
            LogTabBar(selection: $vm.selectedTab)

            Group {
                switch vm.selectedTab {
                case .talk:
                    TalkToLogView(vm: talkVM, date: selectedDate, headerMeal: vm.selectedMeal, onLogged: { source in
                        handleLogged(source, keepOpen: false)
                    }, familiarFoods: familiar, onSelectFamiliar: { reviewFood = $0 })
                case .search:
                    FoodSearchView(
                        vm: searchVM, date: selectedDate, headerMeal: vm.selectedMeal,
                        onLogged: handleLogged,
                        onEnterManually: { showManualEntry = true }
                    )
                case .scan:
                    BarcodeScanView(vm: searchVM, date: selectedDate, headerMeal: vm.selectedMeal, onLogged: { source in
                        handleLogged(source, keepOpen: false)
                    })
                case .favorites:
                    FavoritesView(vm: favoritesVM, date: selectedDate, headerMeal: vm.selectedMeal, onLogged: handleLogged)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.foodSaveUndo, undo)
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.ground.ignoresSafeArea())
        .tint(Theme.Colors.primary)
        .sheet(isPresented: $showSaveUsual) { SaveUsualMealSheet(foods: undo.savedFoods) }
        .sheet(isPresented: $showMealNote) {
            MealNoteSheet(date: selectedDate, meal: vm.selectedMeal) { saved = true }.environment(\.foodSaveUndo, undo)
        }
        .sheet(item: $reviewFood) { food in
            FamiliarFoodReview(food: food, date: selectedDate, meal: vm.selectedMeal) {
                handleLogged(.favorite, keepOpen: false)
            }.environment(\.foodSaveUndo, undo)
        }
        .task {
            #if DEBUG
            if DebugLaunch.tour {
                familiar = Array(AppStoreScreenshotPreview.todayModel().foodLogs.prefix(3))
                returning = true
                if ProcessInfo.processInfo.arguments.contains("--saved-note-preview") {
                    let note = MealNote(userId: familiar.first?.userId ?? UUID(), logDate: Date.now.isoDateString, meal: .lunch, body: "Lunch out with friends")
                    MealNoteStore.shared.preview(note); undo.record(note: note); saved = true
                }
                return
            }
            #endif
            guard let id = try? await supabase.auth.session.user.id else { return }
            let history: [FoodLog]
            do { history = try await FoodLogRepository().familiarHistory() }
            catch { history = (try? LocalStore.shared.fetchFoodLogs(since: .distantPast, userId: id)) ?? [] }
            guard (try? await supabase.auth.session.user.id) == id else { return }
            familiar = FamiliarFoods.suggestions(history)
            if selectedDate.isToday, let latest = history.map(\.logDate).max(), let day = Date.fromISODateString(latest) {
                returning = (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: day), to: Calendar.current.startOfDay(for: .now)).day ?? 0) >= 4
            }
        }
        .sheet(isPresented: $showManualEntry) {
            NavigationStack {
                ManualEntryView(vm: vm, date: selectedDate, onLogged: { source in
                    showManualEntry = false
                    handleLogged(source, keepOpen: false)
                })
                .navigationTitle("Enter it yourself")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showManualEntry = false }
                    }
                }
                .background(Theme.Colors.ground.ignoresSafeArea())
            }
            .tint(Theme.Colors.primary)
            .environment(\.foodSaveUndo, undo)
        }
        // .constant() evaluates once and freezes — Binding(get:set:) re-evaluates
        // whenever @Observable tracks a change to vm.errorMessage.
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onChange(of: vm.selectedTab) { _, method in
            LogMethodPreference.save(method, userId: supabase.auth.currentSession?.user.id)
        }
        .onAppear {
            if !AppStoreScreenshotMode.active {
                Telemetry.logIntentStarted(source: vm.selectedTab.telemetrySource)
            }
        }
    }

    // Every successful save has an explicit stopping point. Adding more is optional.
    private func handleLogged(_ source: LogSource, keepOpen: Bool) {
        if source == .talk {
            Telemetry.logConfirmed(
                source: source,
                rowsTotal: talkVM.rows.count,
                rowsEdited: talkVM.rows.filter(\.wasEdited).count
            )
        } else {
            Telemetry.logConfirmed(source: source)
        }
        saved = true
    }
}
