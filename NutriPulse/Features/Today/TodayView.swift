import SwiftUI
import UIKit

struct TodayView: View {
    // The ViewModel is owned by MainTabView and passed in, so the tab bar's Log action and
    // this screen share one selected date — logging always lands on the day you're viewing.
    let vm: TodayViewModel
    // False while the logging sheet is up or another tab is showing. The protein win is
    // latched until this goes true, so the celebration always plays to a watching user.
    var isFrontmost: Bool = true
    @State private var strongWeek = StrongWeekViewModel()
    @State private var showStrongWeek = false
    @State private var showBodyCompSheet = false
    @State private var showBodyHub = false
    @State private var showDatePicker = false
    @State private var showRitual = false
    @State private var showProteinRescue = false
    @State private var showRecoveryLogger = false
    @State private var showShotCycleCheckIn = false
    @State private var repeatedMealRoute: SmartNotificationRoute? = nil
    @State private var ringCelebrationTrigger = 0
    @State private var proteinCelebrationTrigger = 0
    @State private var proteinCelebrationPending = false
    // Between the latch clearing and the moment playing (the short delay below).
    @State private var proteinCelebrationInFlight = false
    @State private var editingLog: FoodLog? = nil
    @State private var showWaterPicker = false
    @State private var showMovement = false
    @State private var showRecentMeals = false
    @State private var showLighterTracking = false
    @State private var showSaveUsualMeal = false
    @State private var usualMealFoods: [FoodLog] = []
    @State private var editingMealNote: MealNote?
    @State private var deletingMealNote: MealNote?
    @State private var mealNoteError: String?
    @State private var rememberingNote: MealNote?
    @State private var showOffScript = false
    @State private var showEverydayTools = false
    @State private var offScriptOwner: UUID?
    @State private var offScriptPrompt: String?

    @State private var lighterTrackingError: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    @AppStorage(LowAppetitePreparationStore.completedKey) private var completedPreparation = ""
    @AppStorage(ShotCycleCheckInSchedule.dismissedDayKey) private var dismissedShotCheckInDay = ""
    // Which day the user dismissed the dose-day card (ISO date). Hides it for that day only;
    // it returns on the next dose day (or as an overdue prompt the following day).
    @AppStorage("doseCardDismissedDay") private var doseCardDismissedDay = ""
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    // The water tile's one-tap amount, in ml. 0 until the user picks a size (see WaterUnit.usualMl).
    @AppStorage(WaterUnit.usualMlKey) private var storedUsualWaterMl: Double = 0
    private var waterUnit: WaterUnit { WaterUnit(units: units) }
    private var usualWaterMl: Double { WaterUnit.usualMl(stored: storedUsualWaterMl, units: units) }
    // Gates Today's Pulse-branded priority cards (see PulseGate). Read directly off the
    // device-cached singleton, like SyncEngine.shared.statusMessage above — Observation tracks
    // the read regardless of how the reference was obtained.
    private var pulseOnToday: Bool { PulseGate.showsPulseStripOnToday(pulseOnToday: PulseProfileStore.shared.pulseOnToday) }
    private var pulseActive: Bool {
        PulseGate.isActive(pulseEnabled: PulseProfileStore.shared.pulseEnabled, aiConsentAt: PulseProfileStore.shared.aiConsentAt)
    }

    // The signed-in account, for keying the floor-cleared celebration's "already played today"
    // record. Nil (signed out) just means the celebration never persists — it can still play
    // in memory for the rest of this session.
    private var isLighterToday: Bool { vm.isToday && TrackingPreferencesStore.shared.isActive }

    private var currentAccountId: String? { appState.session?.user.id.uuidString }

    // Pieces of the body pulled out so the compiler can type-check it in reasonable time.

    private var header: some View {
        TodayHeaderView(
            date: vm.selectedDate,
            isToday: vm.isToday,
            onPrevious: vm.goToPreviousDay,
            onNext: vm.goToNextDay,
            onToday: vm.goToToday,
            onPickDate: { showDatePicker = true }
        )
        .padding(.top, Theme.Spacing.sm)
        .popIn(order: 0)
        .popoverTip(DaySwipeTip(), arrowEdge: .top)
    }

    @ViewBuilder private var firstDayCard: some View {
        if let checklist = firstDayChecklist {
            FirstDayChecklistCard(
                checklist: checklist,
                onStep: openFirstDayStep,
                onDismiss: dismissFirstDay
            )
            .popIn(order: 1)
            .transition(.opacity)
        }
    }

    @ViewBuilder private var mealNoteSections: some View {
        if vm.mealNotesLoadFailed {
            Button("Couldn’t load meal notes. Tap to retry.") { Task { await vm.loadMealNotes() } }
                .font(Theme.Fonts.body(14)).frame(minHeight: 44)
        }
        if let mealNoteError { Text(mealNoteError).foregroundStyle(Theme.Colors.danger) }
        ForEach(vm.mealNotes) { note in
            VStack(alignment: .leading, spacing: 10) {
                Label(note.displayTitle, systemImage: "square.and.pencil")
                    .font(Theme.Fonts.body(14, .bold))
                Text(note.body).font(Theme.Fonts.body(16))
                if MealNoteStore.shared.isPending(note.id) {
                    Button { Task { await SyncEngine.shared.pushPendingChanges() } } label: {
                        Text(MealNoteStore.shared.lastSyncFailed ? "Saved on this phone · Retry sync" : "Saved on this phone · Waiting to sync")
                            .font(Theme.Fonts.body(13)).frame(minHeight: 44)
                    }.foregroundStyle(Theme.Colors.textSecondary)
                }
                Text("Nutrition unknown · not included in totals")
                    .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                HStack {
                    Button("Edit") { editingMealNote = note }.frame(minHeight: 44)
                    Spacer()
                    Button("Delete", role: .destructive) { deletingMealNote = note }.frame(minHeight: 44)
                }.font(Theme.Fonts.body(14, .semibold))
                Button("Remember what helped") { rememberingNote = note }
                    .font(Theme.Fonts.body(14, .semibold)).frame(minHeight: 44)
            }.tile(padding: Theme.Spacing.md)
        }
    }

