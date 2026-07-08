import SwiftUI

struct ProfileView: View {
    @State private var vm = ProfileViewModel()
    @Environment(AppState.self) private var appState
    @AppStorage("unitSystem") private var unitSystemRaw = "metric"
    @AppStorage("chatHistoryVersion") private var chatHistoryVersion = 0
    @State private var showClearHistoryConfirm = false
    @State private var showDeleteAccountConfirm = false

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                bodyStatsSection
                goalsSection
                glp1Section
                healthKitSection
                coachSection
                feedbackSection
                signOutSection
                deleteAccountSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
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
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryGradient)
                        .frame(width: 60, height: 60)
                    Text(initials)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.profile?.fullName ?? "Your Name")
                        .font(.title3.bold())
                    Text(vm.profile?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
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

    // MARK: - Body Stats

    private var bodyStatsSection: some View {
        Section("Body Stats") {
            Picker("Units", selection: $unitSystemRaw) {
                Text("Metric (kg, cm)").tag("metric")
                Text("Imperial (lbs, ft)").tag("imperial")
            }

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
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Section {
            Button("Sign Out", role: .destructive) {
                Task { try? await supabase.auth.signOut() }
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
    @State private var heightCm      = 170.0
    @State private var heightFeet    = 5.0
    @State private var heightInches  = 7.0
    @State private var activity      = ActivityLevel.moderate
    @State private var logWeight     = false
    @State private var weightInput   = 70.0   // in user's preferred unit
    @State private var isSaving      = false

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
                    DatePicker("Date of birth", selection: $dob,
                               in: ...Date.now, displayedComponents: .date)
                    Picker("Sex", selection: $sex) {
                        ForEach(BiologicalSex.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    if units == .imperial {
                        HStack {
                            Text("Height")
                            Spacer()
                            TextField("ft", value: $heightFeet, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 36)
                            Text("ft").foregroundStyle(.secondary)
                            TextField("in", value: $heightInches, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 36)
                            Text("in").foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Height")
                            Spacer()
                            TextField("cm", value: $heightCm, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
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
                            TextField(units.weightUnit, value: $weightInput, format: .number)
                                .keyboardType(.decimalPad)
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
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        name = vm.profile?.fullName ?? ""
        if let dobStr = vm.profile?.dob, let d = dobFormatter.date(from: dobStr) { dob = d }
        if let s = vm.profile?.sex { sex = BiologicalSex(rawValue: s) ?? .male }
        if let a = vm.profile?.activityLevel { activity = ActivityLevel(rawValue: a) ?? .moderate }

        let storedCm = vm.profile?.heightCm ?? 170
        heightCm     = storedCm
        heightFeet   = units.feetFrom(storedCm)
        heightInches = units.inchesFrom(storedCm)

        let storedKg  = vm.latestWeight?.weightKg ?? 70
        weightInput   = units.weightInput(from: storedKg)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // Pass the stored height so an untouched imperial field round-trips exactly
        // instead of being rewritten to the nearest whole inch.
        let storedCm = vm.profile?.heightCm ?? heightCm
        let finalHeightCm = units == .imperial
            ? units.cmFrom(feet: heightFeet, inches: heightInches, unchangedFrom: storedCm)
            : heightCm
        let finalWeightKg = units.kgFrom(weightInput)

        let update = UpdateProfile(
            fullName: name.trimmingCharacters(in: .whitespaces),
            dob: dobFormatter.string(from: dob),
            sex: sex.rawValue,
            heightCm: finalHeightCm,
            activityLevel: activity.rawValue
        )
        do {
            try await vm.updateProfile(update)
            if logWeight { try await vm.logWeight(finalWeightKg) }
            dismiss()
        } catch {
            vm.errorMessage = error.localizedDescription
        }
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
