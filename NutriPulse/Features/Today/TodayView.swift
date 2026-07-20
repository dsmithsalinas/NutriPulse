import SwiftUI
import UIKit

struct TodayView: View {
    // The ViewModel is owned by MainTabView and passed in, so the tab bar's Log action and
    // this screen share one selected date — logging always lands on the day you're viewing.
    let vm: TodayViewModel
    // False while the logging sheet is up or another tab is showing. The protein win is
    // latched until this goes true, so the celebration always plays to a watching user.
    var isFrontmost: Bool = true
    @State private var showBodyCompSheet = false
    @State private var showWorkoutSheet = false
    @State private var showDatePicker = false
    @State private var showRitual = false
    @State private var ringCelebrationTrigger = 0
    @State private var proteinRippleTrigger = 0
    @State private var proteinCelebrationPending = false
    @State private var editingLog: FoodLog? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    // Which day the user dismissed the dose-day card (ISO date). Hides it for that day only;
    // it returns on the next dose day (or as an overdue prompt the following day).
    @AppStorage("doseCardDismissedDay") private var doseCardDismissedDay = ""
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    // Health permissions live in the Health app (Sharing → Apps), not in this app's
    // Settings page, so openSettingsURLString would drop the user somewhere with no
    // Health controls at all. Fall back to it only if the Health app can't be opened.
    // Plays a latched protein win, but only with Today actually in front of the user. The short
    // delay lets the ring spring up to full first, so the ripple reads as the ring completing
    // rather than firing over a half-drawn ring the instant the sheet clears.
    private func playProteinCelebrationIfVisible() {
        guard proteinCelebrationPending, isFrontmost, vm.isToday else { return }
        proteinCelebrationPending = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            proteinRippleTrigger += 1
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    TodayHeaderView(
                        firstName: appState.profile?.fullName?
                            .components(separatedBy: " ").first ?? "there",
                        date: vm.selectedDate,
                        isToday: vm.isToday,
                        onPrevious: vm.goToPreviousDay,
                        onNext: vm.goToNextDay,
                        onToday: vm.goToToday,
                        onPickDate: { showDatePicker = true }
                    )
                    .padding(.top, Theme.Spacing.sm)

                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // On dose day (or overdue), the shot comes to the front — a living-gradient
                        // card that opens the injection ritual, instead of a chip buried in the header.
                        // On dose day the shot comes to the front — a living-gradient card that opens
                        // the ritual. Once logged, it flips to a celebratory "done" state for the rest
                        // of the day, then falls away. The user can also dismiss it for the day.
                        if doseCardDismissedDay != Date.now.isoDateString, let log = vm.latestGLP1 {
                            if vm.injectionLoggedToday {
                                DoseDayCard(
                                    medication: log.medication,
                                    doseText: "\(log.doseMg.glp1DoseString) mg",
                                    completed: true,
                                    onDismiss: { doseCardDismissedDay = Date.now.isoDateString }
                                )
                            } else if let dose = vm.doseStatus {
                                DoseDayCard(
                                    medication: log.medication,
                                    doseText: "\(log.doseMg.glp1DoseString) mg",
                                    overdue: dose.urgent,
                                    onTap: { showRitual = true },
                                    onDismiss: { doseCardDismissedDay = Date.now.isoDateString }
                                )
                            }
                        }

                        HeroNutritionCard(
                            calories: vm.totalCalories,
                            proteinG: vm.totalProteinG,
                            carbsG:   vm.totalCarbsG,
                            fatG:     vm.totalFatG,
                            fiberG:   vm.totalFiberG,
                            goal:     vm.dailyGoal
                        )
                        .celebrationBeat(trigger: ringCelebrationTrigger)
                        .proteinRipple(trigger: proteinRippleTrigger)

                        if let nudge = vm.nudge {
                            UnderEatingNudgeCard(nudge: nudge) {
                                appState.askPulse(nudge.prompt)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if HealthKitManager.shared.isAvailable {
                            HealthStatsCard(
                                activeCalories: vm.activeCalories,
                                restingHR:      vm.restingHeartRate,
                                hrv:            vm.hrv,
                                sleepHours:     vm.sleepHours,
                                hasRequestedAuthorization: HealthKitManager.shared.hasRequestedAuthorization,
                                onConnect:       { Task { await vm.requestHealthAuthorization() } },
                                onOpenHealthApp: openHealthApp
                            )
                        }

                        MovementCard(
                            workouts: vm.workouts,
                            onLog: { showWorkoutSheet = true },
                            onDelete: { workout in Task { await vm.deleteWorkout(id: workout.id) } }
                        )

                        BodyCompositionCard(
                            data: vm.bodyComp,
                            units: units,
                            onAddTapped: { showBodyCompSheet = true }
                        )

                        WaterCard(
                            intakeMl: vm.waterIntakeMl,
                            goalMl:   vm.waterGoalMl
                        ) { ml in
                            Task { await vm.addWater(ml) }
                        }

                        if vm.foodLogs.isEmpty {
                            EmptyDayView(isToday: vm.isToday)
                        } else {
                            // Meal sections in fixed display order (breakfast → snack)
                            ForEach(Meal.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { meal in
                                let logs = vm.logsByMeal[meal] ?? []
                                if !logs.isEmpty {
                                    MealSectionView(
                                        meal: meal,
                                        logs: logs,
                                        onEdit: { editingLog = $0 },
                                        onDelete: { log in Task { await vm.deleteLog(id: log.id) } }
                                    )
                                }
                            }
                        }

                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding()
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
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
                ) { weightKg, bodyFatPct, bmi, lbmKg, writeToHK in
                    await vm.saveBodyComposition(
                        weightKg: weightKg,
                        bodyFatPct: bodyFatPct,
                        bmi: bmi,
                        lbmKg: lbmKg,
                        writeToHK: writeToHK
                    )
                }
            }
            .sheet(isPresented: $showWorkoutSheet) {
                WorkoutEntrySheet { activity, minutes, calories, distanceMeters in
                    await vm.addManualWorkout(
                        activity: activity,
                        durationMinutes: minutes,
                        calories: calories,
                        distanceMeters: distanceMeters
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $editingLog) { log in
                EditFoodLogSheet(
                    log: log,
                    onSave: { meal, quantity in
                        await vm.editLog(id: log.id, meal: meal, quantity: quantity)
                    }
                )
            }
            .task(id: vm.selectedDate) {
                await vm.loadData()
            }
            .onChange(of: vm.justClosedAllRings) { _, justClosed in
                guard vm.isToday, justClosed else { return }
                ringCelebrationTrigger += 1
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            .onChange(of: vm.justHitProteinGoal) { _, justHit in
                guard vm.isToday, justHit else { return }
                // Don't fire here — logging food is what pushes protein over the line, and the
                // reload lands while the logging sheet still covers the ring. Latch it and let
                // the handler below play it once Today is actually on screen.
                proteinCelebrationPending = true
                playProteinCelebrationIfVisible()
            }
            .onChange(of: isFrontmost) { _, _ in
                playProteinCelebrationIfVisible()
            }
            .onChange(of: SyncEngine.shared.lastSyncAt) { _, _ in
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
        }
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

// SWIFT CONCEPT — #Preview replaces the old PreviewProvider protocol in iOS 17+.
// Xcode renders this in the canvas without running the full app.
// We inject a mock environment so the preview doesn't need real Supabase credentials.
#Preview {
    TodayView(vm: TodayViewModel())
        .environment(AppState())
}
