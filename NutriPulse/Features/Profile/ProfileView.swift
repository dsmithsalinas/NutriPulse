import SwiftUI
import UIKit

// Daylight rebuild (docs/daylight-redesign.md, mockup "Daylight — Profile"): an avatar/name
// header, an indigo "Daily targets" hero tile, a lime GLP-1 tile and a rose Apple Health tile
// side by side, then white settings tiles grouped with eyebrow labels instead of a grouped
// system List. Every setting, toggle, navigation link, destructive action and confirmation
// from the previous List-based screen is preserved — only the presentation changed.
struct ProfileView: View {
    @State private var vm = ProfileViewModel()
    @Environment(AppState.self) private var appState
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    @AppStorage("chatHistoryVersion") private var chatHistoryVersion = 0
    @State private var showClearHistoryConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showGLP1Tracker = false
    @State private var isSeedingHealth = false
    @State private var isReconnectingHealth = false
    @State private var showHealthPermissionsHelp = false
    @State private var showSmartNotificationExplainer = false
    @State private var showPulseOffConfirm = false
    @State private var showAIDataSharingInfo = false
    @State private var isSavingPulseSetting = false
    @Environment(\.scenePhase) private var scenePhase
    // The device-cached Pulse settings singleton (see PulseProfileStore). Read directly, like
    // HealthKitManager.shared above — Observation tracks the read regardless of how the
    // reference was obtained.
    private var pulseStore: PulseProfileStore { PulseProfileStore.shared }

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    #if DEBUG
    // Set only by `.preview()` below, to skip the network fetch and keep the fixture data
    // already loaded into `vm`. Never true outside a debug preview.
    private var skipInitialLoad = false