    private var mealSections: some View {
        ForEach(Meal.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { meal in
            let logs = vm.logsByMeal[meal] ?? []
            if !logs.isEmpty {
                MealSectionView(
                    meal: meal,
                    logs: logs,
                    onEdit: { editingLog = $0 },
                    onDelete: { log in Task { await vm.deleteLog(id: log.id) } }
                )
                .popIn(order: 7)
                // Only on the first meal shown, so the tip points at one row.
                .popoverTip(MealRowTip(), arrowEdge: .bottom, when: meal == firstLoggedMeal)
                Button("Save \(meal.displayName.lowercased()) as a usual meal") {
                    usualMealFoods = logs; showSaveUsualMeal = true
                }.font(Theme.Fonts.body(14, .semibold)).frame(minHeight: 44)
            }
        }
    }

    /// The first meal section Today shows, where the meal-row tip points.
    private var firstLoggedMeal: Meal? {
        Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }.first { !(vm.logsByMeal[$0] ?? []).isEmpty }
    }

    // MARK: First day

    /// Ticks first-day steps off as they happen, re-reads on coming back to Today (the Pulse
    /// step is recorded on the Pulse tab), and lets the tips know food has been logged.
    private var firstDayObserver: some View {
        Color.clear
            .accessibilityHidden(true)
            .task {
                recordFirstDayProgress()
                if !vm.foodLogs.isEmpty { FootingTips.hasLoggedFood = true }
            }
            .onChange(of: vm.foodLogs.count) {
                recordFirstDayProgress()
                if !vm.foodLogs.isEmpty { FootingTips.hasLoggedFood = true }
            }
            .onChange(of: vm.waterIntakeMl) { recordFirstDayProgress() }
            .onChange(of: vm.latestGLP1?.id) { recordFirstDayProgress() }
            .onChange(of: isFrontmost) { _, frontmost in
                guard frontmost else { return }
                recordFirstDayProgress()
                firstDayRevision += 1
            }
    }

    // Bumped when a step is recorded or the card dismissed, so the card re-reads the store.
    @State private var firstDayRevision = 0

    /// The first-day checklist, or nil when it shouldn't show (not today, an older account,
    /// dismissed, or finished on an earlier day). See FirstDayChecklist.
    private var firstDayChecklist: FirstDayChecklist? {
        _ = firstDayRevision
        guard vm.isToday else { return nil }
        #if DEBUG
        // Its own flag (not part of --tour, which has no account): the card with the shot done.
        if ProcessInfo.processInfo.arguments.contains("--first-day-preview") {
            let steps = FirstDayChecklist.steps(tracksGLP1: true, pulseEnabled: true)
            return FirstDayChecklist(steps: steps, done: [.shot])
        }
        #endif
        guard let userId = currentAccountId, FirstDayChecklist.isVisible(
            accountCreated: appState.profile?.createdAt,
            dismissed: FirstDayChecklistStore.isDismissed(userId: userId),
            completedOn: FirstDayChecklistStore.completedOn(userId: userId)
        ) else { return nil }
        let steps = FirstDayChecklist.steps(
            tracksGLP1: GLP1TrackingStore.shared.isTracking,
            pulseEnabled: PulseProfileStore.shared.pulseEnabled
        )
        return FirstDayChecklist(steps: steps, done: FirstDayChecklistStore.done(userId: userId))
    }

    /// Ticks off steps from what Today can already see: a meal or water logged today, a shot on
    /// record. Pulse is ticked from the Pulse tab when a message sends (CoachViewModel).
    private func recordFirstDayProgress() {
        guard vm.isToday, let userId = currentAccountId,
              appState.profile.map({ FirstDayChecklist.isVisible(accountCreated: $0.createdAt, dismissed: false, completedOn: nil) }) == true
        else { return }
        var changed = false
        if !vm.foodLogs.isEmpty { changed = FirstDayChecklistStore.recordStep(.meal, userId: userId) || changed }
        if vm.waterIntakeMl > 0 { changed = FirstDayChecklistStore.recordStep(.water, userId: userId) || changed }
        if vm.latestGLP1 != nil { changed = FirstDayChecklistStore.recordStep(.shot, userId: userId) || changed }
        if let checklist = firstDayChecklist, checklist.isComplete {
            FirstDayChecklistStore.markCompleted(on: Date.now.isoDateString, userId: userId)
        }
        if changed { firstDayRevision += 1 }
    }

    private func openFirstDayStep(_ step: FirstDayStep) {
        switch step {
        case .meal: appState.pendingOpenTalkToLog = true
        case .shot: showRitual = true
        case .water: showWaterPicker = true
        case .pulse: appState.pendingSelectTab = .pulse
        }
    }

