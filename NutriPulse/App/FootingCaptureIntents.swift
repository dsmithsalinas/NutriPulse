import AppIntents
import Foundation
import Supabase

enum CaptureWaterUnit: String, AppEnum {
    case milliliters, fluidOunces
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Water unit")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .milliliters: "Milliliters", .fluidOunces: "US fluid ounces"
    ]
    func milliliters(for amount: Double) -> Double? {
        let ml = self == .milliliters ? amount : amount * 29.5735295625
        return amount.isFinite && ml.isFinite && ml >= 1 && ml <= 3000 ? ml : nil
    }
}

enum QuickCaptureError: LocalizedError {
    case signIn, changedAccount, invalidWater, invalidNote
    var errorDescription: String? {
        switch self {
        case .signIn: "Open Footing and sign in before saving."
        case .changedAccount: "Your account changed. Run the shortcut again."
        case .invalidWater: "Choose a water amount between 1 and 3,000 milliliters, or the equivalent in US fluid ounces."
        case .invalidNote: "Use a note between 1 and 1,000 characters."
        }
    }
}

struct CaptureWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Record water"
    static let description = IntentDescription("Confirm and save a specific amount of water in Footing without opening the app.")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    @Parameter(title: "Amount") var amount: Double
    @Parameter(title: "Unit", default: .milliliters) var unit: CaptureWaterUnit
    static var parameterSummary: some ParameterSummary { Summary("Record \(\.$amount) \(\.$unit) of water") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let ml = unit.milliliters(for: amount) else { throw QuickCaptureError.invalidWater }
        guard let owner = try? await supabase.auth.session.user.id else { throw QuickCaptureError.signIn }
        // Confirm the account before presenting sensitive data and again before the write.
        guard supabase.auth.currentSession?.user.id == owner else { throw QuickCaptureError.changedAccount }
        try await requestConfirmation(result: .result(dialog: "Save \(Int(ml.rounded())) milliliters of water for today in Footing?"))
        guard supabase.auth.currentSession?.user.id == owner else { throw QuickCaptureError.changedAccount }
        // App Intents runs in the app process; FootingApp configures this durable store.
        // No network is needed to commit, and a failed local save must never report success.
        try LocalStore.shared.insertWaterLog(id: UUID(), userId: owner, logDate: Date.now.isoDateString, amountMl: ml)
        SyncEngine.shared.refreshPendingCount()
        NotificationCenter.default.post(name: .quickCaptureChanged, object: owner)
        Task { await SyncEngine.shared.pushPendingChanges() }
        return .result(dialog: "Saved \(Int(ml.rounded())) milliliters in Footing. You can remove it from today’s water history.")
    }
}

struct CaptureDayNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Save a quick note"
    static let description = IntentDescription("Confirm and save a day note. No calories, macros or lasting Pulse memory are created.")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    @Parameter(title: "Note") var note: String
    static var parameterSummary: some ParameterSummary { Summary("Save \(\.$note) as a day note") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let body = MealNote.validBody(note) else { throw QuickCaptureError.invalidNote }
        guard let owner = try? await supabase.auth.session.user.id else { throw QuickCaptureError.signIn }
        guard supabase.auth.currentSession?.user.id == owner else { throw QuickCaptureError.changedAccount }
        try await requestConfirmation(result: .result(dialog: "Save this day note in Footing: \(body)?"))
        guard supabase.auth.currentSession?.user.id == owner else { throw QuickCaptureError.changedAccount }
        try await MealNoteRepository().save(MealNote(userId: owner, logDate: Date.now.isoDateString, meal: .snack, body: body, kind: .dayContext))
        return .result(dialog: "Day note saved in Footing. You can edit or delete it on Today. It was not added to lasting Pulse memory.")
    }
}

struct OpenOffScriptIntent: AppIntent {
    static let title: LocalizedStringResource = "Today went sideways"
    static let description = IntentDescription("Open Footing’s three off-script choices.")
    static var openAppWhenRun: Bool = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    func perform() async throws -> some IntentResult {
        QuickActionStore.enqueue(.offScript)
        return .result()
    }
}

extension Notification.Name { static let quickCaptureChanged = Notification.Name("quickCaptureChanged") }
