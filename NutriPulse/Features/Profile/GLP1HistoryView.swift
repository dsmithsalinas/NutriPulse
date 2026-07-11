import SwiftUI

struct GLP1HistoryView: View {
    @State private var logs: [GLP1Log] = []
    @State private var isLoading = true

    var body: some View {
        List(logs) { log in
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
        .task {
            logs = (try? await GLP1Repository().fetchAllLogs()) ?? []
            isLoading = false
        }
    }
}
