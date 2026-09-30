import SwiftUI

// Daylight Log sheet (docs/daylight-redesign.md): a header showing the meal everything logs to
// ("Adding to Dinner ▾") plus a close button, and Talk / Search / Scan / Favorites tabs beneath
// it. Manual entry moved inside Search ("Can't find it? Enter it yourself"); Favorites replaces
// the old Manual tab.
struct FoodLoggingView: View {
    let selectedDate: Date
    let initialTab: FoodLoggingViewModel.LogTab

    // SWIFT CONCEPT — @Environment(\.dismiss) gives any view the ability to close itself
    // when it's presented as a sheet or navigation push. It's like calling
    // router.back() or closing a modal in React — no prop drilling needed.
    @Environment(\.dismiss) private var dismiss
    @State private var vm = FoodLoggingViewModel()
    @State private var searchVM = FoodSearchViewModel()
    @State private var talkVM = TalkToLogViewModel()
    @State private var favoritesVM = FavoritesViewModel()
    @State private var showManualEntry = false

    init(selectedDate: Date, initialTab: FoodLoggingViewModel.LogTab = .talk) {
        self.selectedDate = selectedDate
        self.initialTab = initialTab
        _vm = State(initialValue: FoodLoggingViewModel(selectedTab: initialTab))
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

            LogTabBar(selection: $vm.selectedTab)

            Group {
                switch vm.selectedTab {
                case .talk:
                    TalkToLogView(vm: talkVM, date: selectedDate, headerMeal: vm.selectedMeal, onLogged: { source in
                        handleLogged(source, keepOpen: false)
                    })
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
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.ground.ignoresSafeArea())
        .tint(Theme.Colors.primary)
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
        .onAppear {
            if !AppStoreScreenshotMode.active {
                Telemetry.logIntentStarted(source: vm.selectedTab.telemetrySource)
            }
        }
    }

    // Every tab's "+" logs without leaving the sheet (keepOpen: true) so a user can add
    // several foods in a row; tapping into the confirm step (a food's name, Talk's Log
    // button, manual entry, a barcode) is a deliberate one-off log that dismisses after.
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
        if !keepOpen {
            dismiss()
        }
    }
}
