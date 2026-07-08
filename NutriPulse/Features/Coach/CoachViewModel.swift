import Foundation
import Supabase

@Observable
@MainActor
final class CoachViewModel {
    var messages: [CoachMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var error: String? = nil
    private(set) var canLoadOlder = false
    private(set) var isLoadingOlder = false

    private(set) var profile: UserProfile?
    private var hasInitialized = false

    private let repo = CoachRepository()
    private let contextBuilder = CoachContextBuilder()

    // MARK: - Initialization

    // Only runs once — safe to call on every tab selection; no-ops after first run.
    func loadIfNeeded() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        await loadAndInitialize()
    }

    // Called after clearing history so the tab reloads fresh.
    //
    // The flag must be restored. Leaving it false meant the next tap on the Pulse tab ran
    // loadAndInitialize a second time — and worse, if the user switched to Pulse while this
    // reload was still in flight, loadIfNeeded's guard passed (flag still false) and a
    // concurrent init started. Both saw `messages` empty, both cleared maybeGenerateCheckin's
    // 8-hour cutoff before either appended, and two check-ins were generated, two Claude
    // calls billed, both persisted.
    func reload() async {
        hasInitialized = true
        messages = []
        await loadAndInitialize()
    }

    private func loadAndInitialize() async {
        await loadProfile()
        await loadHistory()
        await maybeGenerateCheckin()
        await maybeGenerateWeeklySummary()
    }

    private func loadProfile() async {
        do {
            let userId = try await supabase.auth.session.user.id
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            profile = profiles.first
        } catch { }
    }

    private static let historyPageSize = 30

    private func loadHistory() async {
        do {
            messages = try await repo.fetchHistory(limit: Self.historyPageSize)
            // A full page means there is probably more behind it.
            canLoadOlder = messages.count == Self.historyPageSize
        } catch { }
    }

    // Everything older than the newest 30 messages used to be unreachable in the UI,
    // forever, though it was still in the database.
    func loadOlderMessages() async {
        guard canLoadOlder, !isLoadingOlder, let oldest = messages.first else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let older = try await repo.fetchHistory(limit: Self.historyPageSize, before: oldest.createdAt)
            canLoadOlder = older.count == Self.historyPageSize
            messages.insert(contentsOf: older, at: 0)
        } catch {
            self.error = "Couldn't load older messages."
        }
    }

    // MARK: - Auto-generated messages

    private func maybeGenerateCheckin() async {
        let cutoff = Date.now.addingTimeInterval(-8 * 3600)
        if let last = messages.last, last.createdAt > cutoff { return }
        let hour = Calendar.current.component(.hour, from: .now)
        let trigger: String
        switch hour {
        case 5..<11:  trigger = "Morning check-in."
        case 11..<15: trigger = "Midday check-in."
        case 15..<20: trigger = "Afternoon check-in."
        default:      trigger = "Evening check-in."
        }
        await generateAutoMessage(type: "checkin", trigger: trigger)
    }

    private func maybeGenerateWeeklySummary() async {
        let weekday = Calendar.current.component(.weekday, from: .now)
        guard weekday == 1 || weekday == 2 else { return }
        if let lastDate = try? await repo.lastWeeklySummaryDate() {
            let days = Calendar.current.dateComponents([.day], from: lastDate, to: .now).day ?? 0
            guard days >= 6 else { return }
        }
        await generateAutoMessage(type: "weekly_summary", trigger: "Weekly summary.")
    }

    private func generateAutoMessage(type: String, trigger: String) async {
        isLoading = true
        let context = await contextBuilder.build(profile: profile)
        let historyItems = messages.suffix(15).map { ChatRequest.HistoryItem(role: $0.role, content: $0.content) }
        do {
            let userId = try await supabase.auth.session.user.id
            let req = ChatRequest(message: trigger, messageType: type, history: historyItems, context: context)
            let resp: ChatResponse = try await supabase.functions.invoke("coach-chat", options: .init(body: req))
            if let reply = resp.reply {
                let saved: CoachMessage = try await repo.save(
                    NewCoachMessage(userId: userId, role: "assistant", content: reply, messageType: type)
                )
                messages.append(saved)
                Telemetry.checkinMessageViewed(messageType: type)
            }
        } catch { }
        isLoading = false
    }

    // MARK: - User-initiated messages

    func sendMessage(_ overrideText: String? = nil) async {
        let text = (overrideText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        isLoading = true
        error = nil

        // Tracks how far we got, so a failure can restore exactly what the user lost.
        var userMessageWasPersisted = false

        do {
            let userId = try await supabase.auth.session.user.id

            let userMsg: CoachMessage = try await repo.save(
                NewCoachMessage(userId: userId, role: "user", content: text, messageType: "chat")
            )
            userMessageWasPersisted = true
            messages.append(userMsg)

            let context = await contextBuilder.build(profile: profile)
            // Send up to 14 prior turns (7 exchanges) as history
            let historyItems = messages.dropLast().suffix(14).map {
                ChatRequest.HistoryItem(role: $0.role, content: $0.content)
            }

            let req = ChatRequest(message: text, messageType: "chat", history: historyItems, context: context)
            let resp: ChatResponse = try await supabase.functions.invoke("coach-chat", options: .init(body: req))

            guard let reply = resp.reply else {
                error = "Pulse didn't respond. Try again."
                isLoading = false
                return
            }

            // Show the reply BEFORE persisting it. By this point Claude has answered and the
            // tokens are paid for; if the second save threw — a connection dropped between
            // the two calls — the old code jumped to `catch`, discarded the reply entirely,
            // and told the user "Couldn't reach Pulse" even though Pulse had answered.
            let assistantMsg = CoachMessage(
                id: UUID(), userId: userId, role: "assistant",
                content: reply, messageType: "chat", createdAt: .now
            )
            messages.append(assistantMsg)
            Telemetry.coachMessageSent(messageType: "chat")

            do {
                _ = try await repo.save(
                    NewCoachMessage(userId: userId, role: "assistant", content: reply, messageType: "chat")
                )
            } catch {
                // The reply is on screen and useful; it just won't survive a relaunch.
                self.error = "Pulse replied, but the message couldn't be saved to your history."
            }
        } catch {
            self.error = "Couldn't reach Pulse right now. Try again."
            // `inputText = ""` happened before any network call. If the user's message never
            // reached the server there is nothing to retry and nothing on screen — the text
            // they typed was simply gone. Put it back in the composer.
            if !userMessageWasPersisted {
                inputText = text
            }
        }

        isLoading = false
    }

    // MARK: - Clear history

    func clearHistory() async {
        do {
            try await repo.clearHistory()
            messages = []
            canLoadOlder = false
        } catch {
            self.error = "Couldn't clear history."
        }
    }
}

// MARK: - Private request / response types

private struct ChatRequest: Encodable {
    let message: String
    let messageType: String
    let history: [HistoryItem]
    let context: CoachContextBundle

    struct HistoryItem: Encodable {
        let role: String
        let content: String
    }
}

private struct ChatResponse: Decodable {
    let reply: String?
    let error: String?
}
