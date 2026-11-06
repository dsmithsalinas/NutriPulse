import SwiftUI
import UIKit

@MainActor
struct MedicationSettingsView: View {
    var store: MedicationStore = .shared
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var editing: MedicationSchedule?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Medications & supplements")
                        .font(Theme.Fonts.display(32, .bold)).accessibilityAddTraits(.isHeader)
                    MedicationStoreStatusView(store: store)
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Show on Today", isOn: Binding(get: { store.enabled }, set: { enabled in
                            do { try store.setEnabled(enabled); error = nil } catch { self.error = error.localizedDescription }
                        }))
                        .font(Theme.Fonts.body(20, .bold))
                        .accessibilityIdentifier("medicationsEnabled")
                        .disabled(store.accountID == nil || store.storageFailed || store.hasConflict)
                        Text("Track your doses on Today and get reminders at your chosen times.")
                            .font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textSecondary)
                    }.tile(padding: 16)
                    Text("Turn off to hide this section and pause its reminders. Your items and history stay saved.")
                        .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    if let error { MedicationErrorText(message: error) }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("YOUR ITEMS").font(Theme.Typography.eyebrow).tracking(1)
                            .foregroundStyle(Theme.Colors.primaryText)
                        let items = store.document.currentSchedules(at: .now)
                        if items.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Build your routine").font(Theme.Fonts.display(22, .bold))
                                Text("Add a vitamin, supplement, or medication and choose when you take it.")
                                    .font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textSecondary)
                            }.tile(padding: 16)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(items) { item in
                                    if item.id != items.first?.id { Divider() }
                                    Button { editing = item } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(item.name).font(Theme.Fonts.body(20, .bold)).foregroundStyle(Theme.Colors.textPrimary)
                                                Text([item.amount, medicationDaysSummary(item.weekdays)].filter { !$0.isEmpty }.joined(separator: " · "))
                                                    .font(Theme.Fonts.body(15))
                                                Text(item.times.map { $0.date.formatted(date: .omitted, time: .shortened) }.joined(separator: " · "))
                                                    .font(Theme.Fonts.body(15))
                                                if item.startsAt > .now { Text("Changes start tomorrow").font(Theme.Fonts.body(13)) }
                                            }.foregroundStyle(Theme.Colors.textSecondary)
                                            Spacer(minLength: 4)
                                            Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textSecondary)
                                        }.padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading)
                                    }.buttonStyle(.plain)
                                }
                            }.tile(padding: 16)
                        }
                        Button { adding = true } label: { Label("Add item", systemImage: "plus") }
                            .buttonStyle(.brandPrimary).accessibilityIdentifier("medicationsAdd")
                            .disabled(store.accountID == nil || store.storageFailed || store.hasConflict)
                    }
                    NavigationLink { MedicationHistoryView(store: store) } label: {
                        HStack {
                            Label("View history", systemImage: "clock.arrow.circlepath")
                            Spacer(); Image(systemName: "chevron.right")
                        }.font(Theme.Fonts.body(17, .semibold)).frame(minHeight: 44)
                            .foregroundStyle(Theme.Colors.textPrimary).tile(padding: 16)
                    }.buttonStyle(.plain).accessibilityIdentifier("medicationsHistory")
                    MedicationReminderStatusView()
                    Text("Amounts are per dose. Times determine how often.")
                        .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                }.padding(Theme.Spacing.page)
            }
            .background(Theme.Colors.ground)
            .foregroundStyle(Theme.Colors.textPrimary)
            .tint(Theme.Colors.primary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $adding) { MedicationEditorView(store: store) }
            .sheet(item: $editing) { MedicationEditorView(store: store, schedule: $0) }
            .task { await store.sync(refresh: true); await MedicationNotificationScheduler.shared.reconcile() }
        }
    }
}

@MainActor
struct MedicationEditorView: View {
    var store: MedicationStore
    var schedule: MedicationSchedule?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var weekdays = Set(1...7)
    @State private var everyDay = true
    @State private var times: [MedicationTime] = [.init(minute: 480)]
    @State private var remind = true
    @State private var applyToday = false
    @State private var saving = false
    @State private var error: String?
    @State private var confirmArchive = false
    @State private var routineID = UUID()
    private enum Field { case name, amount }
    @FocusState private var focusedField: Field?

