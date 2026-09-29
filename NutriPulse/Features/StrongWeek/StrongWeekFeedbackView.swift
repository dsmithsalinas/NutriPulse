import SwiftUI
import Supabase

struct StrongWeekFeedbackView: View {
    let week: StrongWeek
    var readOnly = false
    @State private var saved: StrongWeekFeedback?
    @State private var rating: OutlookRating = .helpful
    @State private var reasons: Set<OutlookFeedbackReason> = []
    @State private var showingEditor = false
    @State private var loading = true
    @State private var saving = false
    @State private var loadError = false
    @State private var saveError: String?
    private let repository = StrongWeekFeedbackRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Was this useful?").font(.subheadline.weight(.semibold))
            if loading {
                ProgressView().controlSize(.small)
            } else if loadError {
                Text("Couldn't load your feedback.").font(.footnote).foregroundStyle(.secondary)
                Button("Try again") { Task { await load() } }
            } else {
                HStack {
                    ForEach(OutlookRating.allCases) { choice in
                        Button {
                            rating = choice
                            reasons = Set(saved?.reasons ?? [])
                            saveError = nil
                            showingEditor = true
                        } label: {
                            Label(choice.title, systemImage: choice.symbol + (saved?.rating == choice ? ".fill" : ""))
                        }.buttonStyle(.bordered)
                        .accessibilityValue(saved?.rating == choice ? "Selected" : "Not selected")
                    }
                }
                if saved != nil {
                    Text("Thanks for your feedback. Tap a rating to edit it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .disabled(readOnly)
        .task {
            if readOnly { loading = false } else { await load() }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                Form {
                    Section("Was this useful?") {
                        Picker("Your rating", selection: $rating) {
                            ForEach(OutlookRating.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                    Section {
                        ForEach(OutlookFeedbackReason.allCases) { reason in
                            Toggle(reason.title, isOn: Binding(
                                get: { reasons.contains(reason) },
                                set: { if $0 { reasons.insert(reason) } else { reasons.remove(reason) } }))
                        }
                    } header: {
                        Text("What could be better? (optional)")
                    } footer: {
                        Text("Feedback helps us improve Pulse. It won't change your current outlook. Use Adjust this for me for different suggestions.")
                    }
                    if let saveError { Text(saveError).foregroundStyle(.red) }
                }
                .disabled(saving)
                .navigationTitle("Outlook feedback")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEditor = false }.disabled(saving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if saving { ProgressView() }
                        else { Button("Save") { Task { await save() } } }
                    }
                }
            }
            .tint(Theme.Colors.primary)
            .interactiveDismissDisabled(saving)
        }
    }

    @MainActor private func load() async {
        loading = true
        defer { loading = false }
        do {
            saved = try await repository.fetch(for: week)
            loadError = false
        } catch { loadError = true }
    }

    @MainActor private func save() async {
        guard !saving else { return }
        saving = true
        saveError = nil
        defer { saving = false }
        do {
            let result = try await repository.save(for: week, rating: rating, reasons: reasons)
            guard try await supabase.auth.session.user.id == week.userId else { throw URLError(.userAuthenticationRequired) }
            saved = result
            showingEditor = false
        } catch {
            saveError = "Couldn't save your feedback. Your choices are kept here—please try again."
        }
    }
}