    private func dismissFirstDay() {
        guard let userId = currentAccountId else { return }
        if let checklist = firstDayChecklist {
            Telemetry.firstDayDismissed(doneCount: checklist.doneCount, stepCount: checklist.steps.count)
        }
        FirstDayChecklistStore.dismiss(userId: userId)
        withAnimation(.easeOut(duration: 0.2)) { firstDayRevision += 1 }
    }

    // Health permissions live in the Health app (Sharing → Apps), not in this app's
    // Settings page, so openSettingsURLString would drop the user somewhere with no
    // Health controls at all. Fall back to it only if the Health app can't be opened.
    // Plays a latched protein win, but only with Today actually in front of the user. The short
    // delay lets the sheet finish sliding away, so the lime flood is seen from its start.
    private func playProteinCelebrationIfVisible() {
        guard proteinCelebrationPending, !isLighterToday, isFrontmost, !showProteinRescue,
              !showRecoveryLogger, vm.isToday else { return }
        proteinCelebrationPending = false
        proteinCelebrationInFlight = true
        let accountId = currentAccountId
        let date = vm.selectedDate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard proteinCelebrationInFlight, isFrontmost, !isLighterToday, vm.proteinGoalHit,
                  currentAccountId == accountId, vm.selectedDate.isoDateString == date.isoDateString else {
                proteinCelebrationInFlight = false
                return
            }
            proteinCelebrationInFlight = false
            proteinCelebrationTrigger += 1
            // Only remembered once the moment actually starts playing — a latch that never
            // got to play (interrupted before this point) shouldn't be marked as spent.
            if let accountId {
                FloorClearedCelebrationStore.markCelebrated(userId: accountId, on: date)
            }
            // The generic ring-close haptic already covers the all-rings case, so only buzz
            // here when protein hit on its own.
            if !vm.justClosedAllRings {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func openHealthApp() {
        if let health = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(health) {
            UIApplication.shared.open(health)
        } else if let settings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settings)
        }
    }

