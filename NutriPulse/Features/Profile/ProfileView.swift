import SwiftUI
import UIKit

struct ProfileView: View {
    @State private var vm = ProfileViewModel()
    @Environment(AppState.self) private var appState
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    @AppStorage("chatHistoryVersion") private var chatHistoryVersion = 0
    @State private var showClearHistoryConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showGLP1Tracker = false
    @State private var isSeedingHealth = false

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                bodyStatsSection
                measurementsSection
                goalsSection
                glp1Section
                healthKitSection
                coachSection
                feedbackSection
                #if DEBUG
                debugSection
                #endif
                signOutSection
                deleteAccountSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.ground.ignoresSafeArea())
            .listRowBackground(Theme.Colors.surfaceCard)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.Colors.ground, for: .navigationBar)
            .task {
                await vm.loadData(profile: appState.profile)
            }
            .sheet(isPresented: $vm.showEditProfile, onDismiss: {
                Task { await appState.fetchProfile() }
            }) {
                EditProfileSheet(vm: vm)
            }
            .sheet(isPresented: $vm.showEditGoals) {
                EditGoalsSheet(vm: vm)
            }
            .sheet(isPresented: $vm.showLogInjection) {
                LogInjectionSheet(vm: vm)
            }
            .sheet(isPresented: $showGLP1Tracker) {
                GLP1TrackerView()
            }
            .alert("Notifications are off", isPresented: $vm.showReminderDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Not now", role: .cancel) { }
            } message: {
                Text("Turn on notifications for NutriPulse in Settings to get shot-day reminders.")
            }
            .sheet(isPresented: $vm.showSendFeedback) {
                SendFeedbackSheet(vm: vm)
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

    private var headerSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryGradient)
                        .frame(width: 68, height: 68)
                        .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 10, y: 4)
                    Text(initials)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.profile?.fullName ?? "Your Name")
                        .font(.system(size: 22, weight: .bold))
                    Text(vm.profile?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let identity = identityLine {
                        Text(identity)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Colors.primary)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    // One-line identity — the medication and activity that define this user's plan.
    private var identityLine: String? {
        var parts: [String] = []
        if let med = vm.mostRecentInjection?.medication { parts.append("On \(med)") }
        if let raw = vm.profile?.activityLevel, let level = ActivityLevel(rawValue: raw) {
            parts.append(level.displayName)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    #if DEBUG
    // Dev-only: seed ~2 weeks of demo Apple Health data on this device/sim so the health signals
    // show in demos. Never compiled into release builds.
    private var debugSection: some View {
        Section("Developer") {
            Button {
                Task {
                    isSeedingHealth = true
                    await HealthKitManager.shared.seedDemoHealthData()
                    isSeedingHealth = false
                }
            } label: {
                HStack {
                    Label("Seed demo Health data", systemImage: "heart.text.square")
                        .foregroundStyle(Theme.Colors.primary)
                    Spacer()
                    if isSeedingHealth { ProgressView() }
                }
            }
            .disabled(isSeedingHealth)
        }
    }
    #endif

    private var initials: String {
        (vm.profile?.fullName ?? "?")
            .components(separatedBy: " ")
            .compactMap { $0.first.map(String.init) }
            .joined()
            .prefix(2)
            .uppercased()
    }

    // MARK: - Body Stats

    private var bodyStatsSection: some View {
        Section("Body Stats") {
            if let w = vm.latestWeight {
                row(label: "Weight", value: units.formatWeight(w.weightKg))
            }
            if let h = vm.profile?.heightCm {
                row(label: "Height", value: units.formatHeight(h))
            }
            if let dob = vm.profile?.dob, let age = ageFrom(dob) {
                row(label: "Age", value: "\(age) years")
            }
            if let act = vm.profile?.activityLevel,
               let level = ActivityLevel(rawValue: act) {
                row(label: "Activity", value: level.displayName)
            }
            Button("Edit Stats") { vm.showEditProfile = true }
                .foregroundStyle(Theme.Colors.primary)
        }
    }

    // MARK: - Measurements

    // One global setting for every unit in the app, with a footer that says what it touches.
    private var measurementsSection: some View {
        Section {
            Picker("Units", selection: $unitSystemRaw) {
                Text("Metric (kg, cm, ml)").tag("metric")
                Text("Imperial (lb, in, oz)").tag("imperial")
            }
        } header: {
            Text("Measurements")
        } footer: {
            Text("Sets the units used everywhere in NutriPulse — weight, height, body composition, and water.")
        }
    }

    // MARK: - Goals

    private var goalsSection: some View {
        Section("Daily Goals") {
            if let g = vm.goal {
                row(label: "Calories", value: "\(Int(g.calories)) kcal")
                row(label: "Protein",  value: "\(Int(g.proteinG))g")
                row(label: "Carbs",    value: "\(Int(g.carbsG))g")
                row(label: "Fat",      value: "\(Int(g.fatG))g")
                row(label: "Fiber",    value: "\(Int(g.fiberG))g")
            }
            Button("Edit Goals") { vm.showEditGoals = true }
                .foregroundStyle(Theme.Colors.primary)
        }
    }

    // MARK: - GLP-1

    private var glp1Section: some View {
        Section("GLP-1 Tracker") {
            if glp1Logs.isEmpty {
                Button {
                    vm.showLogInjection = true
                } label: {
                    Label("Set Up GLP-1 Tracker", systemImage: "syringe")
                        .foregroundStyle(Theme.Colors.primary)
                }
            } else {
                Button {
                    showGLP1Tracker = true
                } label: {
                    Label("Protein floor & today", systemImage: "shield.lefthalf.filled")
                        .foregroundStyle(Theme.Colors.primary)
                }

                if let last = vm.mostRecentInjection {
                    row(label: "Medication",
                        value: "\(last.medication) \(last.doseMg.formatted())mg")
                }

                if let countdown = vm.nextInjectionCountdown,
                   let due = vm.nextInjectionDue {
                    HStack {
                        Label("Next injection", systemImage: "calendar")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(countdown)
                                .foregroundStyle(vm.isInjectionOverdue ? .red : .secondary)
                                .fontWeight(vm.isInjectionOverdue ? .semibold : .regular)
                            Text(due, style: .date)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Toggle(isOn: Binding(
                    get: { vm.remindersOn },
                    set: { newValue in Task { await vm.setReminders(newValue) } }
                )) {
                    Label("Shot-day reminders", systemImage: "bell.badge")
                }

                Button {
                    vm.showLogInjection = true
                } label: {
                    Label("Log Injection", systemImage: "syringe")
                        .foregroundStyle(Theme.Colors.primary)
                }

                if !glp1Logs.isEmpty {
                    ForEach(glp1Logs.prefix(3)) { log in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.injectedAt, style: .date)
                                .font(.subheadline)
                            Text(log.site.map { "\(log.doseMg.glp1DoseString)mg · \($0)" }
                                 ?? "\(log.doseMg.glp1DoseString)mg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    NavigationLink {
                        GLP1HistoryView()
                    } label: {
                        Text("See All Injections")
                            .foregroundStyle(Theme.Colors.primary)
                    }
                }
            }
        }
    }

    private var glp1Logs: [GLP1Log] { vm.glp1Logs }

    // MARK: - HealthKit

    private var healthKitSection: some View {
        Section("Apple Health") {
            if HealthKitManager.shared.isAvailable {
                HStack {
                    // isAvailable is a device capability — true on every iPhone. Reporting
                    // it as "Connected" told users who had denied every permission that
                    // Health was hooked up. Read grants are never disclosed by HealthKit,
                    // so the honest states are "we've been granted something we can verify"
                    // and "we haven't".
                    if HealthKitManager.shared.isSharingAuthorized {
                        Label("Connected", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                    } else if HealthKitManager.shared.hasRequestedAuthorization {
                        Label("Access not granted", systemImage: "heart.slash")
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Not connected", systemImage: "heart.slash")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Health permissions live in the Health app, not this app's Settings page.
                    Button("Health App") {
                        if let health = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(health) {
                            UIApplication.shared.open(health)
                        } else if let settings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settings)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            } else {
                Label("Not available on this device", systemImage: "heart.slash")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Coach

    private var coachSection: some View {
        Section("Pulse Coach") {
            Button("Clear Chat History", role: .destructive) {
                showClearHistoryConfirm = true
            }
        }
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        Section("Support") {
            Button {
                vm.showSendFeedback = true
            } label: {
                Label("Send Feedback", systemImage: "envelope")
                    .foregroundStyle(Theme.Colors.primary)
            }
            Link(destination: Config.privacyPolicyURL) {
                Label("Privacy Policy", systemImage: "hand.raised")
                    .foregroundStyle(Theme.Colors.primary)
            }
            Link(destination: Config.termsOfUseURL) {
                Label("Terms of Use", systemImage: "doc.text")
                    .foregroundStyle(Theme.Colors.primary)
            }
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Section {
            Button("Sign Out", role: .destructive) {
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
        }
    }

    // MARK: - Delete Account

    private var deleteAccountSection: some View {
        Section {
            Button("Delete Account", role: .destructive) {
                showDeleteAccountConfirm = true
            }
            .disabled(vm.isDeletingAccount)
        }
    }

    // MARK: - Helpers

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func ageFrom(_ dob: String) -> Int? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: dob) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: .now).year
    }
}

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
                Section("Account") {
                    TextField("Full name", text: $name)
                }
                Section("Body") {
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
                            Text("ft").foregroundStyle(.secondary)
                            TextField("in", text: $heightInchesText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .focused($fieldFocused)
                                .frame(width: 36)
                            Text("in").foregroundStyle(.secondary)
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
                            Text("cm").foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Activity Level") {
                    Picker("Activity", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Weight") {
                    Toggle("Log today's weight", isOn: $logWeight)
                    if logWeight {
                        HStack {
                            TextField(units.weightUnit, text: $weightText)
                                .keyboardType(.decimalPad)
                                .focused($fieldFocused)
                            Text(units.weightUnit).foregroundStyle(.secondary)
                        }
                    }
                }
            }
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
                            carbsG: goals.carbsG, fatG: goals.fatG, fiberG: goals.fiberG
                        )
                        dismiss()
                    }
                }
            } message: { suggestion in
                Text("Your new stats give \(Int(suggestion.goals.calories)) kcal a day (currently \(Int(suggestion.currentCalories))).")
            }
        }
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
            heightCm: oldHeightCm, weightKg: oldWeightKg, activity: oldActivity
        )
        let newTDEE = GoalCalculator.tdee(
            sex: sex, ageYears: GoalCalculator.ageYears(fromDOB: dob),
            heightCm: newHeightCm, weightKg: newWeightKg, activity: activity
        )

        let goals = GoalCalculator.retargeted(
            currentCalories: currentCalories,
            oldTDEE: oldTDEE,
            newTDEE: newTDEE,
            newWeightKg: newWeightKg
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
                Section("Calorie Target") {
                    goalRow(label: "Calories", value: $calories, unit: "kcal",
                            range: 1000...5000, step: 50)
                }
                Section("Macros") {
                    goalRow(label: "Protein", value: $proteinG, unit: "g",
                            range: 20...400, step: 5)
                    goalRow(label: "Carbs",   value: $carbsG,   unit: "g",
                            range: 20...600, step: 5)
                    goalRow(label: "Fat",     value: $fatG,     unit: "g",
                            range: 10...300, step: 5)
                    goalRow(label: "Fiber",   value: $fiberG,   unit: "g",
                            range: 5...100,  step: 1)
                }
            }
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
                .foregroundStyle(.secondary)
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
                Section("Medication") {
                    Picker("Medication", selection: $medication) {
                        ForEach(GLP1Medication.allCases) { med in
                            VStack(alignment: .leading) {
                                Text(med.rawValue)
                                Text(med.activeIngredient)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(med)
                        }
                    }
                    Picker("Dose", selection: $doseMg) {
                        ForEach(medication.availableDoses, id: \.self) { dose in
                            Text("\(dose.glp1DoseString) mg").tag(dose)
                        }
                    }
                }

                Section("Injection") {
                    DatePicker("Date & Time", selection: $injectionDate, in: ...Date.now)
                    Picker("Site", selection: $site) {
                        ForEach(InjectionSite.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                Section {
                    Label("Suggested next: \(vm.suggestedNextSite.rawValue)",
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log Injection")
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