    private var valid: Bool { MedicationCalendar.valid(name: name, amount: amount, weekdays: weekdays, times: times) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(schedule == nil ? "Build your routine" : "Edit your routine").font(Theme.Fonts.display(30, .bold))
                    Text("One item. Times that work for you.").font(Theme.Fonts.body(17)).foregroundStyle(Theme.Colors.textSecondary)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name").font(Theme.Fonts.body(18, .bold))
                        TextField("Vitamin, supplement, or medication", text: $name)
                            .focused($focusedField, equals: .name)
                            .textInputAutocapitalization(.words).accessibilityIdentifier("medicationName")
                            .padding(12).background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12))
                        Divider()
                        HStack {
                            Text("Amount per dose").font(Theme.Fonts.body(18, .bold))
                            Spacer(); Text("Optional").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                        }
                        TextField("e.g. 2 capsules", text: $amount).accessibilityIdentifier("medicationAmount")
                            .focused($focusedField, equals: .amount)
                            .padding(12).background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 12))
                        Text("The amount you take each time.").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    }.tile(padding: 16)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days").font(Theme.Fonts.body(18, .bold))
                        Picker("Days", selection: $everyDay) {
                            Text("Every day").tag(true); Text("Selected days").tag(false)
                        }.pickerStyle(.segmented)
                        .onChange(of: everyDay) { _, value in if value { weekdays = Set(1...7) } }
                        if !everyDay {
                            // Wrapping grid keeps full weekday labels readable at large text.
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 8) {
                                ForEach(1...7, id: \.self) { day in
                                    Button {
                                        if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
                                    } label: {
                                        Text(MedicationCalendar.calendar.shortWeekdaySymbols[day - 1])
                                            .font(Theme.Fonts.body(15, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                                            .background(weekdays.contains(day) ? Theme.Colors.primarySoft : Theme.Colors.surfaceInset,
                                                        in: RoundedRectangle(cornerRadius: 12))
                                    }.buttonStyle(.plain).accessibilityAddTraits(weekdays.contains(day) ? .isSelected : [])
                                }
                            }
                        }
                    }.tile(padding: 16)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DOSE TIMES").font(Theme.Typography.eyebrow).tracking(1).foregroundStyle(Theme.Colors.primaryText)
                        ForEach($times) { $slot in
                            HStack {
                                DatePicker("Dose time", selection: Binding(get: { slot.date }, set: { date in
                                    let parts = MedicationCalendar.calendar.dateComponents([.hour, .minute], from: date)
                                    slot.minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                                }), displayedComponents: .hourAndMinute).labelsHidden()
                                Spacer()
                                Button { times.removeAll { $0.id == slot.id } } label: {
                                    Image(systemName: "minus.circle.fill").frame(width: 44, height: 44)
                                }.disabled(times.count == 1).accessibilityLabel("Remove dose time")
                            }
                            Divider()
                        }
                        Button {
                            let used = Set(times.map(\.minute))
                            if let minute = ([1140, 480, 720, 1020] + Array(stride(from: 0, to: 1440, by: 60))).first(where: { !used.contains($0) }) {
                                times.append(.init(minute: minute))
                            }
                        } label: { Label("Add time", systemImage: "plus").frame(minHeight: 44) }
                        .disabled(times.count >= 12).accessibilityIdentifier("medicationAddTime")
                    }.tile(padding: 16)
                    Text("\(times.count == 1 ? "Once" : (times.count == 2 ? "Twice" : "\(times.count) times")) \(everyDay ? "daily" : "on selected days")\(amount.isEmpty ? "" : " · \(amount) each time")")
                        .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Remind me", isOn: $remind).font(Theme.Fonts.body(18, .bold))
                        Text("A reminder at each dose time. Mark taken from the notification.")
                            .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
                        if !store.enabled { Text("Reminders stay paused until Show on Today is enabled in Profile.").font(Theme.Fonts.body(14)) }
                    }.tile(padding: 16)
                    if schedule != nil {
                        Toggle("Apply to remaining doses today", isOn: $applyToday).font(Theme.Fonts.body(16))
                        Text(applyToday ? "Replaces remaining doses with the times above. Already logged doses stay saved." : "Schedule changes start tomorrow. Today’s doses stay the same.")
                            .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if let error { MedicationErrorText(message: error) }
                    Button(saving ? "Saving…" : "Save item") { Task { await save() } }
                        .buttonStyle(.brandPrimary).disabled(!valid || saving || store.hasConflict)
                        .accessibilityIdentifier("medicationSave")
                    if schedule != nil {
                        Button("Archive item", role: .destructive) { confirmArchive = true }
                            .font(Theme.Fonts.body(16, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                }.padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.Colors.ground).foregroundStyle(Theme.Colors.textPrimary).tint(Theme.Colors.primary)
            .navigationTitle(schedule == nil ? "Add item" : "Edit item").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("medicationKeyboardDone")
                }
            }
            .interactiveDismissDisabled(saving)
            .onAppear {
                if let schedule {
                    routineID = schedule.routineID; name = schedule.name; amount = schedule.amount
                    weekdays = schedule.weekdays; everyDay = weekdays.count == 7; times = schedule.times
                    remind = MedicationNotificationScheduler.shared.reminderEnabled(routineID, owner: store.accountID)
                }
            }
            .confirmationDialog("Archive this item?", isPresented: $confirmArchive, titleVisibility: .visible) {
                Button("Archive item", role: .destructive) {
                    do { try store.archive(routineID); dismiss() } catch { self.error = error.localizedDescription }
                }
            } message: { Text("Future doses and reminders stop. Your history stays saved.") }
        }
    }
    private func save() async {
        guard let owner = store.accountID else { return }
        saving = true; defer { saving = false }
        if remind { _ = await NotificationManager.shared.requestPermissionIfNeeded() }
        guard store.accountID == owner else { error = MedicationError.unavailable.localizedDescription; return }
        do {
            // New routines use the editor's stable ID so device reminder preferences match.
            let id: UUID
            if let schedule { id = schedule.routineID }
            else { id = routineID }
            try store.saveRoutine(routineID: schedule == nil ? nil : id, name: name, amount: amount,
                weekdays: weekdays, times: times, applyToday: applyToday)
            let savedID = schedule == nil ? store.document.schedules.last!.routineID : id
            MedicationNotificationScheduler.shared.setReminder(remind, routine: savedID, owner: owner)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

@MainActor
struct MedicationTodaySection: View {
    var date: Date
    var store: MedicationStore = .shared
    var onManage: () -> Void
    var onHistory: () -> Void
    @State private var expanded = false
    @State private var error: String?
    private var doses: [MedicationOccurrence] { store.occurrences(on: date) }
    private var complete: Bool { !doses.isEmpty && doses.allSatisfy { $0.status != .notLogged } }
    private var taken: Int { doses.filter { $0.status == .taken }.count }
    private var skipped: Int { doses.filter { $0.status == .skipped }.count }
    private var summary: String {
        if complete {
            return skipped == 0 ? (date.isToday ? "All taken today" : "All doses taken")
                : "\(date.isToday ? "Today" : "Day") complete · \(taken) taken, \(skipped) skipped"
        }
        return "\(taken) of \(doses.count) taken"
    }
    var body: some View {
        content
            .onChange(of: date) { _, _ in expanded = false; error = nil }
            .onChange(of: complete) { _, done in if done { expanded = false } }
    }
    @ViewBuilder private var content: some View {
        if store.enabled && !store.document.schedules.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text("Medications & supplements").font(Theme.Fonts.display(22, .bold)).accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Button("Manage", action: onManage).font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44)
                }
                MedicationStoreStatusView(store: store)
                if doses.isEmpty {
                    Text("Nothing scheduled this day").font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    if complete {
                        Button { expanded.toggle() } label: {
                            HStack {
                                Label(summary, systemImage: skipped == 0 ? "checkmark.circle.fill" : "checkmark.circle")
                                Spacer(); Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            }.font(Theme.Fonts.body(16, .semibold)).frame(minHeight: 44)
                        }.accessibilityHint("Review or correct your doses")
                    } else {
                        Text(summary).font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if !complete || expanded {
                        ForEach(["Morning", "Afternoon", "Evening"], id: \.self) { group in
                            let rows = doses.filter { $0.group == group }
                            if !rows.isEmpty {
                                Text(group.uppercased()).font(Theme.Typography.eyebrow).tracking(1).foregroundStyle(Theme.Colors.primaryText)
                                ForEach(rows) { dose in
                                    MedicationDoseRow(dose: dose, historical: !date.isToday, disabled: store.hasConflict,
                                        taken: { record(dose, .taken) }, skip: { record(dose, .skipped) },
                                        undo: { record(dose, .notLogged) }, edit: onHistory)
                                    if dose.id != rows.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }
                if let error { MedicationErrorText(message: error) }
                Button("View history", action: onHistory).font(Theme.Fonts.body(15, .semibold)).frame(minHeight: 44)
            }.foregroundStyle(Theme.Colors.textPrimary).tint(Theme.Colors.primary).tile(padding: 16)
                .accessibilityIdentifier("medicationsToday")
        }
    }
    private func record(_ dose: MedicationOccurrence, _ status: MedicationDoseStatus) {
        do { try store.record(dose, status: status); error = nil } catch { self.error = error.localizedDescription }
    }
}

@MainActor
private struct MedicationDoseRow: View {
    var dose: MedicationOccurrence
    var historical: Bool
    var disabled: Bool
    var taken: () -> Void
    var skip: () -> Void
    var undo: () -> Void
    var edit: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                if dose.status != .notLogged {
                    Image(systemName: dose.status == .taken ? "checkmark.circle.fill" : "minus.circle")
                        .foregroundStyle(dose.status == .taken ? Theme.Colors.limeLine : Theme.Colors.textSecondary)
                        .font(.system(size: 24)).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(dose.name).font(Theme.Fonts.body(18, .bold))
                    Text([dose.amount, dose.scheduledAt.formatted(date: .omitted, time: .shortened)].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    if dose.status != .notLogged {
                        Text(dose.status == .taken ? "Taken at \((dose.takenAt ?? dose.scheduledAt).formatted(date: .omitted, time: .shortened))" : "Skipped")
                            .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize { actions }
            }
            if typeSize.isAccessibilitySize { actions }
        }.padding(.vertical, 6)
    }
    @ViewBuilder private var actions: some View {
        if historical {
            Button("Review", action: edit).frame(minHeight: 44)
        } else if dose.status == .notLogged {
            HStack(spacing: 8) {
                Button("Taken", action: taken).font(Theme.Fonts.body(15, .semibold))
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(Theme.Colors.primary, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                    .accessibilityLabel("Mark \(dose.name) taken, \(dose.scheduledAt.formatted(date: .omitted, time: .shortened))")
                Button("Skip", action: skip).frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Skip \(dose.name), \(dose.scheduledAt.formatted(date: .omitted, time: .shortened))")
            }.disabled(disabled)
        } else { Button("Undo", action: undo).frame(minHeight: 44).disabled(disabled).accessibilityLabel("Undo \(dose.name) \(dose.status.title)") }
    }
}

@MainActor
struct MedicationHistoryView: View {
    var store: MedicationStore = .shared
    var initialDate: Date = .now
    var showsDone = false
    var focusedDoseID: String?
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var editing: MedicationOccurrence?
    private var doses: [MedicationOccurrence] { store.occurrences(on: date) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DaylightPageTitle("History", subtitle: "Your doses, day by day.")
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .font(Theme.Fonts.body(16)).tile(padding: 16)
                MedicationStoreStatusView(store: store)
                Text(date.formatted(date: .complete, time: .omitted)).font(Theme.Fonts.display(24, .bold))
                if doses.isEmpty {
                    Text("Nothing scheduled or logged this day. Tracking may have been off.")
                        .font(Theme.Fonts.body(16)).foregroundStyle(Theme.Colors.textSecondary).tile(padding: 16)
                } else {
                    Text("\(doses.filter { $0.status == .taken }.count) taken · \(doses.filter { $0.status == .skipped }.count) skipped · \(doses.filter { $0.status == .notLogged }.count) not logged")
                        .font(Theme.Fonts.body(15)).foregroundStyle(Theme.Colors.textSecondary)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(["Morning", "Afternoon", "Evening"], id: \.self) { group in
                            let rows = doses.filter { $0.group == group }
                            if !rows.isEmpty {
                                Text(group.uppercased()).font(Theme.Typography.eyebrow).tracking(1).foregroundStyle(Theme.Colors.primaryText)
                                ForEach(rows) { dose in
                                    Button { editing = dose } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: dose.status == .taken ? "checkmark.circle.fill" : (dose.status == .skipped ? "minus.circle" : "circle"))
                                                .foregroundStyle(dose.status == .taken ? Theme.Colors.limeLine : Theme.Colors.textSecondary)
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(dose.name).font(Theme.Fonts.body(18, .bold)).foregroundStyle(Theme.Colors.textPrimary)
                                                if dose.id == focusedDoseID {
                                                    Text("From your reminder").font(Theme.Fonts.body(13, .semibold)).foregroundStyle(Theme.Colors.primaryText)
                                                }
                                                Text([dose.amount, "Scheduled \(dose.scheduledAt.formatted(date: .omitted, time: .shortened))"].filter { !$0.isEmpty }.joined(separator: " · "))
                                                Text(dose.status == .taken ? "Taken · \((dose.takenAt ?? dose.scheduledAt).formatted(date: .omitted, time: .shortened))" : dose.status.title)
                                            }.font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                                            Spacer(minLength: 4)
                                            Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.primaryText)
                                        }.frame(minHeight: 44).padding(.vertical, 8)
                                    }.buttonStyle(.plain).disabled(store.hasConflict)
                                        .accessibilityHint("Correct status or taken time")
                                    if dose.id != rows.last?.id { Divider() }
                                }
                            }
                        }
                    }.tile(padding: 16)
                }
                Text("Tap an entry to correct its status or taken time.").font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            }.padding(20)
        }
        .background(Theme.Colors.ground).foregroundStyle(Theme.Colors.textPrimary).tint(Theme.Colors.primary)
        .daylightSubpage("History")
        .toolbar { if showsDone { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } }
        .onAppear { date = min(initialDate, .now) }
        .sheet(item: $editing) { MedicationCorrectionView(store: store, dose: $0) }
    }
}

