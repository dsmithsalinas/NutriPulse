import Foundation
import Supabase

@Observable @MainActor
final class StrongWeekViewModel {
    var current: StrongWeek?
    var previous: StrongWeek?
    var draft = StrongWeekDraft()
    var isLoading = true
    var isGenerating = false
    var loadFailed = false
    var error: String?
    var editing = false
    var changedSinceGeneration = false
    var didConfirmPrevious = false
    private var loadedWeekKey: String?
    private var loadedUserId: UUID?
    private var pendingOutlook: StrongWeekOutlook?
    private var pendingRevision: UUID?
    private var pendingFoodAccessUpdatedAt: Date?
    private let repo = StrongWeekRepository()

    var previousNeedsConfirmation: Bool { current == nil && previous?.ongoing == true }
    var needsRefresh: Bool {
        changedSinceGeneration || current?.generatedAt.map { !Calendar.current.isDateInToday($0) } == true
    }

    func load() async {
        guard !isGenerating else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let userId = try await supabase.auth.session.user.id
            if loadedUserId != userId {
                current = nil; previous = nil; draft = .init(); pendingOutlook = nil; pendingRevision = nil
                pendingFoodAccessUpdatedAt = nil; changedSinceGeneration = false
                loadedUserId = userId
            }
            let key = StrongWeekWindow.key()
            async let foodAccess = FoodAccessRepository().fetch()
            let weeks = try await repo.fetchLatest()
            let preferences = try? await foodAccess
            guard try await supabase.auth.session.user.id == userId, StrongWeekWindow.key() == key else { return }
            if loadedWeekKey != key { didConfirmPrevious = false; editing = false }
            loadedWeekKey = key
            current = weeks.first { $0.weekStart == key }
            previous = weeks.first { $0.weekStart < key }
            if let generatedAt = current?.generatedAt, let updatedAt = preferences?.updatedAt, updatedAt > generatedAt {
                changedSinceGeneration = true
            }
            if !editing { draft = current?.draft ?? .init() }
            loadFailed = false
            error = nil
        } catch {
            loadFailed = true
            self.error = "Couldn't load your week. Try again when you're connected."
        }
    }

    func foodPreferencesChanged() {
        changedSinceGeneration = true
        pendingOutlook = nil; pendingRevision = nil; pendingFoodAccessUpdatedAt = nil
    }

    func beginEditing() {
        draft = current?.draft ?? .init()
        editing = true
        error = nil
    }

    func confirmPrevious() {
        guard let previous else { return }
        draft = previous.draft
        draft.adjustments = [] // Response preferences expire with the previous week.
        didConfirmPrevious = true
    }

    func clearPrevious() {
        draft = .init(circumstances: [.usual])
        didConfirmPrevious = true
    }

    func adjust(_ adjustments: Set<WeekAdjustment>, profile: UserProfile?) async {
        guard let current, !isGenerating else { return }
        draft = current.draft
        draft.adjustments = adjustments
        await generate(profile: profile, updateContext: true)
    }

    func generate(profile: UserProfile?, updateContext: Bool) async {
        guard !isGenerating, !loadFailed, let userId = loadedUserId else { return }
        isGenerating = true
        error = nil
        defer { isGenerating = false }
        do {
            guard try await supabase.auth.session.user.id == userId else { throw URLError(.userAuthenticationRequired) }
            let key = StrongWeekWindow.key()
            guard loadedWeekKey == key else { throw URLError(.cancelled) }
            guard !previousNeedsConfirmation || didConfirmPrevious else { throw URLError(.userAuthenticationRequired) }
            if updateContext || current?.weekStart != key {
                current = try await repo.saveContext(draft.normalized, weekStart: key, expectedRevision: current?.contextRevision)
                pendingOutlook = nil; pendingRevision = nil
                editing = false
                NotificationCenter.default.post(name: .strongWeekChanged, object: nil)
                if StrongWeekContext.make(current: current, previous: nil).needsTailoredSuggestions {
                    NotificationManager.shared.cancelSmartNotifications()
                }
            }
            guard let week = current else { throw URLError(.badServerResponse) }

            // The check-in and its adjustments are saved above regardless — that's the weekly
            // plan input, not an AI call. Only the written outlook itself goes to the AI
            // provider, and only Pulse sends anything there. See PulseGate.isActive.
            guard PulseProfileStore.shared.pulseActive else { return }

            let foodAccess = try await FoodAccessRepository().fetch()
            let outlook: StrongWeekOutlook
            if let pendingOutlook, pendingRevision == week.contextRevision, pendingFoodAccessUpdatedAt == foodAccess?.updatedAt {
                outlook = pendingOutlook
            } else {
                var context = await CoachContextBuilder().build(profile: profile, includeWeeklyEvidence: true)
                // The exact saved revision takes precedence over a concurrent context fetch.
                context.strongWeek = .make(current: week, previous: nil)
                context.foodAccess = .make(foodAccess)
                struct Request: Encodable {
                    let message = "Create Your strong week from my saved context and the supplied evidence."
                    let messageType = "weekly_outlook"
                    let context: CoachContextBundle
                }
                struct Response: Decodable { let outlook: StrongWeekOutlook }
                guard try await supabase.auth.session.user.id == userId,
                      StrongWeekWindow.key() == week.weekStart else { throw URLError(.cancelled) }
                let response: Response = try await supabase.functions.invoke("coach-chat", options: .init(body: Request(context: context)))
                outlook = response.outlook
                pendingOutlook = outlook; pendingRevision = week.contextRevision
                pendingFoodAccessUpdatedAt = foodAccess?.updatedAt
            }
            guard try await supabase.auth.session.user.id == userId,
                  StrongWeekWindow.key() == week.weekStart else { throw URLError(.cancelled) }
            let latestFoodAccess = try await FoodAccessRepository().fetch()
            guard latestFoodAccess?.updatedAt == foodAccess?.updatedAt else {
                foodPreferencesChanged()
                throw URLError(.cancelled)
            }
            current = try await repo.saveOutlook(outlook, for: week)
            pendingOutlook = nil; pendingRevision = nil
            changedSinceGeneration = false
            NotificationCenter.default.post(name: .strongWeekChanged, object: nil)
        } catch {
            self.error = EdgeFunctionError.message(from: error,
                fallback: "Your week couldn't be updated. Any saved context is kept. Try again, or reopen to load the latest version.")
        }
    }
}
