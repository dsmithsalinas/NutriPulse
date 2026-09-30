import Foundation
import Supabase

@Observable
@MainActor
final class CoachViewModel {
    var messages: [CoachMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var error: String? = nil
    private(set) var suggestedPrompts: [String] = []
    private(set) var canLoadOlder = false
    private(set) var isLoadingOlder = false
    // History fetch failed (offline, 5xx). Drives the retry state — without it the tab is
    // just an empty scroll view, which reads as a broken build rather than "no connection".
    private(set) var historyLoadFailed = false
    // Profile fetch failed, so the coach is answering without the user's goals/GLP-1 context.
    private(set) var profileLoadFailed = false

    // MARK: Start screen
    // Pulse opens here and never messages first (docs/daylight-redesign.md). Everything on it
    // is built on the device; the first model call is whatever the user sends.
    private(set) var startSuggestions: [PulseStartSuggestion] = []
    /// Whether Pulse can see a current shot cycle, for the start screen's "what I can see" line.
    private(set) var hasShotCycle = false
    /// Where the current topic begins. Starting something from the start screen begins a fresh
    /// topic, so the conversation — on screen and in the history sent to Pulse — starts there.
    /// Marked by the last message before it rather than a timestamp: saved messages carry the
    /// server's clock, which can trail the device's and would hide the user's first message.
    private enum TopicStart {
        case wholeHistory           // "Pick up where you left off"
        case after(UUID?)           // nil: the topic started with no history at all
    }
    private var topicStart: TopicStart = .wholeHistory

    private(set) var profile: UserProfile?
    private var hasInitialized = false

    private let repo = CoachRepository()
    private let contextBuilder = CoachContextBuilder()
    private let glp1Repo = GLP1Repository()
    private let analyticsRepo = AnalyticsRepository()

    // MARK: Structured replies (docs/daylight-redesign.md)

    /// The user's last 30 days of local food logs, for resolving a Pulse food suggestion to
    /// something that can be logged again in one tap. See `PulseFoodResolver`.
    private(set) var recentFoodLogs: [FoodLog] = []

    /// Weekly recap chart data, built from the app's own local data (never from Pulse's text)
    /// and cached per message id so scrolling the conversation doesn't re-fetch it. Lazily
    /// loaded by the view when a recap card appears.
    struct RecapChartData {
        let days: [CoachContextBundle.LastWeekContext.Day]
        let goalProteinG: Double?
    }
    private var recapCharts: [UUID: RecapChartData] = [:]

    /// The conversation as shown: the current topic, or all history when picking up.
    var visibleMessages: [CoachMessage] {
        switch topicStart {
        case .wholeHistory, .after(nil):
            return messages
        case .after(let boundary?):
            guard let index = messages.firstIndex(where: { $0.id == boundary }) else { return messages }
            return Array(messages[(index + 1)...])
        }
    }

    private func beginTopic() {
        topicStart = .after(messages.last?.id)
    }

    /// The newest thing the user said, for "Pick up where you left off".
    var lastUserMessage: CoachMessage? {
        messages.last { $0.isUser }
    }

    var firstName: String? {
        profile?.fullName?
            .split(separator: " ")
            .first
            .map(String.init)
    }

    // MARK: - Initialization

    // Only runs once — safe to call on every tab selection; no-ops after first run.
    /// Returns whether this call did the load (and so already built the start screen).
    @discardableResult
    func loadIfNeeded() async -> Bool {
        guard !hasInitialized else { return false }
        hasInitialized = true
        await loadAndInitialize()
        return true
    }

    // Called after clearing history so the tab reloads fresh. The flag stays set so a tab
    // switch while this is in flight can't start a second, concurrent load.
    func reload() async {
        hasInitialized = true
        messages = []
        topicStart = .wholeHistory
        await loadAndInitialize()
    }

    // Pulse no longer generates a check-in or weekly summary when the tab opens. Those were
    // the only model calls made without the user asking; proactive coaching now lives in
    // notifications (smart coaching, Your Strong Week), and the recap waits for a tap.
    private func loadAndInitialize() async {
        #if DEBUG
        if Self.isPreview {
            loadPreview()
            await refreshStartSuggestions()
            return
        }
        #endif
        await loadProfile()
        await refreshSuggestedPrompts()
        await loadHistory()
        await refreshStartSuggestions()
    }

    // Retry entry point for the offline/error state.
    func retryInitialLoad() async {
        await loadAndInitialize()
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
            profileLoadFailed = false
        } catch {
            // Deliberately non-blocking: Pulse is still useful without the profile, just
            // more generic, so failing the whole tab would be worse than answering. But it
            // can't be silent — an un-recorded degradation makes "Pulse gave me a bad
            // answer" indistinguishable from "Pulse never had my profile".
            profileLoadFailed = true
        }
    }

