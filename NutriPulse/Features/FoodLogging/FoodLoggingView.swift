import SwiftUI

struct FoodLoggingView: View {
    let selectedDate: Date

    // SWIFT CONCEPT — @Environment(\.dismiss) gives any view the ability to close itself
    // when it's presented as a sheet or navigation push. It's like calling
    // router.back() or closing a modal in React — no prop drilling needed.
    @Environment(\.dismiss) private var dismiss
    @State private var vm = FoodLoggingViewModel()
    @State private var searchVM = FoodSearchViewModel()
    @State private var talkVM = TalkToLogViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Log method", selection: $vm.selectedTab) {
                    ForEach(FoodLoggingViewModel.LogTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(Theme.Spacing.md)

                switch vm.selectedTab {
                case .talk:
                    TalkToLogView(vm: talkVM, date: selectedDate, onLogged: handleLogged)
                case .manual:
                    ManualEntryView(vm: vm, date: selectedDate, onLogged: handleLogged)
                case .search:
                    FoodSearchView(vm: searchVM, date: selectedDate, onLogged: handleLogged)
                case .scan:
                    BarcodeScanView(vm: searchVM, date: selectedDate, onLogged: handleLogged)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.ground.ignoresSafeArea())
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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
                Telemetry.logIntentStarted(source: vm.selectedTab.telemetrySource)
            }
        }
        .tint(Theme.Colors.primary)
    }

    // Only the talk flow carries a meaningful confirm-card edit rate — every
    // other source logs exactly what the user picked, nothing to correct.
    private func handleLogged(_ source: LogSource) {
        if source == .talk {
            Telemetry.logConfirmed(
                source: source,
                rowsTotal: talkVM.rows.count,
                rowsEdited: talkVM.rows.filter(\.wasEdited).count
            )
        } else {
            Telemetry.logConfirmed(source: source)
        }
        dismiss()
    }
}

private struct ComingSoonView: View {
    let icon: String
    let label: String
    let detail: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.quaternary)
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
