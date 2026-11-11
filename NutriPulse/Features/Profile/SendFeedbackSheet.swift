import SwiftUI

struct SendFeedbackSheet: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var editing: Bool
    @Bindable var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var category = FeedbackCategory.general
    @State private var message  = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if typeSize >= .xxxLarge {
                        VStack(spacing: 0) {
                            ForEach(FeedbackCategory.allCases) { option in
                                Button { category = option } label: {
                                    HStack {
                                        Text(option.displayName)
                                        Spacer(minLength: 12)
                                        Image(systemName: category == option ? "checkmark.circle.fill" : "circle")
                                    }
                                    .font(Theme.Fonts.body(16, .semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.displayName)
                                .accessibilityIdentifier("feedbackCategory" + option.rawValue)
                                .accessibilityAddTraits(category == option ? [.isSelected] : [])
                            }
                        }
                    } else {
                        Picker("Category", selection: $category) {
                            ForEach(FeedbackCategory.allCases) { Text($0.displayName).tag($0) }
                        }.pickerStyle(.segmented).labelsHidden().accessibilityIdentifier("feedbackCategory")
                    }
                } header: {
                    DaylightSectionHeader("Type")
                }
                .daylightSection()

                Section {
                    TextEditor(text: $message).focused($editing)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                } header: {
                    DaylightSectionHeader("What's on your mind?")
                }
                .daylightSection()

                Section {
                    Text("Your app version is included automatically to help us track down issues.")
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .daylightSection()
            }
            .daylightForm()
            .navigationTitle("Send feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editing = false }.accessibilityIdentifier("feedbackKeyboardDone")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await send() } }
                        .disabled(isSaving || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(Theme.Colors.primary)
    }

    private func send() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await vm.submitFeedback(
                category: category,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            vm.errorMessage = "Couldn't send feedback. Try again."
        }
    }
}