@MainActor
private struct MedicationCorrectionView: View {
    var store: MedicationStore
    var dose: MedicationOccurrence
    @Environment(\.dismiss) private var dismiss
    @State private var status: MedicationDoseStatus = .taken
    @State private var takenAt = Date.now
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(dose.name).font(Theme.Fonts.body(20, .bold))
                    if !dose.amount.isEmpty { Text(dose.amount) }
                    Text("Scheduled \(dose.scheduledAt.formatted(date: .abbreviated, time: .shortened))")
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(MedicationDoseStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("medicationCorrectionStatus")
                    if status == .taken { DatePicker("Taken at", selection: $takenAt, in: ...Date.now) }
                    if let recorded = dose.recordedAt {
                        Text("Last recorded \(recorded.formatted(date: .abbreviated, time: .shortened))")
                            .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                if let error { MedicationErrorText(message: error) }
                Button("Save changes") {
                    do {
                        try store.record(dose, status: status, takenAt: status == .taken ? takenAt : nil, source: "history")
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }.disabled(store.hasConflict)
            }.font(Theme.Fonts.body(16)).tint(Theme.Colors.primary)
                .navigationTitle("Correct entry").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onAppear { status = dose.status == .notLogged ? .taken : dose.status; takenAt = dose.takenAt ?? min(dose.scheduledAt, .now) }
        }
    }
}

