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
            TileEyebrow("Was this useful?", color: Theme.Colors.textFaint)
            if loading {
                ProgressView().controlSize(.small)
            } else if loadError {
                Text("Couldn't load your feedback.")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Button("Try again") { Task { await load() } }
                    .font(Theme.Fonts.body(13, .semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
            } else {
                HStack(spacing: 10) {
                    ForEach(OutlookRating.allCases) { choice in
                        RatingChip(title: choice.title, symbol: choice.symbol, isSelected: saved?.rating == choice) {
                            rating = choice
                            reasons = Set(saved?.reasons ?? [])
                            saveError = nil
                            showingEditor = true
                        }
                    }
                }
                if saved != nil {
                    Text("Thanks for your feedback. Tap a rating to edit it.")
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
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
                    Section {
                        Picker("Your rating", selection: $rating) {
                            ForEach(OutlookRating.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented)
                    } header: {
                        DaylightSectionHeader("Was this useful?")
                    }
                    .daylightSection()

                    Section {
                        ForEach(OutlookFeedbackReason.allCases) { reason in
                            Toggle(isOn: Binding(
                                get: { reasons.contains(reason) },
                                set: { if $0 { reasons.insert(reason) } else { reasons.remove(reason) } })) {
                                Text(reason.title).font(Theme.Fonts.body(15))
                            }
                        }
                    } header: {
                        DaylightSectionHeader("What could be better? (optional)")
                    } footer: {
                        DaylightSectionFooter("Feedback helps us improve Pulse. It won't change your current outlook. Use Adjust this for me for different suggestions.")
                    }
                    .daylightSection()

                    if let saveError {
                        Section {
                            Text(saveError)
                                .font(Theme.Fonts.body(13))
                                .foregroundStyle(Theme.Colors.danger)
                        }
                        .daylightSection()
                    }
                }
                .daylightForm()
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

/// A pill-style rating chip — filled/tinted when this is the saved rating.
private struct RatingChip: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol + (isSelected ? ".fill" : ""))
                .font(Theme.Fonts.body(14, .semibold))
                .foregroundStyle(isSelected ? Theme.Colors.primaryText : Theme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(isSelected ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.surfaceInset,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Theme.Colors.primary.opacity(0.55) : .clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
