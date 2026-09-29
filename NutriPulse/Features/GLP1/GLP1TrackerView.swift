import SwiftUI
import UIKit

// The GLP-1 screen the marketing promises, made real: dose status, a protein "floor" that
// protects muscle (not a ceiling to stay under), hydration, and schedule-aware coach guidance.
struct GLP1TrackerView: View {
    @State private var vm = GLP1ViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    @State private var showCheckIn = false

    private var isMetric: Bool { (UnitSystem(rawValue: unitSystemRaw) ?? .metric) == .metric }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    doseCard
                    if vm.doseScheduleLoaded, vm.nextDue != nil {
                        DoseSkipControl(schedule: vm.doseSchedule) { await vm.load() }
                            .padding(Theme.Spacing.md).card()
                    }
                    if let error = vm.scheduleError {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                        Button("Try again") { Task { await vm.load() } }
                    }
                    if let plan = vm.cyclePlan {
                        ShotCyclePlanCard(
                            plan: plan,
                            hasCheckIn: vm.todayCheckIn != nil,
                            onCheckIn: { showCheckIn = true }
                        )
                    }
                    proteinFloorCard
                    waterCard
                    coachCard
                }
                .padding(Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("GLP-1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.Colors.primary)
        .task { await vm.load() }
        .onReceive(NotificationCenter.default.publisher(for: .glp1DoseHistoryChanged)) { _ in
            Task { await vm.load() }
        }
        .sheet(isPresented: $showCheckIn) {
            ShotCycleCheckInSheet(
                cycleDay: max(vm.daysSinceShot ?? 0, 0),
                existing: vm.todayCheckIn,
                onSave: { draft in await vm.saveCheckIn(draft) }
            )
            .presentationDetents([.large])
        }
        .alert("Couldn't save check-in", isPresented: Binding(
            get: { vm.checkInError != nil },
            set: { if !$0 { vm.checkInError = nil } }
        )) {
            Button("OK") { vm.checkInError = nil }
        } message: {
            Text(vm.checkInError ?? "")
        }
    }

    // MARK: Dose card

    private var doseCard: some View {
        HStack(spacing: Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.Colors.primaryGradient)
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                if let log = vm.latest {
                    Text("\(log.medication) · \(log.doseMg.glp1DoseString) mg")
                        .font(.system(size: 16, weight: .bold))
                    if let next = vm.nextDoseText {
                        Text("\(vm.doseSchedule.latestSkip == nil ? "Next dose" : "Next reminder") · \(next)")
                            .font(.subheadline)
                            .foregroundStyle(vm.isOverdue ? .orange : .secondary)
                    }
                } else {
                    Text("No dose logged yet")
                        .font(.system(size: 16, weight: .bold))
                    Text("Log a dose in Profile → GLP-1 to start tracking")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Theme.Spacing.xs)

            if vm.latest != nil {
                reminderPill
            }
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    private var reminderPill: some View {
        Button {
            switch vm.reminderState {
            case .on:  vm.disableReminders()
            case .off: Task { await vm.enableReminders() }
            case .denied:
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } label: {
            HStack(spacing: 5) {
                if vm.isBusyReminders {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: reminderIcon)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(reminderLabel)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(reminderActive ? Theme.Colors.primary : Theme.Colors.textFaint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((reminderActive ? Theme.Colors.primary : Theme.Colors.textFaint).opacity(0.12))
            .clipShape(Capsule())
            .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(vm.isBusyReminders || !vm.doseScheduleLoaded)
    }

    private var reminderActive: Bool { vm.reminderState == .on }
    private var reminderIcon: String {
        switch vm.reminderState {
        case .on:     return "bell.fill"
        case .off:    return "bell.badge.plus"
        case .denied: return "bell.slash.fill"
        }
    }
    private var reminderLabel: String {
        switch vm.reminderState {
        case .on:     return "Reminders on"
        case .off:    return "Remind me"
        case .denied: return "Enable in Settings"
        }
    }

    // MARK: Protein floor — the hero of this screen

    private var proteinFloorCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Protein floor")
                    .font(.system(size: 15, weight: .bold))
                if let day = vm.daysSinceShot {
                    Text("· day \(day) after your shot")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textFaint)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("\(Int(vm.proteinToday.rounded())) / \(Int(vm.proteinGoal.rounded()))g")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    if vm.proteinCleared {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.NutrientColor.fiber)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.ringTrack)
                    Capsule()
                        .fill(Theme.Colors.primaryGradient)
                        .frame(width: max(geo.size.width * vm.proteinPct, vm.proteinPct > 0 ? 10 : 0))
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.proteinPct)
                }
            }
            .frame(height: 10)

            Text(vm.proteinCleared
                 ? "Floor cleared — muscle protected."
                 : "\(vm.proteinRemaining)g to go — clearing your floor protects your muscle while the medication does its part.")
                .font(.footnote)
                .foregroundStyle(vm.proteinCleared ? Theme.NutrientColor.fiber : Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    // MARK: Water

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill").foregroundStyle(Theme.NutrientColor.water)
                    Text("Water").font(.system(size: 15, weight: .bold))
                }
                Spacer()
                Text(waterLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.ringTrack)
                    Capsule()
                        .fill(Theme.NutrientColor.water)
                        .frame(width: max(geo.size.width * vm.waterPct, vm.waterPct > 0 ? 8 : 0))
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.waterPct)
                }
            }
            .frame(height: 10)
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    private var waterLabel: String {
        if isMetric {
            return "\(Int(vm.waterMl.rounded())) / \(Int(vm.waterGoalMl.rounded())) ml"
        }
        let oz = vm.waterMl / 29.5735
        let goalOz = vm.waterGoalMl / 29.5735
        return "\(Int(oz.rounded())) / \(Int(goalOz.rounded())) oz"
    }

    // MARK: Coach note

    private var coachCard: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            PulseMark()
                .foregroundStyle(.white)
                .padding(6)
                .frame(width: 34, height: 34)
                .background(Theme.Colors.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.coachNote)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    // Dismiss first, then hand off — switching the Pulse tab while this sheet is
                    // still up over the Today tab would strand the sheet and swallow the switch.
                    let prompt = vm.askPulsePrompt
                    dismiss()
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        appState.askPulse(prompt)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text("Ask Pulse about today")
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [Theme.Colors.primary.opacity(0.13), Theme.Colors.surfaceCard],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.Colors.primary.opacity(0.28), lineWidth: 1)
        }
    }
}

