import SwiftUI

struct FoodLoggingView: View {
    let selectedDate: Date

    // SWIFT CONCEPT — @Environment(\.dismiss) gives any view the ability to close itself
    // when it's presented as a sheet or navigation push. It's like calling
    // router.back() or closing a modal in React — no prop drilling needed.
    @Environment(\.dismiss) private var dismiss
    @State private var vm = FoodLoggingViewModel()

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
                case .manual:
                    ManualEntryView(vm: vm, date: selectedDate) {
                        dismiss()
                    }
                case .search:
                    ComingSoonView(icon: "magnifyingglass", label: "Food Search", detail: "FatSecret integration coming soon")
                case .scan:
                    ComingSoonView(icon: "barcode.viewfinder", label: "Barcode Scanner", detail: "On-device scanning coming soon")
                }
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil), actions: {
                Button("OK") { vm.errorMessage = nil }
            }, message: {
                Text(vm.errorMessage ?? "")
            })
        }
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
