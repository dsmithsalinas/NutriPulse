import SwiftUI

struct SendFeedbackSheet: View {
    @Bindable var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var category = FeedbackCategory.general
    @State private var message  = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(FeedbackCategory.allCases) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } header: {
                    DaylightSectionHeader("Type")
                }
                .daylightSection()

                Section {
                    TextEditor(text: $message)
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
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
