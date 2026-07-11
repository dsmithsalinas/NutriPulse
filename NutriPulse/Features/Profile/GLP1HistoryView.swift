import SwiftUI

struct GLP1HistoryView: View {
    @State private var logs: [GLP1Log] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let repo = GLP1Repository()

    var body: some View {
        List {
            ForEach(logs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.medication)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(log.doseMg.glp1DoseString)mg")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(log.injectedAt, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let site = log.site {
                            Text(site)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Dose History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView()
            } else if logs.isEmpty {
                ContentUnavailableView(
                    "No Doses Logged",
                    systemImage: "syringe",
                    description: Text("Your dose history will appear here.")
                )
            }
        }
        .alert("Couldn't delete that dose", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            logs = (try? await repo.fetchAllLogs()) ?? []
            isLoading = false
        }
    }

    // Delete the dose, then re-point reminders at the most recent REMAINING log — the one that
    // now drives the schedule — or cancel them entirely if that was the last dose. Without this,
    // reminders could keep firing for a shot the user just removed.
    private func delete(_ log: GLP1Log) async {
        do {
            try await repo.deleteLog(id: log.id)
            logs.removeAll { $0.id == log.id }
            // fetchAllLogs sorts newest-first, and removeAll preserves order, so logs.first is
            // the most recent remaining dose.
            if let newest = logs.first, let due = newest.nextDueAt {
                await NotificationManager.shared.scheduleGLP1Reminders(nextDueAt: due)
            } else {
                NotificationManager.shared.cancelGLP1Reminders()
            }
        } catch {
            errorMessage = "Check your connection and try again."
        }
    }
}