    init(debugFixture: Bool = DebugLaunch.tour) {
        if debugFixture {
            _vm = State(initialValue: Self.fixtureViewModel())
        }
        skipInitialLoad = debugFixture
    }
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.tileGap) {
                    header
                        .popIn(order: 0)

                    dailyTargetsTile
                        .popIn(order: 1)

                    HStack(spacing: Theme.Spacing.tileGap) {
                        glp1QuickTile
                        healthQuickTile
                    }
                    .popIn(order: 2)

                    pulseTile
                        .popIn(order: 3)

                    notificationsTile
                        .popIn(order: 3)

                    glp1DetailsTile
                        .popIn(order: 4)

                    healthKitDetailsTile
                        .popIn(order: 4)

                    bodyStatsTile
                        .popIn(order: 5)

                    measurementsTile
                        .popIn(order: 5)

                    supportTile
                        .popIn(order: 6)

                    #if DEBUG
                    debugTile
                    #endif

                    accountTile
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Colors.ground.ignoresSafeArea())
            // No navigation bar, so cover the status bar or scrolled tiles slide under the clock
            // (same as Pulse). A ShapeStyle background extends into the safe area.
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: 0)
                    .background(Theme.Colors.ground)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                #if DEBUG
                if skipInitialLoad { return }
                #endif
                await vm.loadData(profile: appState.profile)
            }
            .onReceive(NotificationCenter.default.publisher(for: .glp1DoseHistoryChanged)) { _ in
                Task { await vm.loadData(profile: appState.profile) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await vm.refreshRemindersState()
                    await vm.refreshSmartCoachingState()
                    await vm.refreshWeeklyReminderState()
                    await NotificationManager.shared.reconcileSmartNotificationHistory()
                }
            }
            .sheet(isPresented: $vm.showEditProfile, onDismiss: {
                Task { await appState.fetchProfile() }
            }) {
                EditProfileSheet(vm: vm)
            }
            .sheet(isPresented: $vm.showEditGoals) {
                EditGoalsSheet(vm: vm)
            }
            .confirmationDialog(
                "What's the aim right now?",
                isPresented: $vm.showRecalcAimDialog,
                titleVisibility: .visible
            ) {
                ForEach(WeightGoal.allCases) { aim in
                    Button(aim.displayName) { vm.prepareRecalc(for: aim) }
                }
            }
            .alert(
                "Use these targets?",
                isPresented: Binding(
                    get: { vm.pendingTargetRecalc != nil },
                    set: { if !$0 { vm.pendingTargetRecalc = nil } }
                ),
                presenting: vm.pendingTargetRecalc
            ) { pending in
                Button("Keep current", role: .cancel) { vm.pendingTargetRecalc = nil }
                Button("Update targets") {
                    Task { await vm.applyRecalc(pending) }
                }
            } message: { pending in
                Text("\(pending.weightGoal.displayName): \(Int(pending.goals.calories)) kcal, \(Int(pending.goals.proteinG))g protein a day (currently \(Int(pending.currentCalories)) kcal).")
            }
            .sheet(isPresented: $vm.showLogInjection) {
                LogInjectionSheet(vm: vm)
            }
            .sheet(isPresented: $showGLP1Tracker) {
                GLP1TrackerView()
            }
            .sheet(isPresented: $showSmartNotificationExplainer) {
                SmartNotificationExplainerSheet {
                    await vm.setSmartCoaching(true)
                }
            }
            .alert("Notifications are off", isPresented: $vm.showWeeklyReminderDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button("Not now", role: .cancel) { }
            } message: {
                Text("Turn on notifications for Footing in Settings to receive Your strong week on Mondays at 8 AM.")
            }
            .alert("Notifications are off", isPresented: $vm.showReminderDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Not now", role: .cancel) { }
            } message: {
                Text("Turn on notifications for Footing in Settings to get shot-day reminders.")
            }
            .alert("Notifications are off", isPresented: $vm.showSmartNotificationDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Not now", role: .cancel) { }
            } message: {
                Text("Turn on notifications for Footing in Settings to receive timely coaching opportunities.")
            }
            .sheet(isPresented: $vm.showSendFeedback) {
                SendFeedbackSheet(vm: vm)
            }
            .alert("Manage Apple Health access", isPresented: $showHealthPermissionsHelp) {
                Button("Open Health") { openHealthApp() }
                Button("Not now", role: .cancel) { }
            } message: {
                Text("Your permission choices are already saved on this iPhone. To change them, open Health → Summary → your profile picture → Apps and Services → Footing, then enable the categories you want to share.")
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .confirmationDialog(
                "Clear all Pulse chat history?",
                isPresented: $showClearHistoryConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    Task {
                        try? await CoachRepository().clearHistory()
                        chatHistoryVersion += 1
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently deletes all messages with Pulse.")
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteAccountConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task { await vm.deleteAccount() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently deletes your account and all your data — logs, goals, weight history, and chat history. This cannot be undone.")
            }
        }
        .tint(Theme.Colors.primary)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryGradient)
                    .frame(width: 60, height: 60)
                    .shadow(color: Theme.Colors.primary.opacity(0.35), radius: 8, y: 4)
                Text(initials)
                    .font(Theme.Fonts.display(22, .extraBold, relativeTo: .title2))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.profile?.fullName ?? "Your Name")
                    .font(Theme.Fonts.display(26, .extraBold, relativeTo: .title))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(identityLine ?? vm.profile?.email ?? " ")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.textSecondary)
                if identityLine != nil, let email = vm.profile?.email, !email.isEmpty {
                    Text(email)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textFaint)
                }
            }
            Spacer(minLength: 0)
            Button { vm.showEditProfile = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceCard, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Edit profile")
        }
    }

    // "Losing · moderately active" — the aim chosen at onboarding (or Recalculate Targets)
    // plus activity level, matching the Daylight mockup. Falls back to the email address
    // when neither is set yet (a profile that predates the weight_goal column).
    private var identityLine: String? {
        var parts: [String] = []
        if let raw = vm.profile?.weightGoal, let goal = WeightGoal(rawValue: raw) {
            parts.append(weightGoalProgressiveLabel(goal))
        }
        if let raw = vm.profile?.activityLevel, let level = ActivityLevel(rawValue: raw) {
            parts.append(level.displayName.lowercased())
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func weightGoalProgressiveLabel(_ goal: WeightGoal) -> String {
        switch goal {
        case .lose:     return "Losing"
        case .maintain: return "Maintaining"
        case .gain:     return "Gaining"
        }
    }

    private var initials: String {
        (vm.profile?.fullName ?? "?")
            .components(separatedBy: " ")
            .compactMap { $0.first.map(String.init) }
            .joined()
            .prefix(2)
            .uppercased()
    }

    // MARK: - Daily targets (hero tile)

    private var dailyTargetsTile: some View {
        VStack(alignment: .leading, spacing: 14) {
            TileEyebrow("Daily targets", color: Theme.Colors.heroLabel)

            if let g = vm.goal {
                HStack(spacing: 8) {
                    heroStat(value: "\(Int(g.proteinG))g", label: "protein floor")
                    heroStat(value: "\(Int(g.calories))", label: "calories")
                    heroStat(value: "\(Int(g.fiberG))g", label: "fiber")
                }
                Text("\(Int(g.carbsG))g carbs · \(Int(g.fatG))g fat")
                    .font(Theme.Fonts.body(13, .medium))
                    .foregroundStyle(Theme.Colors.heroSubtext)
            } else {
                Text("Set up your daily goals to see targets here.")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.heroSubtext)
            }

            HStack(spacing: 8) {
                Button("Edit goals") { vm.showEditGoals = true }
                    .buttonStyle(HeroFilledButtonStyle())
                Button("Recalculate") { vm.showRecalcAimDialog = true }
                    .buttonStyle(HeroOutlineButtonStyle())
            }
        }
        .tile(Theme.Colors.heroDeep, shadow: false)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Fonts.number(24))
                .foregroundStyle(.white)
            Text(label)
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Colors.heroLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Quick tiles (Shots / Apple Health)

    private var glp1Logs: [GLP1Log] { vm.glp1Logs }

    private var glp1QuickTile: some View {
        Button {
            if glp1Logs.isEmpty {
                vm.showLogInjection = true
            } else {
                showGLP1Tracker = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                TileEyebrow("Shots", color: Theme.Colors.limeLabel)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(glp1QuickTitle)
                        .font(Theme.Fonts.body(16, .bold))
                        .foregroundStyle(Theme.Colors.limeInk)
                        .lineLimit(1)
                    Text(glp1QuickSubtitle)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.limeLabel)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(Theme.Colors.lime, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityHint(glp1Logs.isEmpty ? "Set up GLP-1 tracking" : "Opens your GLP-1 tracker")
    }

    private var glp1QuickTitle: String {
        guard let last = vm.mostRecentInjection else { return "Set up tracking" }
        return "\(last.medication) \(last.doseMg.formatted())mg"
    }

    private var glp1QuickSubtitle: String {
        if glp1Logs.isEmpty { return "Track your weekly shot" }
        return vm.nextInjectionCountdown ?? "Dose history"
    }

    private var healthQuickTile: some View {
        Button {
            guard HealthKitManager.shared.isAvailable else { return }
            openHealthApp()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                TileEyebrow("Apple Health", color: Theme.Colors.healthTileLabel)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(healthQuickTitle)
                        .font(Theme.Fonts.body(16, .bold))
                        .foregroundStyle(Theme.Colors.healthTileInk)
                        .lineLimit(1)
                    Text("Weight, workouts, sleep")
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.healthTileLabel)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(Theme.Colors.healthTile, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .disabled(!HealthKitManager.shared.isAvailable)
        .accessibilityHint("Opens the Health app")
    }

    private var healthQuickTitle: String {
        guard HealthKitManager.shared.isAvailable else { return "Not available" }
        if HealthKitManager.shared.isSharingAuthorized { return "Connected" }
        if HealthKitManager.shared.hasRequestedAuthorization { return "Permissions requested" }
        return "Not connected"
    }

    // MARK: - Pulse notifications

    private var notificationsTile: some View {
        SettingsTile(
            eyebrow: "Pulse notifications",
            footer: "Smart coaching sends at most one timely suggestion a day. Your Monday outlook reminder and shot-day reminders are separate."
        ) {
            toggleRow(
                icon: "calendar.badge.clock",
                title: "Your strong week",
                subtitle: "Mondays at 8 AM · your local time",
                isOn: Binding(
                    get: { vm.weeklyReminderOn },
                    set: { enabled in Task { await vm.setWeeklyReminder(enabled) } }
                ),
                disabled: vm.weeklyReminderBusy
            )
            hairline
            toggleRow(
                icon: "bell.and.waves.left.and.right",
                title: "Smart coaching",
                subtitle: pulseStore.pulseEnabled ? "At most one nudge a day" : "Off while Pulse is off",
                isOn: Binding(
                    get: { vm.smartCoachingOn },
                    set: { value in
                        if value {
                            showSmartNotificationExplainer = true
                        } else {
                            Task { await vm.setSmartCoaching(false) }
                        }
                    }
                ),
                // These nudges come from Pulse, so with Pulse off they can't fire anyway.
                disabled: !pulseStore.pulseEnabled
            )
            if !glp1Logs.isEmpty {
                hairline
                toggleRow(
                    icon: "bell.badge",
                    title: "Shot-day reminders",
                    subtitle: "Day before and day of",
                    isOn: Binding(
                        get: { vm.remindersOn },
                        set: { newValue in Task { await vm.setReminders(newValue) } }
                    ),
                    disabled: !vm.doseScheduleLoaded
                )
            }
            hairline
            navRow(icon: "slider.horizontal.3", title: "Notification preferences", disabled: !vm.smartCoachingOn) {
                SmartNotificationSettingsView()
            }
            hairline
            navRow(icon: "clock.arrow.circlepath", title: "Pulse history") {
                SmartNotificationHistoryView()
            }
        }
    }

    // MARK: - GLP-1 tracker (details tile)

    private var glp1DetailsTile: some View {
        SettingsTile(eyebrow: "GLP-1 tracker") {
            if glp1Logs.isEmpty {
                actionRow(icon: "syringe", title: "Set Up GLP-1 Tracker") {
                    vm.showLogInjection = true
                }
            } else {
                actionRow(icon: "shield.lefthalf.filled", title: "Protein floor & today", showChevron: true) {
                    showGLP1Tracker = true
                }
                hairline

                if let last = vm.mostRecentInjection {
                    valueRow(icon: "pill", label: "Medication", value: "\(last.medication) \(last.doseMg.formatted())mg")
                    hairline
                }

                if let countdown = vm.nextInjectionCountdown, let due = vm.nextInjectionDue {
                    HStack(spacing: 12) {
                        iconBadge("calendar", tint: vm.isInjectionOverdue ? Theme.Colors.danger : Theme.Colors.primary)
                        Text(vm.doseSchedule.latestSkip == nil ? "Next dose" : "Next reminder")
                            .font(Theme.Fonts.body(15, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(countdown)
                                .font(Theme.Fonts.body(14, .semibold))
                                .foregroundStyle(vm.isInjectionOverdue ? Theme.Colors.danger : Theme.Colors.textSecondary)
                            Text(due, style: .date)
                                .font(Theme.Fonts.body(12))
                                .foregroundStyle(Theme.Colors.textFaint)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    hairline
                }

                if vm.doseScheduleLoaded, vm.nextInjectionDue != nil {
                    DoseSkipControl(schedule: vm.doseSchedule) { await vm.loadData(profile: appState.profile) }
                        .font(Theme.Fonts.body(13))
                        .tint(Theme.Colors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    hairline
                }

                actionRow(icon: "syringe", title: "Log Dose") {
                    vm.showLogInjection = true
                }

                if !glp1Logs.isEmpty {
                    hairline
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(glp1Logs.prefix(3)) { log in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.injectedAt, style: .date)
                                    .font(Theme.Fonts.body(14, .semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(log.site.map { "\(log.doseMg.glp1DoseString)mg · \($0)" }
                                     ?? "\(log.doseMg.glp1DoseString)mg")
                                    .font(Theme.Fonts.body(12))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                    }
                    hairline
                    navRow(icon: "list.bullet.rectangle", title: "Dose History") {
                        GLP1HistoryView()
                    }
                }
            }
        }
    }

    // MARK: - Apple Health (details tile)

    private var healthKitDetailsTile: some View {
        SettingsTile(eyebrow: "Apple Health") {
            if HealthKitManager.shared.isAvailable {
                HStack(spacing: 12) {
                    iconBadge(
                        HealthKitManager.shared.isSharingAuthorized ? "heart.fill" : "heart",
                        tint: HealthKitManager.shared.isSharingAuthorized ? Theme.Colors.healthTileInk : Theme.Colors.textSecondary
                    )
                    Text(healthQuickTitle)
                        .font(Theme.Fonts.body(15, .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer(minLength: 8)
                    Button("Health App") { openHealthApp() }
                        .font(Theme.Fonts.body(13, .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                hairline
                actionRow(
                    icon: "arrow.clockwise",
                    title: "Reconnect Apple Health",
                    isLoading: isReconnectingHealth
                ) {
                    guard !isReconnectingHealth else { return }
                    isReconnectingHealth = true
                    Task { await reconnectHealth() }
                }
                .disabled(isReconnectingHealth)
            } else {
                valueRow(icon: "heart.slash", label: "Not available on this device", value: "")
            }
        }
    }

    private func openHealthApp() {
        if let health = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(health) {
            UIApplication.shared.open(health)
        } else if let settings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settings)
        }
    }

    @MainActor
    private func reconnectHealth() async {
        defer { isReconnectingHealth = false }
        do {
            let didRequest = try await HealthKitManager.shared.reconnect()
            showHealthPermissionsHelp = !didRequest
        } catch {
            vm.errorMessage = "Could not request Apple Health access. \(error.localizedDescription)"
        }
    }

    // MARK: - Body stats

    private var bodyStatsTile: some View {
        SettingsTile(eyebrow: "Body stats") {
            if let w = vm.latestWeight {
                valueRow(icon: "scalemass", label: "Weight", value: units.formatWeight(w.weightKg))
                hairline
            }
            if let h = vm.profile?.heightCm {
                valueRow(icon: "ruler", label: "Height", value: units.formatHeight(h))
                hairline
            }
            if let dob = vm.profile?.dob, let age = ageFrom(dob) {
                valueRow(icon: "calendar", label: "Age", value: "\(age) years")
                hairline
            }
            if let act = vm.profile?.activityLevel, let level = ActivityLevel(rawValue: act) {
                valueRow(icon: "figure.run", label: "Activity", value: level.displayName)
                hairline
            }
            actionRow(icon: "pencil", title: "Edit Stats") {
                vm.showEditProfile = true
            }
        }
    }

    // MARK: - Measurements

    private var measurementsTile: some View {
        SettingsTile(
            eyebrow: "Measurements",
            footer: "Sets the units used everywhere in Footing — weight, height, body composition, and water."
        ) {
            Picker("Units", selection: $unitSystemRaw) {
                Text("Metric (kg, cm, ml)").tag("metric")
                Text("Imperial (lb, in, oz)").tag("imperial")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Pulse (on/off, on Today, what it knows, AI data sharing)

    private var pulseTile: some View {
        SettingsTile(
            eyebrow: "Pulse",
            footer: "Pulse is Footing's coach: a tab of its own, a nudge on Today, and the written Strong Week outlook. Turning it off stops all three; Talk to Log's food parsing is separate and keeps working."
        ) {
            toggleRow(
                // Not a heartbeat line: the design notes reserve Pulse's look for the Pulse mark.
                icon: "bubble.left.and.text.bubble.right",
                title: "Pulse",
                subtitle: pulseStore.pulseEnabled ? "On" : "Off",
                isOn: Binding(
                    get: { pulseStore.pulseEnabled },
                    set: { newValue in
                        if newValue {
                            Task { await savePulseSetting { try await pulseStore.setPulseEnabled(true) } }
                        } else {
                            showPulseOffConfirm = true
                        }
                    }
                ),
                disabled: isSavingPulseSetting
            )
            hairline
            toggleRow(
                icon: "sun.max",
                title: "Pulse on Today",
                subtitle: "Shows Pulse's nudge card on Today",
                isOn: Binding(
                    get: { pulseStore.pulseOnToday },
                    set: { newValue in
                        Task { await savePulseSetting { try await pulseStore.setPulseOnToday(newValue) } }
                    }
                ),
                disabled: isSavingPulseSetting || !pulseStore.pulseEnabled
            )
            hairline
            navRow(icon: "person.text.rectangle", title: "What Pulse knows") {
                AboutYouView()
            }
            hairline
            actionRow(icon: "hand.raised", title: "AI data sharing", showChevron: true) {
                showAIDataSharingInfo = true
            }
            hairline
            actionRow(icon: "trash", title: "Clear Chat History", tint: Theme.Colors.danger) {
                showClearHistoryConfirm = true
            }
        }
        .confirmationDialog(
            "Turn off Pulse?",
            isPresented: $showPulseOffConfirm,
            titleVisibility: .visible
        ) {
            Button("Turn Off Pulse", role: .destructive) {
                Task { await savePulseSetting { try await pulseStore.setPulseEnabled(false) } }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This turns off the Pulse tab, Pulse on Today, the written Strong Week outlook, and coaching notifications that come from Pulse. You can turn it back on any time.")
        }
        .sheet(isPresented: $showAIDataSharingInfo) {
            if pulseStore.aiConsentAt != nil {
                PulseConsentSheet()
            } else {
                PulseConsentSheet(onAgree: {
                    await savePulseSetting { try await pulseStore.recordConsent(agreed: true) }
                    showAIDataSharingInfo = false
                })
            }
        }
    }

    /// Optimistic saves already live in PulseProfileStore; this just surfaces a failure the
    /// same way every other Profile toggle does.
    private func savePulseSetting(_ save: () async throws -> Void) async {
        isSavingPulseSetting = true
        defer { isSavingPulseSetting = false }
        do {
            try await save()
        } catch {
            vm.errorMessage = "Couldn't update Pulse. Check your connection and try again."
        }
    }

    // MARK: - Support

    private var supportTile: some View {
        SettingsTile(
            eyebrow: "Support",
            footer: "Footing is a wellness tracker, not a medical device, and Pulse is not a medical professional. Nothing in the app is medical advice — always consult your doctor about medication and health decisions."
        ) {
            actionRow(icon: "envelope", title: "Send Feedback", showChevron: true) {
                vm.showSendFeedback = true
            }
            hairline
            linkRow(icon: "hand.raised", title: "Privacy Policy", url: Config.privacyPolicyURL)
            hairline
            linkRow(icon: "doc.text", title: "Terms of Use", url: Config.termsOfUseURL)
        }
    }

    // MARK: - Developer (DEBUG only)

    #if DEBUG
    // Dev-only: seed ~2 weeks of demo Apple Health data on this device/sim so the health signals
    // show in demos. Never compiled into release builds.
    private var debugTile: some View {
        SettingsTile(eyebrow: "Developer") {
            actionRow(icon: "heart.text.square", title: "Seed demo Health data", isLoading: isSeedingHealth) {
                Task {
                    isSeedingHealth = true
                    await HealthKitManager.shared.seedDemoHealthData()
                    isSeedingHealth = false
                }
            }
            .disabled(isSeedingHealth)
        }
    }
    #endif

    // MARK: - Account (sign out / delete)

    private var accountTile: some View {
        SettingsTile(eyebrow: "Account") {
            actionRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out", tint: Theme.Colors.danger) {
                // `try?` swallowed the failure: the user tapped Sign Out, nothing happened,
                // and nothing said why.
                Task {
                    do {
                        try await supabase.auth.signOut()
                    } catch {
                        vm.errorMessage = "Couldn't sign out. Check your connection and try again."
                    }
                }
            }
            hairline
            actionRow(icon: "trash", title: "Delete Account", tint: Theme.Colors.danger, isLoading: vm.isDeletingAccount) {
                showDeleteAccountConfirm = true
            }
            .disabled(vm.isDeletingAccount)
        }
    }

    // MARK: - Row helpers

    private func iconBadge(_ systemName: String, tint: Color = Theme.Colors.primary) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }

    private func toggleRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        disabled: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.Colors.primary)
                .disabled(disabled)
                .accessibilityLabel(title)
                .accessibilityHint(subtitle ?? "")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .opacity(disabled ? 0.55 : 1)
    }

    private func navRow<Destination: View>(
        icon: String,
        title: String,
        disabled: Bool = false,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                iconBadge(icon)
                Text(title)
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.textFaint)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }

    private func actionRow(
        icon: String,
        title: String,
        tint: Color = Theme.Colors.primary,
        showChevron: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBadge(icon, tint: tint)
                // Titles read as ordinary rows, like nav and link rows; only a non-default tint
                // (the destructive red) colors the title too.
                Text(title)
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(tint == Theme.Colors.primary ? Theme.Colors.textPrimary : tint)
                Spacer(minLength: 8)
                if isLoading {
                    ProgressView()
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textFaint)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func linkRow(icon: String, title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                iconBadge(icon)
                Text(title)
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Colors.textFaint)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func valueRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon, tint: Theme.Colors.textSecondary)
            Text(label)
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: 8)
            if !value.isEmpty {
                Text(value)
                    .font(Theme.Fonts.body(15, .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Theme.Colors.hairline)
            .frame(height: 1)
            .padding(.leading, 60)
    }

    // MARK: - Helpers

    private func ageFrom(_ dob: String) -> Int? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: dob) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: .now).year
    }
}

// MARK: - Tokens Theme doesn't have yet

// Theme has no destructive-red or Apple-Health-rose tokens; Profile is the only screen that
// needs them so they live here rather than in the shared DesignSystem.
private extension Theme.Colors {
    /// AA-compliant destructive red for the sign-out / delete-account / clear-history rows —
    /// #B91C1C on white contrasts ~5.9:1 (AA for normal text needs 4.5:1).
    static let danger = Color(light: 0xB91C1C, dark: 0xF87171)

    /// The Daylight mockup's rose family for the Apple Health tile.
    static let healthTile      = Color(hex: 0xFFE4E6)
    static let healthTileInk   = Color(hex: 0x881337)
    static let healthTileLabel = Color(hex: 0x9F1239)
}

// MARK: - Settings tile

/// A white Daylight tile with an uppercase eyebrow label and stacked rows — the replacement for
/// a grouped `Section` in the old system List. `footer`, if given, renders below the tile like a
/// section footer.
private struct SettingsTile<Content: View>: View {
    let eyebrow: String
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            VStack(alignment: .leading, spacing: 0) {
                TileEyebrow(eyebrow)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                content
                    .padding(.bottom, 6)
            }
            .background(Theme.Colors.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
            .shadow(color: Color(hex: 0x0F172A, opacity: 0.06), radius: 1, y: 1)

            if let footer {
                Text(footer)
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textFaint)
                    .padding(.horizontal, 6)
            }
        }
    }
}

// MARK: - Hero tile button styles

/// "Edit goals" on the indigo hero tile — a solid white pill with indigo text.
private struct HeroFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(14, .bold))
            .foregroundStyle(Theme.Colors.heroDeep)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// "Recalculate" on the indigo hero tile — an outlined pill, white text.
private struct HeroOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(14, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.Colors.primaryText, lineWidth: 1.5)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Debug preview fixture

#if DEBUG
extension ProfileView {
    /// Fixture data, no network calls — lets the lead engineer preview the Daylight Profile
    /// rebuild without a signed-in session. Not wired into RootView; call
    /// `ProfileView.preview()` from a debug menu item, a temporary RootView branch, or a
    /// SwiftUI `#Preview`.
    static func preview() -> some View {
        let appState = AppState()
        appState.profile = fixtureProfile
        return ProfileView(debugFixture: true)
            .environment(appState)
    }

    /// The tour's signed-in user (MainTabView puts it on AppState).
    static var tourProfile: UserProfile { fixtureProfile }

    private static let fixtureProfile = UserProfile(
        id: UUID(),
        email: "dustin@example.com",
        fullName: "Dustin Allen",
        dob: "1990-04-12",
        sex: "male",
        heightCm: 180,
        activityLevel: "moderate",
        weightGoal: "lose",
        dietaryPrefs: nil,
        createdAt: .now
    )

    private static func fixtureViewModel() -> ProfileViewModel {
        let vm = ProfileViewModel()
        let profile = fixtureProfile
        vm.profile = profile
        vm.goal = DailyGoal(
            id: UUID(), userId: profile.id, effectiveDate: Date.now.isoDateString,
            calories: 1850, proteinG: 140, carbsG: 180, fatG: 60, fiberG: 28, waterMlTarget: 2000
        )
        vm.latestWeight = WeightLog(id: UUID(), userId: profile.id, loggedAt: .now, weightKg: 84, source: "manual")
        vm.glp1Logs = [GLP1Log(
            id: UUID(), userId: profile.id,
            injectedAt: Date.now.addingTimeInterval(-2 * 86_400),
            medication: "Ozempic", doseMg: 0.5, site: "Left Abdomen",
            nextDueAt: Date.now.addingTimeInterval(5 * 86_400)
        )]
        vm.doseScheduleLoaded = true
        vm.remindersOn = true
        vm.weeklyReminderOn = true
        vm.smartCoachingOn = true
        return vm
    }
}
#endif

// MARK: - Edit Profile Sheet

private struct EditProfileSheet: View {
    @Bindable var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    @State private var name          = ""
    @State private var dob           = Date()
    @State private var sex           = BiologicalSex.male
    // String-backed, not `TextField(value:format:)`. A value-bound numeric field commits to
    // its binding only on submit or focus loss, and a number pad has no return key — so
    // tapping Save with the keyboard still up wrote the OLD height/weight into the profile,
    // HealthKit, and the BMR recalc. Binding plain strings and parsing on save (the
    // DecimalInput pattern used in BodyCompositionSheet / ManualEntryView) avoids the trap.
    @State private var heightCmText     = ""
    @State private var heightFeetText   = ""
    @State private var heightInchesText = ""
    @State private var activity         = ActivityLevel.moderate
    @State private var logWeight        = false
    @State private var weightText       = ""   // in user's preferred unit
    @FocusState private var fieldFocused: Bool
    @State private var isSaving      = false

    // Matches DobStepView: at least 13 (App Store minimum), at most 120.
    private static let dobRange: ClosedRange<Date> = {
        let cal = Calendar.current
        let oldest = cal.date(byAdding: .year, value: -120, to: .now) ?? .distantPast
        let youngest = cal.date(byAdding: .year, value: -13, to: .now) ?? .now
        return oldest...youngest
    }()

    @State private var pendingRecalc: RecalcSuggestion? = nil

    // Surfaced after saving stats that move the BMR. Never applied silently: the user may
    // have hand-tuned their targets in Edit Goals, and overwriting that without asking is
    // worse than letting the numbers drift.
    private struct RecalcSuggestion {
        let goals: CalculatedGoals
        let currentCalories: Double
    }

    private let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full name", text: $name)
                } header: {
                    DaylightSectionHeader("Account")
                }
                .daylightSection()

                Section {
                    // `...Date.now` let a user set their DOB to today — "Age: 0 years" in Body
                    // Stats, and a nonsense BMR. Onboarding enforces 13–120; match it.
                    DatePicker("Date of birth", selection: $dob,
                               in: Self.dobRange, displayedComponents: .date)
                    Picker("Sex", selection: $sex) {
                        ForEach(BiologicalSex.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    if units == .imperial {
                        HStack {
                            Text("Height")
                            Spacer()
                            TextField("ft", text: $heightFeetText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .focused($fieldFocused)
                                .frame(width: 36)
                            Text("ft").foregroundStyle(Theme.Colors.textSecondary)
                            TextField("in", text: $heightInchesText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .focused($fieldFocused)
                                .frame(width: 36)
                            Text("in").foregroundStyle(Theme.Colors.textSecondary)
                        }
                    } else {
                        HStack {
                            Text("Height")
                            Spacer()
                            TextField("cm", text: $heightCmText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .focused($fieldFocused)
                                .frame(width: 60)
                            Text("cm").foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                } header: {
                    DaylightSectionHeader("Body")
                }
                .daylightSection()

                Section {
                    Picker("Activity", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    DaylightSectionHeader("Activity Level")
                }
                .daylightSection()

                Section {
                    Toggle("Log today's weight", isOn: $logWeight)
                    if logWeight {
                        HStack {
                            TextField(units.weightUnit, text: $weightText)
                                .keyboardType(.decimalPad)
                                .focused($fieldFocused)
                            Text(units.weightUnit).foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                } header: {
                    DaylightSectionHeader("Weight")
                }
                .daylightSection()
            }
            .daylightForm()
            .navigationTitle("Edit Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
            .onAppear { prefill() }
            .alert(
                "Recalculate your targets?",
                isPresented: Binding(
                    get: { pendingRecalc != nil },
                    set: { if !$0 { pendingRecalc = nil } }
                ),
                presenting: pendingRecalc
            ) { suggestion in
                Button("Keep current", role: .cancel) {
                    pendingRecalc = nil
                    dismiss()
                }
                Button("Recalculate") {
                    let goals = suggestion.goals
                    pendingRecalc = nil
                    Task {
                        try? await vm.updateGoals(
                            calories: goals.calories, proteinG: goals.proteinG,
                            carbsG: goals.carbsG, fatG: goals.fatG, fiberG: goals.fiberG,
                            waterMlTarget: goals.waterMlTarget
                        )
                        dismiss()
                    }
                }
            } message: { suggestion in
                Text("Your new stats give \(Int(suggestion.goals.calories)) kcal a day (currently \(Int(suggestion.currentCalories))).")
            }
        }
        .tint(Theme.Colors.primary)
    }

    private func prefill() {
        name = vm.profile?.fullName ?? ""
        if let dobStr = vm.profile?.dob, let d = dobFormatter.date(from: dobStr) { dob = d }
        if let s = vm.profile?.sex { sex = BiologicalSex(rawValue: s) ?? .male }
        if let a = vm.profile?.activityLevel { activity = ActivityLevel(rawValue: a) ?? .moderate }

        let storedCm     = vm.profile?.heightCm ?? 170
        heightCmText     = DecimalInput.text(from: storedCm)
        heightFeetText   = DecimalInput.text(from: units.feetFrom(storedCm))
        heightInchesText = DecimalInput.text(from: units.inchesFrom(storedCm))

        let storedKg = vm.latestWeight?.weightKg ?? 70
        weightText   = DecimalInput.text(from: units.weightInput(from: storedKg))
    }

    private func parse(_ text: String) -> Double {
        DecimalInput.value(from: DecimalInput.sanitize(text.trimmingCharacters(in: .whitespaces)))
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // Pass the stored height so an untouched imperial field round-trips exactly
        // instead of being rewritten to the nearest whole inch. An empty field parses to 0;
        // fall back to the stored height rather than writing a nonsense 0 cm.
        let storedCm = vm.profile?.heightCm ?? 170
        let finalHeightCm: Double
        if units == .imperial {
            let feet = parse(heightFeetText)
            let inches = parse(heightInchesText)
            finalHeightCm = (feet <= 0 && inches <= 0)
                ? storedCm
                : units.cmFrom(feet: feet, inches: inches, unchangedFrom: storedCm)
        } else {
            let entered = parse(heightCmText)
            finalHeightCm = entered > 0 ? entered : storedCm
        }

        // Only actually log a weight when the toggle is on AND a real value was entered;
        // an empty field must not write 0 kg to weight_logs / HealthKit / the recalc.
        let enteredWeight = parse(weightText)
        let willLogWeight = logWeight && enteredWeight > 0
        let finalWeightKg = units.kgFrom(enteredWeight)

        // Snapshot the old stats before the update overwrites them.
        let oldProfile = vm.profile
        let oldWeightKg = vm.latestWeight?.weightKg

        let update = UpdateProfile(
            fullName: name.trimmingCharacters(in: .whitespaces),
            dob: dobFormatter.string(from: dob),
            sex: sex.rawValue,
            heightCm: finalHeightCm,
            activityLevel: activity.rawValue
        )
        do {
            try await vm.updateProfile(update)
            if willLogWeight { try await vm.logWeight(finalWeightKg) }

            if let suggestion = recalcSuggestion(
                oldProfile: oldProfile,
                oldWeightKg: oldWeightKg,
                newHeightCm: finalHeightCm,
                newWeightKg: willLogWeight ? finalWeightKg : oldWeightKg
            ) {
                pendingRecalc = suggestion   // the alert dismisses us
            } else {
                dismiss()
            }
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }

    // Stats that move BMR — weight, height, activity, sex, age — used to leave the calorie and
    // macro targets untouched, so a user who lost 20 lb kept eating for their old body.
    //
    // The suggestion preserves whatever adjustment they're currently living with (the deficit
    // chosen at onboarding, or a target hand-tuned in Edit Goals) rather than re-deriving from
    // a WeightGoal that `profiles` doesn't even store.
    private func recalcSuggestion(
        oldProfile: UserProfile?,
        oldWeightKg: Double?,
        newHeightCm: Double,
        newWeightKg: Double?
    ) -> RecalcSuggestion? {
        guard
            let currentCalories = vm.goal?.calories,
            let oldProfile,
            let oldSexRaw = oldProfile.sex, let oldSex = BiologicalSex(rawValue: oldSexRaw),
            let oldActivityRaw = oldProfile.activityLevel, let oldActivity = ActivityLevel(rawValue: oldActivityRaw),
            let oldHeightCm = oldProfile.heightCm,
            let oldDOBString = oldProfile.dob, let oldDOB = dobFormatter.date(from: oldDOBString),
            let oldWeightKg, let newWeightKg
        else { return nil }

        let oldTDEE = GoalCalculator.tdee(
            sex: oldSex, ageYears: GoalCalculator.ageYears(fromDOB: oldDOB),
            heightCm: oldHeightCm, weightKg: oldWeightKg, activity: oldActivity,
            bodyFatPct: vm.latestBodyFatPct
        )
        let newTDEE = GoalCalculator.tdee(
            sex: sex, ageYears: GoalCalculator.ageYears(fromDOB: dob),
            heightCm: newHeightCm, weightKg: newWeightKg, activity: activity,
            bodyFatPct: vm.latestBodyFatPct
        )

        let goals = GoalCalculator.retargeted(
            currentCalories: currentCalories,
            oldTDEE: oldTDEE,
            newTDEE: newTDEE,
            newWeightKg: newWeightKg,
            heightCm: newHeightCm,
            sex: sex
        )

        // Don't nag over rounding noise.
        guard abs(goals.calories - currentCalories) >= 25 else { return nil }
        return RecalcSuggestion(goals: goals, currentCalories: currentCalories)
    }
}

// MARK: - Edit Goals Sheet

private struct EditGoalsSheet: View {
    @Bindable var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var calories = 2000.0
    @State private var proteinG = 150.0
    @State private var carbsG   = 200.0
    @State private var fatG     = 65.0
    @State private var fiberG   = 25.0
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    goalRow(label: "Calories", value: $calories, unit: "kcal",
                            range: 1000...5000, step: 50)
                } header: {
                    DaylightSectionHeader("Calorie Target")
                }
                .daylightSection()

                Section {
                    goalRow(label: "Protein", value: $proteinG, unit: "g",
                            range: 20...400, step: 5)
                    goalRow(label: "Carbs",   value: $carbsG,   unit: "g",
                            range: 20...600, step: 5)
                    goalRow(label: "Fat",     value: $fatG,     unit: "g",
                            range: 10...300, step: 5)
                    goalRow(label: "Fiber",   value: $fiberG,   unit: "g",
                            range: 5...100,  step: 1)
                } header: {
                    DaylightSectionHeader("Macros")
                }
                .daylightSection()
            }
            .daylightForm()
            .navigationTitle("Edit Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
            .onAppear { prefill() }
        }
        .tint(Theme.Colors.primary)
    }

    private func prefill() {
        guard let g = vm.goal else { return }
        calories = g.calories
        proteinG = g.proteinG
        carbsG   = g.carbsG
        fatG     = g.fatG
        fiberG   = g.fiberG
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await vm.updateGoals(
                calories: calories, proteinG: proteinG,
                carbsG: carbsG, fatG: fatG, fiberG: fiberG
            )
            dismiss()
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }

    private func goalRow(label: String, value: Binding<Double>,
                         unit: String, range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(value.wrappedValue)) \(unit)")
                .foregroundStyle(Theme.Colors.textSecondary)
                .monospacedDigit()
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
    }
}

// MARK: - Log Injection Sheet

private struct LogInjectionSheet: View {
    @Bindable var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var medication     = GLP1Medication.ozempic
    @State private var doseMg         = 0.25
    @State private var injectionDate  = Date.now
    @State private var site           = InjectionSite.leftAbdomen
    @State private var isSaving       = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Medication", selection: $medication) {
                        ForEach(GLP1Medication.allCases) { med in
                            VStack(alignment: .leading) {
                                Text(med.rawValue)
                                Text(med.activeIngredient)
                                    .font(Theme.Fonts.body(12))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .tag(med)
                        }
                    }
                    Picker("Dose", selection: $doseMg) {
                        ForEach(medication.availableDoses, id: \.self) { dose in
                            Text("\(dose.glp1DoseString) mg").tag(dose)
                        }
                    }
                } header: {
                    DaylightSectionHeader("Medication")
                }
                .daylightSection()

                Section {
                    DatePicker("Date & Time", selection: $injectionDate, in: ...Date.now)
                    Picker("Site", selection: $site) {
                        ForEach(InjectionSite.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                } header: {
                    DaylightSectionHeader("Dose")
                }
                .daylightSection()

                Section {
                    Label("Suggested next: \(vm.suggestedNextSite.rawValue)",
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .daylightSection()
            }
            .daylightForm()
            .navigationTitle("Log Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
            .onChange(of: medication) { _, _ in
                if !medication.availableDoses.contains(doseMg) {
                    doseMg = medication.availableDoses.first ?? 0.25
                }
            }
            .onAppear { prefill() }
        }
        .tint(Theme.Colors.primary)
    }

    private func prefill() {
        if let last = vm.mostRecentInjection {
            medication = GLP1Medication(rawValue: last.medication) ?? .ozempic
            doseMg = last.doseMg
            if !medication.availableDoses.contains(doseMg) {
                doseMg = medication.availableDoses.first ?? 0.25
            }
        }
        site = vm.suggestedNextSite
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await vm.logInjection(
                medication: medication.rawValue,
                doseMg: doseMg,
                site: site.rawValue,
                date: injectionDate
            )
            dismiss()
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }
}

private struct SmartNotificationExplainerSheet: View {
    let onEnable: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabling = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SheetHeader(title: "Notifications", onClose: { if !isEnabling { dismiss() } })

                ZStack {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Useful timing, fewer interruptions")
                        .font(Theme.Fonts.display(22, .bold, relativeTo: .title2))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Pulse waits for a specific next step instead of reminding you on a fixed clock.")
                        .font(Theme.Fonts.body(16))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    explainerRow("figure.strengthtraining.traditional", "After a workout", "When a recovery gap still has a practical fix.")
                    explainerRow("fork.knife", "When the finish line is close", "A protein option or usual meal you can act on now.")
                    explainerRow("moon.zzz.fill", "Quiet by design", "At most one coaching notification a day, never from 9 PM–7 AM.")
                }

                Text("Shot-day reminders remain separate and keep their own setting.")
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Colors.textFaint)

                Button {
                    isEnabling = true
                    Task {
                        await onEnable()
                        dismiss()
                    }
                } label: {
                    HStack {
                        if isEnabling { ProgressView().tint(.white) }
                        Text("Allow useful notifications")
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.brandPrimary)
                .disabled(isEnabling)
            }
            .padding(Theme.Spacing.page)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.ground.ignoresSafeArea())
        .interactiveDismissDisabled(isEnabling)
        .presentationDragIndicator(.visible)
        .tint(Theme.Colors.primary)
    }

    private func explainerRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 28, height: 28)
                .background(Theme.Colors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Fonts.body(15, .semibold)).foregroundStyle(Theme.Colors.textPrimary)
                Text(detail).font(Theme.Fonts.body(12)).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