    private var presentedContent: some View {
            scrollContent
            .background(Theme.Colors.ground.ignoresSafeArea())
            // No navigation bar, so cover the status bar or scrolled tiles slide under the clock.
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: 0)
                    .background(Theme.Colors.ground)
            }
            .scrollContentBackground(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            // Swipe the canvas to change days — right = previous, left = next (blocked at
            // today). Runs alongside vertical scroll; only a clearly horizontal swipe counts.
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height),
                              abs(value.translation.width) > 60 else { return }
                        if value.translation.width > 0 {
                            vm.goToPreviousDay()
                        } else {
                            vm.goToNextDay()
                        }
                    }
            )
            .navigationDestination(isPresented: $showBodyHub) {
                BodyHubView(todayVM: vm, heightCm: appState.profile?.heightCm)
            }
            .sheet(isPresented: $showWaterPicker) {
                WaterPickerSheet(
                    intakeMl: vm.waterIntakeMl,
                    goalMl: vm.waterGoalMl,
                    unit: waterUnit,
                    usualMl: Binding(get: { usualWaterMl }, set: { storedUsualWaterMl = $0 }),
                    onAdd: { ml in await vm.addWater(ml) },
                    onUndo: { id, ml in await vm.undoWater(id: id, ml: ml) },
                    loadHistory: {
                        guard let owner = appState.session?.user.id else { return [] }
                        return (try? LocalStore.shared.waterHistory(for: vm.selectedDate, userId: owner)) ?? []
                    }
                )
            }
            .sheet(isPresented: $showMovement) {
                MovementSheet(vm: vm)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selected: vm.selectedDate) { picked in
                    vm.goTo(date: picked)
                }
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showRitual) {
                InjectionRitualView(latest: vm.latestGLP1) { saved in
                    vm.registerLoggedInjection(saved)
                }
            }
            .sheet(isPresented: $showBodyCompSheet) {
                BodyCompositionSheet(
                    current: vm.bodyComp,
                    heightCm: appState.profile?.heightCm
                ) { weightKg, bodyFatPct, bmi, lbmKg, measurementsCm, writeToHK in
                    await vm.saveBodyComposition(
                        weightKg: weightKg,
                        bodyFatPct: bodyFatPct,
                        bmi: bmi,
                        lbmKg: lbmKg,
                        measurementsCm: measurementsCm,
                        writeToHK: writeToHK
                    )
                }
            }
            .sheet(isPresented: $showProteinRescue, onDismiss: {
                playProteinCelebrationIfVisible()
            }) {
                ProteinRescueSheet(
                    date: vm.selectedDate,
                    proteinGap: vm.recoveryOpportunity?.proteinGap
                        ?? max(Int(((vm.dailyGoal?.proteinG ?? 0) - vm.totalProteinG).rounded()), 0),
                    calorieRoom: max(Int(((vm.dailyGoal?.calories ?? 0) - vm.totalCalories).rounded()), 0),
                    onLogged: { Task { await vm.loadData() } },
                    onBuildMyOwn: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showRecoveryLogger = true
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showRecoveryLogger, onDismiss: {
                Task { await vm.loadData() }
            }) {
                FoodLoggingView(selectedDate: vm.selectedDate)
            }
            .sheet(isPresented: $showShotCycleCheckIn) {
                if let cycleDay = vm.currentShotCycleDay {
                    ShotCycleCheckInSheet(
                        cycleDay: cycleDay,
                        existing: vm.todayShotCycleCheckIn,
                        onSave: { draft in await vm.saveShotCycleCheckIn(draft) }
                    )
                    .presentationDetents([.large])
                }
            }
            .alert("Couldn’t save check-in", isPresented: Binding(
                get: { vm.shotCycleCheckInError != nil },
                set: { if !$0 { vm.shotCycleCheckInError = nil } }
            )) {
                Button("OK", role: .cancel) { vm.shotCycleCheckInError = nil }
            } message: {
                Text(vm.shotCycleCheckInError ?? "Please try again.")
            }
            .sheet(item: $editingLog) { log in
                EditFoodLogSheet(
                    log: log,
                    onSave: { meal, quantity in
                        await vm.editLog(id: log.id, meal: meal, quantity: quantity)
                    }
                )
            }
            .sheet(isPresented: $showLighterTracking) { LighterTrackingSheet() }
            .sheet(isPresented: $showStrongWeek, onDismiss: { strongWeek.editing = false }) {
                StrongWeekView(vm: strongWeek, profile: appState.profile)
            }
            .confirmationDialog("Use a recent meal", isPresented: $showRecentMeals, titleVisibility: .visible) {
                ForEach(vm.recentMeals.keys.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { meal in
                    Button(meal.displayName) {
                        repeatedMealRoute = SmartNotificationRoute(
                            action: .reviewMeal, sourceDate: vm.recentMealDate, mealRawValue: meal.rawValue
                        )
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let sourceDate = vm.recentMealDate.flatMap({ Date.fromISODateString($0) }) {
                    Text("From \(sourceDate.formatted(date: .abbreviated, time: .omitted)). Review servings before adding to today.")
                }
            }
            .sheet(item: $repeatedMealRoute) { route in
                if let sourceDate = route.sourceDate, let meal = route.meal {
                    RepeatedMealConfirmationSheet(
                        sourceDate: sourceDate,
                        meal: meal,
                        vm: vm
                    )
                }
            }
    }

    var body: some View {
        NavigationStack {
            presentedContent
            .task(id: vm.selectedDate) {
                #if DEBUG
                if AppStoreScreenshotMode.active || DebugLaunch.tour {
                    strongWeek.isLoading = false
                    strongWeek.current = AppStoreScreenshotPreview.week
                    return
                }
                #endif
                // The drift check inside loadData needs the user's stats.
                vm.profile = appState.profile
                await vm.loadData()
                if vm.isToday { await strongWeek.load() }
                openWeeklyReminderIfNeeded()
            }
            #if DEBUG
            // --floor-cleared-preview (with --tour for data): tops protein up past the floor two
            // seconds in and plays the moment through the real latch, to review the animation.
            .task {
                guard ProcessInfo.processInfo.arguments.contains("--floor-cleared-preview"),
                      let goal = vm.dailyGoal?.proteinG, vm.totalProteinG < goal,
                      let sample = vm.foodLogs.first else { return }
                try? await Task.sleep(for: .seconds(2))
                vm.foodLogs.append(FoodLog(
                    id: UUID(), userId: sample.userId, loggedAt: .now, logDate: sample.logDate, meal: .snack,
                    foodItemId: UUID(), quantity: 1, caloriesSnapshot: 180,
                    proteinGSnapshot: goal - vm.totalProteinG + 6, carbsGSnapshot: 8, fatGSnapshot: 4,
                    fiberGSnapshot: 0, foodItems: .init(name: "Protein shake", brand: nil, servingDesc: "1 bottle")
                ))
                proteinCelebrationPending = true
                playProteinCelebrationIfVisible()
            }
            #endif
            .onChange(of: vm.justClosedAllRings) { _, justClosed in
                guard vm.isToday, !isLighterToday, justClosed else { return }
                ringCelebrationTrigger += 1
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            // First-day checklist and tips: their observers live on a hidden view of their own
            // (firstDayObserver) to keep this modifier chain short enough to type-check.
            .background { firstDayObserver }
            .onChange(of: vm.justHitProteinGoal) { _, justHit in
                guard vm.isToday, !isLighterToday, justHit else { return }
                // A fresh view model (new launch, or swiping back to today from another day)
                // recomputes this edge from scratch, so it can fire again for a floor that was
                // already cleared — and already celebrated — earlier today. The persisted record
                // is the only thing that remembers across that reset (iOS used to keep the latch
                // in memory only, so it could replay).
                if let accountId = currentAccountId,
                   FloorClearedCelebrationStore.hasCelebrated(userId: accountId, on: vm.selectedDate) {
                    return
                }
                // Don't fire here — logging food is what pushes protein over the line, and the
                // reload lands while the logging sheet still covers the ring. Latch it and let
                // the handler below play it once Today is actually on screen.
                proteinCelebrationPending = true
                playProteinCelebrationIfVisible()
            }
            .onChange(of: isFrontmost) { _, frontmost in
                if frontmost { Task { await strongWeek.load() } }
                playProteinCelebrationIfVisible()
            }
            .onChange(of: showRecoveryLogger) { _, _ in
                playProteinCelebrationIfVisible()
            }
            .onChange(of: appState.pendingStrongWeekReminder) { _, pending in
                if pending { openWeeklyReminderIfNeeded() }
            }
            .onChange(of: appState.pendingQuickAction) { _, action in
                guard let action else { return }
                if action == .logDose {
                    appState.pendingQuickAction = nil; showRitual = true
                } else if action == .offScript {
                    appState.pendingQuickAction = nil
                    offScriptOwner = appState.session?.user.id; offScriptPrompt = nil; showOffScript = true
                }
            }
            .onChange(of: appState.pendingSmartNotificationRoute) { _, route in
                guard let route else { return }
                switch route.action {
                case .closeProtein:
                    appState.pendingSmartNotificationRoute = nil
                    showProteinRescue = true
                case .reviewMeal:
                    appState.pendingSmartNotificationRoute = nil
                    repeatedMealRoute = route
                case .viewPreparation:
                    // The preparation card is already in Today's ranked Pulse slot.
                    appState.pendingSmartNotificationRoute = nil
                case .addWater, .repeatMeal:
                    break
                }
            }
            .onChange(of: SyncEngine.shared.lastSyncAt) { _, _ in
                // `lastSyncAt` advances only after a full pull (foreground/reconnect), not
                // after pushing a local mutation. Water already updates optimistically;
                // reloading here after every quick-add replaced the whole page with a
                // spinner and made each selection look like a full refresh.
                Task { await vm.loadData() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    // The day may have rolled over while the app was suspended.
                    // Snapping first mutates vm.selectedDate, which re-fires the
                    // .task(id:) above and reloads the correct day's data.
                    vm.snapToTodayIfDayChanged()
                    Task { await vm.loadHealthData() }
                }
            }
            // Fires at midnight (and on timezone changes) while the app is foregrounded.
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.significantTimeChangeNotification
            )) { _ in
                vm.snapToTodayIfDayChanged()
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodAccessChanged)) { _ in
                strongWeek.foodPreferencesChanged()
            }
            .onReceive(NotificationCenter.default.publisher(for: .strongWeekChanged)) { _ in
                Task { await vm.loadData() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .glp1DoseHistoryChanged)) { _ in
                strongWeek.changedSinceGeneration = true
                Task { await vm.loadData() }
            }
            .background { memorySheetPresenter }
            .sheet(isPresented: $showSaveUsualMeal) { SaveUsualMealSheet(foods: usualMealFoods) }
        .sheet(item: $editingMealNote) { note in
            MealNoteSheet(date: vm.selectedDate, meal: note.meal, existing: note) {
                Task { await vm.loadMealNotes() }
            }
        }
        .confirmationDialog("Delete this meal note?", isPresented: Binding(
            get: { deletingMealNote != nil }, set: { if !$0 { deletingMealNote = nil } }
        ), titleVisibility: .visible) {
            Button("Delete note", role: .destructive) {
                guard let note = deletingMealNote else { return }
                Task {
                    do { try await MealNoteRepository().delete(note); await vm.loadMealNotes(); mealNoteError = nil }
                    catch { mealNoteError = "Couldn’t delete your note. Please try again." }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .foodSaveUndone)) { _ in
            proteinCelebrationPending = false
            proteinCelebrationInFlight = false
            Task { await vm.loadData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mealNotesChanged)) { _ in
            Task { await vm.loadMealNotes() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trackingModeChanged)) { _ in
                if isLighterToday { proteinCelebrationPending = false }
                Task { await vm.refreshSmartNotifications() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .smartCoachingSettingsChanged)) { _ in
                Task { await vm.refreshSmartNotifications() }
            }
            // Pulse toggled off cancels any pending smart notification immediately (see
            // NotificationManager); toggled back on, re-evaluate now rather than waiting for
            // the next natural trigger (a workout finishing, etc.).
            .onReceive(NotificationCenter.default.publisher(for: .pulseProfileChanged)) { _ in
                Task { await vm.refreshSmartNotifications() }
            }
        }
    }

    private var memorySheetPresenter: some View {
        Color.clear.frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: .quickCaptureChanged)) { notification in
                guard notification.object as? UUID == appState.session?.user.id else { return }
                Task { await vm.loadData() }
            }
            .sheet(item: $rememberingNote) { note in PulseMemoryEditor(proposed: note.body) }
            .sheet(isPresented: $showEverydayTools, onDismiss: {
                let prompt = offScriptPrompt; offScriptPrompt = nil
                guard let owner = offScriptOwner, owner == appState.session?.user.id, let prompt else { return }
                appState.askPulse(prompt)
            }) {
                if let owner = offScriptOwner {
                    EverydayToolsView(userId: owner, onAskPulse: { offScriptPrompt = $0 })
                }
            }
            .sheet(isPresented: $showOffScript, onDismiss: {
                let prompt = offScriptPrompt; offScriptPrompt = nil
                guard let owner = offScriptOwner, owner == appState.session?.user.id, let prompt else { return }
                appState.askPulse(prompt)
            }) {
                if let owner = offScriptOwner {
                    OffScriptSheet(userId: owner, date: .now, onAskPulse: { offScriptPrompt = $0 },
                                   onSaved: { Task { await vm.loadMealNotes() } })
                }
            }
    }

    private var scrollContent: some View {
            ScrollView {
                VStack(spacing: Theme.Spacing.tileGap) {
                    header
                    if vm.isToday {
                        Button {
                            offScriptOwner = appState.session?.user.id; offScriptPrompt = nil; showOffScript = true
                        } label: {
                            HStack {
                                Label("Today went sideways", systemImage: "arrow.triangle.branch")
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                            }.font(Theme.Fonts.body(15, .semibold)).foregroundStyle(Theme.Colors.primaryText)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.buttonStyle(.plain)
                    }

                    if vm.isToday {
                        Button {
                            offScriptOwner = appState.session?.user.id; offScriptPrompt = nil; showEverydayTools = true
                        } label: {
                            HStack {
                                Label("Make today easier", systemImage: "sparkles")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }.font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44)
                        }.buttonStyle(.plain).foregroundStyle(Theme.Colors.primaryText)
                    }

                    // No account in the tour, so every sync "fails"; that banner is noise there.
                    if let status = SyncEngine.shared.statusMessage, !DebugLaunch.tour {
                        SyncStatusBanner(status: status) {
                            Task { await SyncEngine.shared.syncNow() }
                        }
                    }

                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // Pulse gets one adaptive slot. A single, ranked next step keeps Today
                        // calm even when dose, recovery, pacing, and target signals coexist.
                        pulsePriorityCard
                            .popIn(order: 1)

                        if isLighterToday {
                            lighterTodayContent
                        } else {
                            firstDayCard
                            tileGrid
                            if vm.isToday {
                                Button("Need a lighter week?") { showLighterTracking = true }
                                    .font(Theme.Fonts.body(14, .semibold))
                                    .foregroundStyle(Theme.Colors.primaryText)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                        }

                        if vm.foodLogs.isEmpty, vm.mealNotes.isEmpty, !BreakfastCheckinStore.shared.checkins.contains(where: { $0.localDay == vm.selectedDate.isoDateString }), !vm.showsReturnExperience, !isLighterToday {
                            EmptyDayView(isToday: vm.isToday)
                                .popIn(order: 7)
                        } else {
                            // Meal sections in fixed display order (breakfast → snack)
                            mealSections
                        }

                        BreakfastCheckinCard(date: vm.selectedDate, hasDetailedBreakfast: vm.foodLogs.contains { $0.meal == .breakfast }) {
                            appState.pendingOpenTalkToLog = true
                        }
                        mealNoteSections

                        if vm.isToday, !isLighterToday, !vm.availableYesterdayMeals.isEmpty {
                            RepeatYesterdayCard(
                                meals: vm.availableYesterdayMeals
                                    .map { (meal: $0.key, itemCount: $0.value.count) }
                                    .sorted { $0.meal.sortOrder < $1.meal.sortOrder },
                                busyMeal: vm.repeatingMeal,
                                onRepeat: { meal in Task { await vm.repeatYesterday(meal) } }
                            )
                        }

                        if vm.isToday, !isLighterToday {
                            StrongWeekCard(vm: strongWeek) {
                                showStrongWeek = true
                                Task { await strongWeek.load() }
                            }
                        }

                        if !isLighterToday, HealthKitManager.shared.isAvailable {
                            HealthStatsCard(
                                context: vm.recoveryContext,
                                shotCycleCheckIn: vm.todayShotCycleCheckIn,
                                shotCycleDay: vm.currentShotCycleDay,
                                activeCalories: vm.activeCalories,
                                restingHR:      vm.restingHeartRate,
                                hrv:            vm.hrv,
                                sleepHours:     vm.sleepHours,
                                hasRequestedAuthorization: HealthKitManager.shared.hasRequestedAuthorization,
                                onConnect:       { Task { await vm.requestHealthAuthorization() } },
                                onOpenHealthApp: openHealthApp
                            )
                        }

                        if !isLighterToday { BodyCompositionCard(
                            data: vm.bodyComp,
                            waistCm: vm.latestWaistCm,
                            units: units,
                            onOpen: { showBodyHub = true },
                            onAddTapped: { showBodyCompSheet = true }
                        ) }

                        if let error = vm.errorMessage {
                            Text(error)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.danger)
                                .padding()
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.bottom, Theme.Spacing.xl)
            }
    }

    private var lighterTodayContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if TrackingPreferencesStore.shared.needsResumeChoice {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your lighter stretch has ended").font(Theme.Fonts.body(18, .bold))
                    Text("Keep taking it easier, or return to usual tracking when you’re ready. Goal reminders stay paused until you choose.")
                        .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
                    Button("Keep taking it easier") {
                        Task {
                            do { try await TrackingPreferencesStore.shared.start(reason: nil, duration: .untilReady); lighterTrackingError = nil }
                            catch { lighterTrackingError = "Couldn’t save your choice. Please try again." }
                        }
                    }.buttonStyle(.brandPrimary).disabled(TrackingPreferencesStore.shared.isSaving)
                    Button("Return to usual tracking") {
                        Task {
                            do { try await TrackingPreferencesStore.shared.resume(); lighterTrackingError = nil }
                            catch { lighterTrackingError = "Couldn’t resume. Please try again." }
                        }
                    }.font(Theme.Fonts.body(15, .semibold)).foregroundStyle(Theme.Colors.primaryText)
                        .frame(minHeight: 44).disabled(TrackingPreferencesStore.shared.isSaving)
                }.tile(padding: Theme.Spacing.md)
            }
            HStack {
                Text("Lighter tracking is on").font(Theme.Fonts.body(15, .semibold))
                Spacer()
                Button("Manage") { showLighterTracking = true }
                    .font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44)
            }
            .foregroundStyle(Theme.Colors.primaryText)
            .padding(.horizontal, Theme.Spacing.md)
            .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: Theme.Radius.row))

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Make room for your week.")
                    .font(Theme.Fonts.display(28, .bold, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                Text("Log what’s useful. Leave the rest.")
                    .font(Theme.Fonts.body(17)).foregroundStyle(Theme.Colors.textSecondary)
                Button("Log something") { appState.pendingOpenTalkToLog = true }
                    .buttonStyle(.brandPrimary)
                if PulseProfileStore.shared.pulseEnabled {
                    Button("Talk with Pulse") { appState.pendingSelectTab = .pulse }
                        .font(Theme.Fonts.body(16, .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .foregroundStyle(Theme.Colors.textPrimary)
            .tile(padding: Theme.Spacing.md)

            Button { showWaterPicker = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Water").font(Theme.Fonts.display(20, .bold, relativeTo: .headline))
                        Text(vm.waterIntakeMl > 0
                             ? "\(waterUnit.displayAmount(vm.waterIntakeMl)) logged"
                             : "Add a drink when you like")
                            .font(Theme.Fonts.body(14))
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill").font(.system(size: 32))
                }
                .foregroundStyle(Theme.Colors.skyInk)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                .background(Theme.Colors.sky, in: RoundedRectangle(cornerRadius: Theme.Radius.tile))
            }
            .buttonStyle(.plain)
            Text("Your food entries")
                .font(Theme.Fonts.body(16, .semibold))
                .accessibilityAddTraits(.isHeader)
            if vm.foodLogs.isEmpty && vm.mealNotes.isEmpty {
                Text("Nothing logged today")
                    .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
            }
            Text("Goal reminders are paused. Incomplete days stay unassessed.")
                .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
            if !TrackingPreferencesStore.shared.needsResumeChoice {
            Button("Return to usual tracking") {
                Task {
                    do { try await TrackingPreferencesStore.shared.resume(); lighterTrackingError = nil }
                    catch { lighterTrackingError = "Couldn’t resume tracking. Please try again." }
                }
            }
            .font(Theme.Fonts.body(15, .semibold))
            .foregroundStyle(Theme.Colors.primaryText)
            .frame(minHeight: 44)
            .disabled(TrackingPreferencesStore.shared.isSaving)
            }
            if let lighterTrackingError {
                Text(lighterTrackingError).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger)
            }
        }
    }

    // MARK: - Tile grid

    // Protein spans the left column beside calories and the shot cycle; water and movement sit
    // below. Without a shot cycle, movement moves up beside protein and water takes the row.
    private var tileGrid: some View {
        let cycleDay = vm.currentShotCycleDay
        let showsShotCycle = cycleDay != nil && !vm.doseSchedule.cycleInterrupted
        return VStack(spacing: Theme.Spacing.tileGap) {
            HStack(alignment: .top, spacing: Theme.Spacing.tileGap) {
                ProteinTile(
                    proteinG: vm.totalProteinG,
                    goalG: vm.dailyGoal?.proteinG,
                    hasFoodLogs: !vm.foodLogs.isEmpty,
                    // Stay indigo until the moment can play to someone watching.
                    holdsClear: vm.isToday && (proteinCelebrationPending || proteinCelebrationInFlight),
                    celebration: proteinCelebrationTrigger
                )
                    .celebrationBeat(trigger: ringCelebrationTrigger)
                    .popIn(order: 2)
                VStack(spacing: Theme.Spacing.tileGap) {
                    CaloriesTile(
                        calories: vm.totalCalories,
                        carbsG: vm.totalCarbsG,
                        fatG: vm.totalFatG,
                        fiberG: vm.totalFiberG,
                        goal: vm.dailyGoal,
                        hasFoodLogs: !vm.foodLogs.isEmpty
                    )
                    .popIn(order: 3)
                    if showsShotCycle, let cycleDay {
                        ShotCycleTile(cycleDay: cycleDay, cycleLength: shotCycleLength) {
                            showShotCycleCheckIn = true
                        }
                        .popIn(order: 4)
                    } else {
                        movedTile.popIn(order: 4)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.tileGap) {
                WaterTile(
                    intakeMl: vm.waterIntakeMl,
                    goalMl: vm.waterGoalMl,
                    unit: waterUnit,
                    usualMl: usualWaterMl,
                    onQuickAdd: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await vm.addWater(usualWaterMl) }
                    },
                    onOpenPicker: { showWaterPicker = true }
                )
                .popIn(order: 5)
                if showsShotCycle {
                    movedTile.popIn(order: 6)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var movedTile: some View {
        MovedTile(workouts: vm.workouts) { showMovement = true }
    }

    private var shotCycleLength: Int { vm.latestGLP1?.cycleLengthDays ?? 7 }

    private func openWeeklyReminderIfNeeded() {
        guard appState.pendingStrongWeekReminder else { return }
        appState.pendingStrongWeekReminder = false
        showStrongWeek = true
        Task { await strongWeek.load() }
    }

    @ViewBuilder
    private var pulsePriorityCard: some View {
        if doseCardDismissedDay != Date.now.isoDateString, let log = vm.latestGLP1,
           !vm.injectionLoggedToday, vm.doseStatus != nil {
            VStack(spacing: Theme.Spacing.sm) {
                DoseDayCard(
                    medication: log.medication,
                    doseText: "\(log.doseMg.glp1DoseString) mg",
                    overdue: vm.doseStatus?.urgent ?? false,
                    plannedFor: vm.doseSchedule.nextDue,
                    lastShot: log.injectedAt,
                    missedMoreThanOneDose: vm.doseSchedule.missedMoreThanOneDose,
                    completed: false,
                    onTap: { showRitual = true },
                    onDismiss: { doseCardDismissedDay = Date.now.isoDateString }
                )
                DoseSkipControl(schedule: vm.doseSchedule) { await vm.loadData() }
                    .padding(Theme.Spacing.md).card()
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if vm.isToday, vm.doseScheduleLoaded, vm.doseSchedule.skippedThisWeek != nil {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                DoseSkipControl(schedule: vm.doseSchedule) { await vm.loadData() }
                Button("Log a shot instead") { showRitual = true }
                    .font(Theme.Fonts.body(14, .semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            .tile(radius: Theme.Radius.tileSmall, padding: Theme.Spacing.md)
        } else if dismissedShotCheckInDay != Date.now.isoDateString,
                  vm.scheduledShotCycleCheckInDue,
                  let cycleDay = vm.currentShotCycleDay {
            ShotCycleCheckInCard(
                cycleDay: cycleDay,
                onCheckIn: { showShotCycleCheckIn = true },
                onNotNow: { dismissedShotCheckInDay = Date.now.isoDateString }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if TrackingPreferencesStore.shared.suppressesGoalPrompts {
            EmptyView()
        } else if vm.showsReturnExperience {
            ReturnToTodayCard(
                hasRecentMeals: !vm.recentMeals.isEmpty,
                onLogFood: { appState.pendingOpenTalkToLog = true },
                onRecentMeal: { showRecentMeals = true }
            )
        } else if let recovery = vm.recoveryOpportunity {
            // Not Pulse: a general recovery card, and "Close Xg gap" opens the local protein
            // rescue sheet rather than handing anything to the coach. Nothing here to gate.
            RecoveryCoachCard(
                opportunity: recovery,
                onCloseGap: {
                    Telemetry.recoveryActionUsed(action: "closeProteinGap")
                    showProteinRescue = true
                },
                onAddWater: { ml in
                    Telemetry.recoveryActionUsed(action: "addWater")
                    Task { await vm.addWater(ml) }
                }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if pulseOnToday, let preparation = vm.lowAppetitePreparation,
                  !LowAppetitePreparationStore.isCompleted(preparation) {
            LowAppetitePreparationCard(
                preparation: preparation,
                onPlan: pulseActive ? {
                    appState.askPulse(
                        "Tomorrow is cycle day \(preparation.targetCycleDay), which has usually been a lower-appetite day for me. Help me choose one small protein-dense backup to prepare today."
                    )
                } : nil,
                onPrepared: {
                    LowAppetitePreparationStore.markCompleted(preparation)
                    completedPreparation = LowAppetitePreparationStore.signature(for: preparation)
                    Task { await vm.refreshSmartNotifications() }
                }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if let suggestion = vm.retargetSuggestion {
            // Not Pulse: adjusts the daily target directly, no hand-off to the coach.
            RetargetCard(
                suggestion: suggestion,
                units: units,
                onAccept: { Task { await vm.acceptRetarget() } },
                onKeep: { vm.dismissRetarget() }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if pulseOnToday, let nudge = vm.nudge {
            UnderEatingNudgeCard(nudge: nudge, onAsk: pulseActive ? { appState.askPulse(nudge.prompt) } : nil)
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if doseCardDismissedDay != Date.now.isoDateString, let log = vm.latestGLP1,
                  vm.injectionLoggedToday {
            // The completed state remains a quiet celebration, but yields to anything the
            // user can still act on today.
            DoseDayCard(
                medication: log.medication,
                doseText: "\(log.doseMg.glp1DoseString) mg",
                completed: true,
                onDismiss: { doseCardDismissedDay = Date.now.isoDateString }
            )
        }
    }
}

private struct SyncStatusBanner: View {
    let status: SyncStatusMessage
    let retry: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: status.icon)
                .foregroundStyle(Theme.Colors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(status.detail)
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer(minLength: Theme.Spacing.sm)

            if status.canRetry {
                Button("Try again", action: retry)
                    .font(Theme.Fonts.body(12, .semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Theme.Colors.primarySoft, in: Capsule())
            }
        }
        .tile(radius: Theme.Radius.row, padding: Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyDayView: View {
    let isToday: Bool

    var body: some View {
        BrandedEmptyState(
            icon: "fork.knife",
            title: isToday ? "Nothing logged yet" : "Nothing logged this day",
            message: isToday
                ? "Tap Log below to add your first meal — talk it, search, or scan."
                : "Add what you ate with the Log button below."
        )
    }
}

/// Persists the floor-cleared celebration's "already played today" record, so it plays once per
/// calendar day per signed-in account (Android: FloorClearedMoment.celebrated/release in
/// TodayLogic.kt). Keyed by account so a shared device never carries one account's celebration
/// into another's, storing the ISO date it last played on — a pure, UserDefaults-backed type so
/// it's unit-testable without standing up a view model.
enum FloorClearedCelebrationStore {
    private static func key(userId: String) -> String { "floorClearedCelebrated_\(userId)" }

    static func hasCelebrated(userId: String, on date: Date, defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: key(userId: userId)) == date.isoDateString
    }

    static func markCelebrated(userId: String, on date: Date, defaults: UserDefaults = .standard) {
        defaults.set(date.isoDateString, forKey: key(userId: userId))
    }
}

// SWIFT CONCEPT — #Preview replaces the old PreviewProvider protocol in iOS 17+.
// Xcode renders this in the canvas without running the full app.
// We inject a mock environment so the preview doesn't need real Supabase credentials.
#Preview {
    TodayView(vm: TodayViewModel())
        .environment(AppState())
}

private struct ReturnToTodayCard: View {
    let hasRecentMeals: Bool
    let onLogFood: () -> Void
    let onRecentMeal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Start with today")
                .font(Theme.Fonts.display(26, .bold, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("No need to fill in the missing days. Add one thing you’ve eaten today.")
                .font(Theme.Fonts.body(16))
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Log food", action: onLogFood)
                .buttonStyle(.brandPrimary)
                .frame(maxWidth: .infinity)
            if hasRecentMeals {
                Button("Use a recent meal", action: onRecentMeal)
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .tile(radius: Theme.Radius.tileSmall, padding: Theme.Spacing.md)
    }
}
