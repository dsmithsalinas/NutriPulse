import SwiftUI

struct TalkToLogView: View {
    @Bindable var vm: TalkToLogViewModel
    let date: Date
    let onLogged: (LogSource) -> Void

    var body: some View {
        Group {
            if vm.hasParsed {
                confirmCard
            } else {
                composer
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Composer (text in, before parsing)

    private var composer: some View {
        VStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Tell Pulse what you ate")
                    .font(Theme.Typography.headline)
                Text("One sentence is plenty — \"a Chipotle bowl with chicken, rice, pico, and cheese.\" Tap the mic on the keyboard to speak it instead of typing.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .topLeading) {
                if vm.inputText.isEmpty {
                    Text("I had…")
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $vm.inputText)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
            }
            .padding(Theme.Spacing.sm)
            .card()

            Spacer()

            Button {
                Task { await vm.parse() }
            } label: {
                if vm.isParsing {
                    ProgressView().tint(.white)
                } else {
                    Text("Parse it")
                }
            }
            .buttonStyle(.brandPrimary)
            .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isParsing)
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Confirm card (rows out, after parsing)

    private var confirmCard: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Theme.Spacing.sm) {
                    Picker("Meal", selection: $vm.selectedMeal) {
                        ForEach(Meal.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { meal in
                            Label(meal.displayName, systemImage: meal.icon).tag(meal)
                        }
                    }
                    .pickerStyle(.segmented)

                    ForEach($vm.rows) { $row in
                        ConfirmRowView(row: $row)
                    }

                    Button("Start Over") { vm.reset() }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, Theme.Spacing.xs)
                }
                .padding(Theme.Spacing.md)
            }

            Button {
                Task {
                    do {
                        try await vm.logAll(on: date)
                        onLogged(.talk)
                    } catch {
                        vm.errorMessage = "Couldn't save that log. Try again."
                    }
                }
            } label: {
                if vm.isLogging {
                    ProgressView().tint(.white)
                } else {
                    // pendingCount, not includedCount: after a partial failure the button
                    // should offer to log only what didn't land.
                    Text(vm.pendingCount == 1 ? "Log it" : "Log \(vm.pendingCount) items")
                }
            }
            .buttonStyle(.brandPrimary)
            .disabled(vm.isLogging || vm.pendingCount == 0)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
            .background(.bar)
        }
    }
}

// One editable row in the confirm card — a single parsed food component.
private struct ConfirmRowView: View {
    @Binding var row: TalkToLogViewModel.ConfirmRow

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                row.isIncluded.toggle()
            } label: {
                // A saved row is locked: it's already in the day, and un-including it here
                // wouldn't remove it.
                Image(systemName: row.isSaved ? "checkmark.circle.fill"
                                 : row.isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(row.isSaved ? Color.green
                                     : row.isIncluded ? Theme.Colors.primary : Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)
            .disabled(row.isSaved)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(row.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if row.source == "estimated" {
                        Text("estimated")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.NutrientColor.fat.opacity(0.15))
                            .foregroundStyle(Theme.NutrientColor.fat)
                            .clipShape(Capsule())
                    }
                }
                Text(row.isSaved
                     ? "Logged · \(Int(row.totalCalories.rounded())) kcal"
                     : "\(Int(row.totalCalories.rounded())) kcal · \(row.servingDesc)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !row.isSaved {
                HStack(spacing: 4) {
                    Text(row.quantity.formatted())
                        .monospacedDigit()
                        .font(.subheadline)
                        .frame(width: 32, alignment: .trailing)
                    Stepper("", value: $row.quantity, in: 0.25...10, step: 0.25)
                        .labelsHidden()
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .card()
        .opacity(row.isIncluded && !row.isSaved ? 1 : 0.4)
    }
}
