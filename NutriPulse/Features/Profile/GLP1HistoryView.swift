import SwiftUI

struct GLP1HistoryView: View {
    @State private var logs: [GLP1Log] = []
    @State private var skips: [GLP1SkippedDose] = []
    @State private var isSaving = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let repo = GLP1Repository()

    var body: some View {
        List {
            Section {
                DaylightPageTitle("Dose history")
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            if !skips.isEmpty {
                Section {
                    ForEach(skips) { skip in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(logs.first(where: { $0.id == skip.injectionId })?.medication ?? "Shot") · skipped")
                                .font(Theme.Fonts.body(15, .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("Planned for \(skip.scheduledAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(Theme.Fonts.body(13))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Button("Undo skip") { Task { await undo(skip) } }
                                .font(Theme.Fonts.body(14, .bold))
                                .foregroundStyle(Theme.Colors.primaryText)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                    }
                } header: {
                    DaylightSectionHeader("Skipped doses")
                }
                .daylightSection()
            }
            Section {
                ForEach(logs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.medication)
                                .font(Theme.Fonts.body(15, .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text("\(log.doseMg.glp1DoseString)mg")
                                .font(Theme.Fonts.body(14))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        HStack {
                            Text(log.injectedAt, style: .date)
                                .font(Theme.Fonts.body(13))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                            if let site = log.site {
                                Text(site)
                                    .font(Theme.Fonts.body(12))
                                    .foregroundStyle(Theme.Colors.textFaint)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await delete(log) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                DaylightSectionHeader("Shots taken")
            }
            .daylightSection()
        }
        .disabled(isSaving)
        .listStyle(.insetGrouped)
        .daylightForm()
        .daylightSubpage("Dose history")
        .overlay {
            if isLoading {
                ProgressView()
            } else if logs.isEmpty && skips.isEmpty {
                BrandedEmptyState(icon: "syringe", title: "No Doses Logged", message: "Your dose history will appear here.")
            }
        }
        .alert("Couldn't update dose history", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            do {
                async let logsTask = repo.fetchAllLogs()
                async let skipsTask = repo.fetchSkippedDoses()
                (logs, skips) = try await (logsTask, skipsTask)
            } catch { errorMessage = "Couldn't load your dose history. Check your connection and try again." }
            isLoading = false
        }
    }

    private func reconcile() async {
        await NotificationManager.shared.reconcileGLP1Reminders(
            schedule: .init(latest: logs.first, skips: skips)
        )
        NotificationCenter.default.post(name: .glp1DoseHistoryChanged, object: nil)
    }

    private func undo(_ skip: GLP1SkippedDose) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await repo.undoSkip(id: skip.id)
            skips.removeAll { $0.id == skip.id }
            await reconcile()
        } catch { errorMessage = "Check your connection and try again." }
    }

    private func delete(_ log: GLP1Log) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await repo.deleteLog(id: log.id)
            logs.removeAll { $0.id == log.id }
            skips.removeAll { $0.injectionId == log.id }
            await reconcile()
        } catch { errorMessage = "Check your connection and try again." }
    }
}