// Shared by Today and GLP-1. A single tap records the choice; Undo is always available.
struct DoseSkipControl: View {
    let schedule: GLP1DoseSchedule
    var onChange: () async -> Void
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let skip = schedule.skippedThisWeek {
                Text("Shot marked as skipped")
                    .font(.subheadline.weight(.semibold))
                Text("Planned for \(skip.scheduledAt.formatted(date: .abbreviated, time: .omitted)). Reminders for this dose are off.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Undo skip") { update(undo: skip) }
            } else if let due = schedule.nextDue {
                Button("Skip this week’s shot") { update(undo: nil) }
                Text("Applies to the dose planned for \(due.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let due = schedule.nextDue, schedule.skippedThisWeek != nil {
                Text("Next reminder date: \(due.formatted(date: .abbreviated, time: .omitted)). Your weekly reminder cadence stays the same.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if isSaving { ProgressView().controlSize(.small) }
        }
        .buttonStyle(.borderless)
        .disabled(isSaving)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("Couldn't update your shot", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func update(undo skip: GLP1SkippedDose?) {
        guard !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            let repo = GLP1Repository()
            do {
                var updated = schedule.skips
                if let skip {
                    try await repo.undoSkip(id: skip.id)
                    updated.removeAll { $0.id == skip.id }
                } else if let latest = schedule.latest, let due = schedule.nextDue {
                    let saved = try await repo.skipDose(injection: latest, scheduledAt: due)
                    updated.removeAll { $0.id == saved.id }
                    updated.append(saved)
                } else { return }
                // Reconcile immediately from the committed result, even if the next read fails.
                await NotificationManager.shared.reconcileGLP1Reminders(
                    schedule: .init(latest: schedule.latest, skips: updated)
                )
                await onChange()
                NotificationCenter.default.post(name: .glp1DoseHistoryChanged, object: nil)
            } catch {
                errorMessage = "Check your connection and try again. Your shot hasn't been marked as taken."
            }
        }
    }
}
