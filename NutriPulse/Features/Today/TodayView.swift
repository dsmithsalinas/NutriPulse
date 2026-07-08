import SwiftUI
import UIKit

struct TodayView: View {
    // SWIFT CONCEPT — @State on a class type works with @Observable in iOS 17.
    // The view OWNS this ViewModel — it's created once and stays alive as long as
    // TodayView is in the view hierarchy. Same role as useState(new ViewModel()) in React
    // if React let you store class instances that outlive renders.
    @State private var vm = TodayViewModel()
    @State private var showFoodLogger = false
    @State private var showBodyCompSheet = false
    @State private var ringCelebrationTrigger = 0
    @State private var editingLog: FoodLog? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    // Health permissions live in the Health app (Sharing → Apps), not in this app's
    // Settings page, so openSettingsURLString would drop the user somewhere with no
    // Health controls at all. Fall back to it only if the Health app can't be opened.
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
                    DateNavigatorView(
                        date: vm.selectedDate,
                        isToday: vm.isToday,
                        onPrevious: vm.goToPreviousDay,
                        onNext: vm.goToNextDay,
                        onToday: vm.goToToday
                    )

                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        MacroRingsSection(
                            calories: vm.totalCalories,
                            proteinG: vm.totalProteinG,
                            carbsG:   vm.totalCarbsG,
                            fiberG:   vm.totalFiberG,
                            goal:     vm.dailyGoal
                        )
                        .celebrationBeat(trigger: ringCelebrationTrigger)

                        if HealthKitManager.shared.isAvailable {
                            HealthStatsCard(
                                activeCalories: vm.activeCalories,
                                netCalories:    vm.netCalories,
                                restingHR:      vm.restingHeartRate,
                                hrv:            vm.hrv,
                                sleepHours:     vm.sleepHours,
                                hasRequestedAuthorization: HealthKitManager.shared.hasRequestedAuthorization,
                                onConnect:       { Task { await vm.requestHealthAuthorization() } },
                                onOpenHealthApp: openHealthApp
                            )
                        }

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
                            EmptyDayView()
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
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showFoodLogger = true } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
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
            // onDismiss fires when the sheet is closed — reloads data so new logs appear.
            // SWIFT CONCEPT — .sheet(isPresented:onDismiss:content:) is SwiftUI's modal.
            // The onDismiss closure is like a Promise.then() that fires after the animation.
            .sheet(isPresented: $showFoodLogger, onDismiss: {
                Task { await vm.loadData() }
            }) {
                FoodLoggingView(selectedDate: vm.selectedDate)
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
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "fork.knife")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("No food logged yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Tap + to log your first meal")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
    }
}

// SWIFT CONCEPT — #Preview replaces the old PreviewProvider protocol in iOS 17+.
// Xcode renders this in the canvas without running the full app.
// We inject a mock environment so the preview doesn't need real Supabase credentials.
#Preview {
    TodayView()
        .environment(AppState())
}