@MainActor
private struct MedicationStoreStatusView: View {
    var store: MedicationStore
    @State private var reviewConflict = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.isSyncing { ProgressView("Syncing medications…").font(Theme.Fonts.body(14)) }
            if store.storageFailed {
                MedicationErrorText(message: "Couldn’t open medication data on this phone. Close and reopen Footing to try again. Your saved file hasn’t been replaced.")
            } else if store.hasConflict {
                Text("Medications changed on another device. This phone’s changes are still saved here.").font(Theme.Fonts.body(14))
                Button("Review sync conflict") { reviewConflict = true }.frame(minHeight: 44)
            } else if store.pendingCount > 0 || store.syncFailed {
                Text(store.pendingCount > 0 ? "Saved on this phone · Waiting to sync" : "Couldn’t refresh medications")
                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
                Button("Retry sync") { Task { await store.sync(refresh: true); SyncEngine.shared.refreshPendingCount() } }.frame(minHeight: 44)
            }
        }
        .sheet(isPresented: $reviewConflict) { MedicationConflictReviewView(store: store) }
    }
}

@MainActor
private struct MedicationConflictReviewView: View {
    var store: MedicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var useThisPhone = false
    @State private var confirm = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Review both versions before choosing. Your changes remain saved on this phone until you choose.")
                        .font(Theme.Fonts.body(16))
                    snapshot(store.document, title: "This phone")
                    if let remote = store.cache.conflict { snapshot(remote.document, title: "Synced version") }
                    if let error { MedicationErrorText(message: error) }
                    Button("Use synced version") { useThisPhone = false; confirm = true }.buttonStyle(.brandPrimary)
                    Button("Use this phone’s version") { useThisPhone = true; confirm = true }
                        .font(Theme.Fonts.body(16, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }.padding(20)
            }.background(Theme.Colors.ground).foregroundStyle(Theme.Colors.textPrimary).tint(Theme.Colors.primary)
                .navigationTitle("Review sync conflict").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Decide later") { dismiss() } } }
                .confirmationDialog("Replace the other version?", isPresented: $confirm, titleVisibility: .visible) {
                    Button(useThisPhone ? "Keep this phone’s version" : "Keep synced version", role: .destructive) {
                        do { try store.resolveConflict(useThisPhone: useThisPhone); SyncEngine.shared.refreshPendingCount(); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                } message: {
                    Text("The selected version replaces the other version’s routines, tracking setting, and dose history. Changes that only exist in the other version will be lost.")
                }
        }
    }
    private func snapshot(_ doc: MedicationDocument, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.Fonts.display(22, .bold))
            Text(doc.enabled ? "Shown on Today" : "Tracking off").font(Theme.Fonts.body(15, .semibold))
            ForEach(doc.currentSchedules(at: .now)) { item in
                Text("\(item.name)\(item.amount.isEmpty ? "" : " · \(item.amount)") · \(medicationDaysSummary(item.weekdays))")
                    .font(Theme.Fonts.body(15))
                Text(item.times.map { $0.date.formatted(date: .omitted, time: .shortened) }.joined(separator: " · "))
                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            }
            Divider()
            Text("Recorded doses").font(Theme.Fonts.body(16, .semibold))
            if doc.doses.isEmpty { Text("No entries").font(Theme.Fonts.body(14)) }
            ForEach(doc.doses.values.sorted { $0.scheduledAt > $1.scheduledAt }) { dose in
                Text("\(dose.name) · \(dose.scheduledAt.formatted(date: .abbreviated, time: .shortened)) · \(dose.status.title)\(dose.takenAt.map { " at " + $0.formatted(date: .abbreviated, time: .shortened) } ?? "")")
                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).tile(padding: 16)
    }
}