    // The profile is what makes Pulse's advice specific, so a transient failure at init
    // shouldn't degrade every answer for the rest of the session. Retry once before we
    // build context; if it still fails, record that this reply went out without it.
    private func ensureProfileLoaded() async {
        if profileLoadFailed { await loadProfile() }
        if profileLoadFailed { Telemetry.coachProfileUnavailable() }
    }

    // These are selected locally from the same current-day cache Today and Pulse use.
    // No extra AI request is needed just to render chat furniture, and unsynced food or
    // workouts can influence the suggestions immediately.
    func refreshSuggestedPrompts(excluding excluded: String? = nil) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let logs = (try? LocalStore.shared.fetchFoodLogs(for: .now, userId: userId)) ?? []
        let goal = try? LocalStore.shared.fetchGoal(for: .now, userId: userId)
        let workouts = (try? LocalStore.shared.fetchRecentWorkoutLogs(days: 1, userId: userId)) ?? []
        let todaysWorkouts = workouts.filter { $0.logDate == Date.now.isoDateString }

        suggestedPrompts = CoachSuggestionBuilder.suggestions(
            hasFoodLogs: !logs.isEmpty,
            totalProteinG: logs.reduce(0) { $0 + $1.totalProteinG },
            proteinGoalG: goal?.proteinG,
            hasWorkout: !todaysWorkouts.isEmpty,
            hour: Calendar.current.component(.hour, from: .now),
            excluding: excluded
        )
    }

    /// Rebuilds the start screen's tiles. Called on every visit to the tab and on returning to
    /// the foreground, since the protein gap and shot day move through the day. Cheap: local
    /// cache plus two small lookups, no model call.
    func refreshStartSuggestions() async {
        await refreshRecentFoodLogs()
        #if DEBUG
        if Self.isPreview {
            hasShotCycle = true
            startSuggestions = CoachSuggestionBuilder.startSuggestions(
                totalProteinG: 112, proteinGoalG: 140, cycleDay: 3, recapDue: true, now: .now
            )
            return
        }
        #endif
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let logs = (try? LocalStore.shared.fetchFoodLogs(for: .now, userId: userId)) ?? []
        let goal = try? LocalStore.shared.fetchGoal(for: .now, userId: userId)

        async let latestDose = glp1Repo.fetchRecentLogs(limit: 1)
        async let skips = glp1Repo.fetchSkippedDoses()
        async let lastRecap = repo.lastWeeklySummaryDate()

        var cycleDay: Int?
        if let log = (try? await latestDose)?.first, let skips = try? await skips {
            let schedule = GLP1DoseSchedule(latest: log, skips: skips)
            if !schedule.cycleInterrupted {
                cycleDay = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: log.injectedAt),
                    to: Calendar.current.startOfDay(for: .now)
                ).day.flatMap { $0 >= 0 ? $0 : nil }
            }
        }
        hasShotCycle = cycleDay != nil

        // A failed lookup hides the tile rather than offering it: unknown is not "no recap
        // yet", and offering it could bill a second recap for a week that already has one.
        let recapDue: Bool
        do {
            recapDue = WeeklyRecapSchedule.isDue(now: .now, lastRecapAt: try await lastRecap)
        } catch {
            recapDue = false
        }

        startSuggestions = CoachSuggestionBuilder.startSuggestions(
            totalProteinG: logs.reduce(0) { $0 + $1.totalProteinG },
            proteinGoalG: goal?.proteinG,
            cycleDay: cycleDay,
            recapDue: recapDue,
            now: .now
        )
    }

    // MARK: - Structured replies: food cards

    // Preview sets its own fixture logs directly (loadPreview); a real fetch here would
    // overwrite them with an empty local cache.
    private func refreshRecentFoodLogs() async {
        #if DEBUG
        if Self.isPreview { return }
        #endif
        guard let userId = try? await supabase.auth.session.user.id else { return }
        let since = Date.now.addingTimeInterval(-30 * 24 * 3600)
        recentFoodLogs = (try? LocalStore.shared.fetchFoodLogs(since: since, userId: userId)) ?? []
    }

    /// The user's own log this food-card name resolves to, or nil to hide the card. Pure
    /// matching lives in `PulseFoodResolver`; see its tests.
    func resolveFoodLog(named name: String) -> FoodLog? {
        PulseFoodResolver.resolve(name, in: recentFoodLogs)
    }

    /// Logs a resolved food suggestion again, to the meal for the current time of day, today —
    /// the same local-first write `FavoritesViewModel.logAgain` uses for "log again" on a
    /// Recents row, so a Pulse food card and a Favorites row behave identically.
    @discardableResult
    func logSuggestedFood(_ log: FoodLog) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else { return false }
        do {
            try LocalStore.shared.insertFoodLog(
                id: UUID(),
                userId: userId,
                logDate: Date.now.isoDateString,
                meal: Meal.current.rawValue,
                foodItemId: log.foodItemId,
                foodItemName: log.displayName,
                quantity: log.quantity,
                caloriesSnapshot: log.caloriesSnapshot,
                proteinGSnapshot: log.proteinGSnapshot,
                carbsGSnapshot: log.carbsGSnapshot,
                fatGSnapshot: log.fatGSnapshot,
                fiberGSnapshot: log.fiberGSnapshot
            )
            SyncEngine.shared.refreshPendingCount()
            Task { await SyncEngine.shared.pushPendingChanges() }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Structured replies: weekly recap chart

    /// Already-loaded chart data for this recap message, if any. The view calls
    /// `loadRecapChartIfNeeded` first (typically from `.task`) to populate it.
    func recapChart(for message: CoachMessage) -> RecapChartData? {
        recapCharts[message.id]
    }

    /// Builds the 7-day protein chart for a recap message's week from the app's own local data
    /// — Pulse only writes the four text fields; the bars are never taken from its reply. Keyed
    /// off the message's own `createdAt` (not `.now`) so an old recap, opened later, still shows
    /// the week it was actually written about.
    func loadRecapChartIfNeeded(for message: CoachMessage) async {
        guard message.payload?.recap != nil, recapCharts[message.id] == nil else { return }
        #if DEBUG
        if Self.isPreview {
            recapCharts[message.id] = Self.previewRecapChart
            return
        }
        #endif
        let interval = WeeklyRecapSchedule.lastWeek(before: message.createdAt)
        let summaries = (try? await analyticsRepo.fetchDailySummaries(from: interval.start, through: interval.end)) ?? []
        let userId = try? await supabase.auth.session.user.id
        let goal = userId.flatMap { try? LocalStore.shared.fetchGoal(for: .now, userId: $0) }
        let lastWeek = WeeklyRecapDigest.build(
            interval: interval, summaries: summaries, movement: [], weightLogs: [], checkIns: [], foodNames: [],
            proteinGoal: goal?.proteinG
        )
        recapCharts[message.id] = RecapChartData(days: lastWeek.days, goalProteinG: goal?.proteinG)
    }

    // MARK: - Topics

    /// Starts a fresh topic from the start screen: the conversation view and the history sent
    /// to Pulse both begin here.
    func startTopic(_ prompt: String) async {
        guard !isLoading else { return }
        beginTopic()
        await sendMessage(prompt)
    }

    /// "Pick up where you left off" and the history button: show everything saved.
    func resumeConversation() {
        topicStart = .wholeHistory
    }

    /// The Monday Recap tile. The only way the weekly summary is generated now.
    func requestWeeklyRecap() async {
        guard !isLoading else { return }
        beginTopic()
        do {
            let userId = try await supabase.auth.session.user.id
            let asked: CoachMessage = try await repo.save(
                NewCoachMessage(userId: userId, role: "user", content: "Monday Recap", messageType: "chat")
            )
            messages.append(asked)
        } catch {
            self.error = EdgeFunctionError.message(from: error, fallback: "Couldn't reach Pulse right now. Try again.")
            return
        }
        await generateAutoMessage(type: "weekly_summary", trigger: "Weekly recap for last week.")
        // Once written, this week's recap hides the tile.
        await refreshStartSuggestions()
    }

    private static let historyPageSize = 30

    // Returns whether the fetch actually succeeded — callers must not treat a failed load as
    // "no messages", which is what silently swallowing this error used to cause.
    @discardableResult
    private func loadHistory() async -> Bool {
        do {
            messages = try await repo.fetchHistory(limit: Self.historyPageSize)
            // A full page means there is probably more behind it.
            canLoadOlder = messages.count == Self.historyPageSize
            historyLoadFailed = false
            return true
        } catch {
            historyLoadFailed = true
            return false
        }
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

    // MARK: - Structured requests

    // A request Pulse answers from a trigger rather than the user's words (today, only the
    // weekly recap). The trigger isn't saved; the reply is, tagged with `type`.
    private func generateAutoMessage(type: String, trigger: String) async {
        isLoading = true
        await ensureProfileLoaded()
        let context = await contextBuilder.build(profile: profile, includeLastWeek: type == "weekly_summary")
        let historyItems = visibleMessages.suffix(15).map { ChatRequest.HistoryItem(role: $0.role, content: $0.content) }
        do {
            let userId = try await supabase.auth.session.user.id
            let req = ChatRequest(message: trigger, messageType: type, history: historyItems, context: context)
            let resp: ChatResponse = try await supabase.functions.invoke("coach-chat", options: .init(body: req))
            if let reply = resp.reply {
                let saved = try await saveAssistantReply(
                    userId: userId, content: reply, messageType: type, payload: resp.payload
                )
                messages.append(saved)
                Telemetry.checkinMessageViewed(messageType: type)
            }
        } catch { }
        isLoading = false
    }

    // MARK: - Saving assistant replies

    /// Saves an assistant message with its structured payload (foods, follow-ups, recap). The
    /// `coach_messages.payload` column may not exist yet in this environment (the migration
    /// hasn't shipped to production) — if the insert fails and a payload was attached, retry
    /// once without it, since losing a card is better than losing the whole message.
    @discardableResult
    private func saveAssistantReply(
        userId: UUID, content: String, messageType: String, payload: CoachMessagePayload?
    ) async throws -> CoachMessage {
        do {
            return try await repo.save(
                NewCoachMessage(userId: userId, role: "assistant", content: content, messageType: messageType, payload: payload)
            )
        } catch {
            guard payload != nil else { throw error }
            return try await repo.save(
                NewCoachMessage(userId: userId, role: "assistant", content: content, messageType: messageType, payload: nil)
            )
        }
    }

    // MARK: - User-initiated messages

    func sendMessage(_ overrideText: String? = nil) async {
        let text = (overrideText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        let selectedSuggestion = suggestedPrompts.contains(text) ? text : nil

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

            await ensureProfileLoaded()
            let context = await contextBuilder.build(profile: profile)
            // Send up to 14 prior turns (7 exchanges) of the current topic as history
            let historyItems = visibleMessages.dropLast().suffix(14).map {
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
                content: reply, messageType: "chat", createdAt: .now, payload: resp.payload
            )
            messages.append(assistantMsg)
            Telemetry.coachMessageSent(messageType: "chat")

            do {
                _ = try await saveAssistantReply(
                    userId: userId, content: reply, messageType: "chat", payload: resp.payload
                )
            } catch {
                // The reply is on screen and useful; it just won't survive a relaunch.
                self.error = "Pulse replied, but the message couldn't be saved to your history."
            }
        } catch {
            // Surfaces the server's reason when there is one — notably the friendly 429
            // rate-limit copy — and the generic message for a genuine transport failure.
            self.error = EdgeFunctionError.message(from: error, fallback: "Couldn't reach Pulse right now. Try again.")
            // `inputText = ""` happened before any network call. If the user's message never
            // reached the server there is nothing to retry and nothing on screen — the text
            // they typed was simply gone. Put it back in the composer.
            if !userMessageWasPersisted {
                inputText = text
            }
        }

        await refreshSuggestedPrompts(excluding: selectedSuggestion)
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

// MARK: - Preview

#if DEBUG
extension CoachViewModel {
    // `--pulse-preview`: the start screen and a short conversation from fixtures, with no
    // account or network, so the redesign can be checked in the simulator.
    static var isPreview: Bool {
        ProcessInfo.processInfo.arguments.contains("--pulse-preview")
    }

    fileprivate func loadPreview() {
        let user = UUID()
        let yesterday = Date.now.addingTimeInterval(-26 * 3600)
        profile = UserProfile(
            id: user, email: "preview@example.com", fullName: "Dustin Smith-Salinas", dob: nil, sex: nil,
            heightCm: nil, activityLevel: nil, weightGoal: nil, dietaryPrefs: nil, createdAt: .now
        )
        messages = [
            CoachMessage(id: UUID(), userId: user, role: "user",
                         content: "Not very hungry tonight. What's easy?", messageType: "chat", createdAt: yesterday),
            CoachMessage(
                id: UUID(), userId: user, role: "assistant",
                content: "Go small and dense. Any of these covers most of the last 28g without a big plate: the shake alone gets you there.",
                messageType: "chat", createdAt: yesterday.addingTimeInterval(20),
                payload: CoachMessagePayload(
                    foods: [
                        .init(name: "Protein shake", why: "1 bottle · you log this often"),
                        .init(name: "Greek yogurt", why: "1 cup, 20g"),
                    ],
                    followUps: ["Something warm?", "Plan tomorrow", "Dessert ideas"],
                    recap: nil
                )
            ),
            CoachMessage(id: UUID(), userId: user, role: "user",
                         content: "Monday Recap", messageType: "chat", createdAt: yesterday.addingTimeInterval(3600)),
            CoachMessage(
                id: UUID(), userId: user, role: "assistant",
                content: """
                Steady all week, until the weekend took the protein.
                Went well: three floor days mid-week, mostly thanks to yogurt breakfasts.
                Pattern: your lightest days matched your low-appetite check-ins.
                This week's focus: stage a small yogurt bowl for Saturday morning.
                """,
                messageType: "weekly_summary", createdAt: yesterday.addingTimeInterval(3620),
                payload: CoachMessagePayload(
                    foods: nil,
                    followUps: ["Plan Saturday", "Low-appetite ideas", "Explain the weekend dip"],
                    recap: .init(
                        story: "Steady all week, until the weekend took the protein.",
                        wentWell: "Three floor days mid-week, mostly thanks to yogurt breakfasts.",
                        pattern: "Your lightest days matched your low-appetite check-ins.",
                        focus: "Stage a small yogurt bowl for Saturday morning."
                    )
                )
            ),
        ]

        // Lets the food cards above resolve to something loggable, the same way a real
        // conversation resolves against the last 30 days of local logs.
        recentFoodLogs = [
            FoodLog(
                id: UUID(), userId: user, loggedAt: yesterday, logDate: yesterday.isoDateString,
                meal: .snack, foodItemId: UUID(), quantity: 1,
                caloriesSnapshot: 160, proteinGSnapshot: 30, carbsGSnapshot: 6, fatGSnapshot: 3, fiberGSnapshot: 0,
                foodItems: .init(name: "Protein shake", brand: nil, servingDesc: nil)
            ),
            FoodLog(
                id: UUID(), userId: user, loggedAt: yesterday.addingTimeInterval(-3600), logDate: yesterday.isoDateString,
                meal: .breakfast, foodItemId: UUID(), quantity: 1,
                caloriesSnapshot: 150, proteinGSnapshot: 20, carbsGSnapshot: 9, fatGSnapshot: 4, fiberGSnapshot: 0,
                foodItems: .init(name: "Greek yogurt", brand: nil, servingDesc: nil)
            ),
        ]
    }

    // Fixture chart for the preview recap card — the only place fabricated protein numbers are
    // allowed; a real recap always builds this from local data (`loadRecapChartIfNeeded`).
    fileprivate static var previewRecapChart: RecapChartData {
        let days: [(String, Bool, Int?, Bool?)] = [
            ("Mon", true, 138, true), ("Tue", true, 121, false), ("Wed", true, 145, true),
            ("Thu", true, 140, true), ("Fri", true, 118, false), ("Sat", false, nil, nil), ("Sun", true, 95, false),
        ]
        return RecapChartData(
            days: days.map { day in
                CoachContextBundle.LastWeekContext.Day(
                    day: day.0, logged: day.1, calories: day.2.map { $0 * 12 }, proteinG: day.2,
                    proteinFloorHit: day.3, workoutMinutes: nil, cycleDay: nil, appetite: nil
                )
            },
            goalProteinG: 140
        )
    }
}
#endif

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

// Mirrors `coach-chat`'s response shape (supabase/functions/_shared/pulse-context.ts): `reply`
// is always present when the call succeeds; the extras are absent whenever Pulse didn't produce
// them (no length/count constraints server-side — `parsePulseReply` already clamps counts before
// this ever reaches the client).
private struct ChatResponse: Decodable {
    let reply: String?
    let error: String?
    let foods: [CoachMessagePayload.FoodSuggestion]?
    let followUps: [String]?
    let recap: CoachMessagePayload.Recap?

    /// nil when none of the extras are present, so a save never attaches an empty payload.
    var payload: CoachMessagePayload? {
        guard foods != nil || followUps != nil || recap != nil else { return nil }
        return CoachMessagePayload(foods: foods, followUps: followUps, recap: recap)
    }
}
