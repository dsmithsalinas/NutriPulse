import SwiftUI

struct SmartNotificationSettingsView: View {
    @AppStorage(NotificationManager.smartCoachingEnabledKey) private var masterEnabled = false
    @AppStorage(SmartNotificationPreferences.workoutKey) private var workoutEnabled = true
    @AppStorage(SmartNotificationPreferences.proteinKey) private var proteinEnabled = true
    @AppStorage(SmartNotificationPreferences.appetiteKey) private var appetiteEnabled = true
    @AppStorage(SmartNotificationPreferences.mealKey) private var mealEnabled = true
    @AppStorage(SmartNotificationPreferences.quietStartKey) private var quietStart = 21
    @AppStorage(SmartNotificationPreferences.quietEndKey) private var quietEnd = 7

    var body: some View {
        Form {
            Section {
                notificationToggle("Workout recovery", "figure.strengthtraining.traditional", $workoutEnabled)
                notificationToggle("Protein closeout", "bolt.heart.fill", $proteinEnabled)
                notificationToggle("Low-appetite preparation", "takeoutbag.and.cup.and.straw.fill", $appetiteEnabled)
                notificationToggle("Usual meals", "fork.knife", $mealEnabled)
            } header: {
                Text("Opportunity types")
            } footer: {
                Text("Pulse still sends at most one coaching notification per day. These controls decide which opportunities can compete for that slot.")
            }

            Section {
                Picker("Starts", selection: $quietStart) {
                    ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                }
                Picker("Ends", selection: $quietEnd) {
                    ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                }
            } header: {
                Text("Quiet hours")
            } footer: {
                Text(quietStart == quietEnd
                     ? "Quiet hours are off."
                     : "Pulse will not schedule coaching between \(hourLabel(quietStart)) and \(hourLabel(quietEnd)). Shot-day reminders are separate.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.ground.ignoresSafeArea())
        .tint(Theme.Colors.primary)
        .navigationTitle("Notification preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
        .disabled(!masterEnabled)
        .onChange(of: workoutEnabled) { _, _ in settingsChanged() }
        .onChange(of: proteinEnabled) { _, _ in settingsChanged() }
        .onChange(of: appetiteEnabled) { _, _ in settingsChanged() }
        .onChange(of: mealEnabled) { _, _ in settingsChanged() }
        .onChange(of: quietStart) { _, _ in settingsChanged() }
        .onChange(of: quietEnd) { _, _ in settingsChanged() }
    }

    private func notificationToggle(_ title: String, _ icon: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) { Label(title, systemImage: icon) }
    }

    private func settingsChanged() {
        NotificationCenter.default.post(name: .smartCoachingSettingsChanged, object: nil)
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        return Calendar.current.date(from: components)?.formatted(date: .omitted, time: .shortened) ?? "\(hour):00"
    }
}

struct SmartNotificationHistoryView: View {
    @State private var entries: [SmartNotificationHistoryEntry] = []
    @State private var showClearConfirmation = false
    @State private var pendingFewerEntry: SmartNotificationHistoryEntry?

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Pulse notifications yet",
                    systemImage: "bell.slash",
                    description: Text("When Pulse finds and schedules a useful opportunity, its reasoning will appear here.")
                )
            } else {
                List {
                    Section {
                        Text("Each entry shows the exact signal that earned Footing's one daily coaching slot. Feedback is saved on this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(entries) { entry in
                        Section {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                HStack(alignment: .top) {
                                    Label(kindTitle(entry.kind), systemImage: kindIcon(entry.kind))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.Colors.primary)
                                    Spacer()
                                    Text(entry.fireDate, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.Colors.textFaint)
                                }

                                Label(statusTitle(entry.status), systemImage: statusIcon(entry.status))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(entry.title).font(.headline)
                                Text(entry.body).font(.subheadline).foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("WHY YOU GOT THIS")
                                        .font(.system(size: 9, weight: .bold)).tracking(0.7)
                                        .foregroundStyle(Theme.Colors.textFaint)
                                    Text(entry.rationale).font(.caption)
                                }
                                .padding(Theme.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12))

                                if entry.status != .scheduled {
                                    HStack {
                                        Text("Was this useful?")
                                            .font(.caption.weight(.semibold))
                                        Spacer()
                                        feedbackButton("Yes", "hand.thumbsup.fill", .helpful, entry)
                                        feedbackButton("No", "hand.thumbsdown.fill", .notHelpful, entry)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .tint(Theme.Colors.primary)
        .navigationTitle("Pulse history")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", systemImage: "trash") { showClearConfirmation = true }
                }
            }
        }
        .confirmationDialog("Clear Pulse history?", isPresented: $showClearConfirmation) {
            Button("Clear history", role: .destructive) {
                SmartNotificationHistoryStore.clear()
                entries = []
            }
        }
        .confirmationDialog(
            "Send fewer like this?",
            isPresented: Binding(
                get: { pendingFewerEntry != nil },
                set: { if !$0 { pendingFewerEntry = nil } }
            ),
            presenting: pendingFewerEntry
        ) { entry in
            Button("Turn off \(kindTitle(entry.kind))") {
                SmartNotificationPreferences.setEnabled(false, for: entry.kind)
                pendingFewerEntry = nil
            }
            Button("Keep it on", role: .cancel) { pendingFewerEntry = nil }
        } message: { entry in
            Text("Your feedback is saved either way. Turning this off updates Notification preferences and prevents future \(kindTitle(entry.kind).lowercased()) prompts.")
        }
        .task {
            await NotificationManager.shared.reconcileSmartNotificationHistory()
            entries = SmartNotificationHistoryStore.load()
        }
    }

    private func feedbackButton(
        _ label: String,
        _ icon: String,
        _ feedback: SmartNotificationHistoryEntry.Feedback,
        _ entry: SmartNotificationHistoryEntry
    ) -> some View {
        Button {
            SmartNotificationHistoryStore.setFeedback(feedback, for: entry.id)
            entries = SmartNotificationHistoryStore.load()
            if feedback == .notHelpful { pendingFewerEntry = entry }
        } label: {
            Label(label, systemImage: entry.feedback == feedback ? "checkmark.circle.fill" : icon)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.bordered)
        .tint(entry.feedback == feedback ? Theme.Colors.primary : .secondary)
        .accessibilityLabel(feedback == .helpful ? "Yes, helpful" : "No, not helpful")
        .accessibilityValue(entry.feedback == feedback ? "Selected" : "Not selected")
    }

    private func kindTitle(_ kind: SmartNotificationKind) -> String {
        switch kind {
        case .workoutRecovery: "Workout recovery"
        case .proteinCloseout: "Protein closeout"
        case .lowAppetite: "Low-appetite preparation"
        case .repeatedMeal: "Usual meal"
        }
    }

    private func kindIcon(_ kind: SmartNotificationKind) -> String {
        switch kind {
        case .workoutRecovery: "figure.strengthtraining.traditional"
        case .proteinCloseout: "bolt.heart.fill"
        case .lowAppetite: "takeoutbag.and.cup.and.straw.fill"
        case .repeatedMeal: "fork.knife"
        }
    }

    private func statusTitle(_ status: SmartNotificationHistoryEntry.Status) -> String {
        switch status {
        case .scheduled: "Scheduled"
        case .delivered: "Delivered"
        case .opened: "Opened"
        case .actioned: "Action taken"
        case .dismissed: "Dismissed"
        }
    }

    private func statusIcon(_ status: SmartNotificationHistoryEntry.Status) -> String {
        switch status {
        case .scheduled: "clock.badge.checkmark"
        case .delivered: "bell.badge"
        case .opened: "envelope.open"
        case .actioned: "checkmark.circle.fill"
        case .dismissed: "xmark.circle"
        }
    }
}