@MainActor
private struct MedicationReminderStatusView: View {
    private var scheduler: MedicationNotificationScheduler { .shared }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if scheduler.permissionDenied {
                Text("Notifications are off for Footing. You can still log doses on Today.").font(Theme.Fonts.body(14))
                Button("Open notification settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }.frame(minHeight: 44)
            }
            if scheduler.schedulingFailed { MedicationErrorText(message: "Some reminders couldn’t be scheduled. Reopen this screen to retry.") }
            if scheduler.capacityConstrained && scheduler.scheduledThrough == nil {
                Text("Your phone’s reminder queue is full. Open Footing again to retry scheduling medication reminders.")
                    .font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.textSecondary)
            }
            if let through = scheduler.scheduledThrough {
                Text("Reminders scheduled through \(through.formatted(date: .abbreviated, time: .shortened)). Open Footing regularly to keep reminders scheduled.")
                    .font(Theme.Fonts.body(13)).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}

private struct MedicationErrorText: View {
    var message: String
    var body: some View { Text(message).font(Theme.Fonts.body(14)).foregroundStyle(Theme.Colors.danger).accessibilityAddTraits(.updatesFrequently) }
}

private func medicationDaysSummary(_ days: Set<Int>) -> String {
    if days.count == 7 { return "Every day" }
    return days.sorted().map { MedicationCalendar.calendar.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
}
