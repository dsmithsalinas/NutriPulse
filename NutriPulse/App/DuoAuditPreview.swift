#if DEBUG
import SwiftUI

/// Audit entry points into production views. No test in this gallery invokes persistence,
/// grants consent/permissions, submits authentication, or changes medication records.
struct DuoAuditPreview: View {
    let screen: String
    @State private var profile = ProfileViewModel()
    init(screen: String) {
        self.screen = screen
        if screen == "nutrition" { NutritionImportStore.shared.loadPreview() }
        if screen == "about-you" {
            PulseProfileStore.shared.setForPreview(preferences: .init(), enabled: true)
        }
    }
    private var foods: [FoodLog] { AppStoreScreenshotPreview.todayModel().foodLogs }
    var body: some View {
        content.tint(Theme.Colors.primary).background(Theme.Colors.ground)
    }
    @ViewBuilder private var content: some View {
        switch screen {
        case "nutrition": NutritionImportView()
        case "tools-data", "tools-memories", "tools-experiment", "tools-library", "tools-leftovers", "tools-decision": EverydayToolsView(userId: AppStoreScreenshotPreview.sampleUser, onAskPulse: { _ in })
        case "health-link": ExperimentHealthLinkEditor(save: { _ in })
        case "observation": ScrollView { ExperimentObservationEditor(experiment: .init(action: "Walk after lunch", outcome: "energy", startedOn: Date.now.isoDateString), save: { _ in }).padding(18).daylightReadableWidth() }
        case "experiment-wrap": ExperimentWrapUpView(experiment: .init(action: "Walk after lunch", outcome: "energy", startedOn: Date.now.isoDateString), owner: AppStoreScreenshotPreview.sampleUser, preview: true)
        case "goal-builder": CreateGoalView(vm: GoalsViewModel(), initialDraft: .init(template: .protein))
        case "experiment-create": CreateExperimentAuditScreen()
        case "profile-edit", "targets-edit", "dose-edit", "notification-explainer": ProfileAuditScreens(screen: screen)
        case "goal-completed", "goal-day", "goal-detail": GoalAuditScreens(screen: screen)
        case "medication-conflict", "medication-correction": MedicationAuditScreens(screen: screen)
        case "usual-review": UsualMealReview(usual: .init(userId: AppStoreScreenshotPreview.sampleUser, name: "Simple lunch", meal: .lunch, items: foods), date: .now, meal: .lunch, onSaved: {})
        case "restaurant-picker": RestaurantPickerView(context: FoodLoggingContext())
        case "breakfast-settings": ScrollView { BreakfastCheckinSettings().padding(Theme.Spacing.page).daylightReadableWidth() }
        case "loading": StartupLoadingView(offersOfflineNotes: true, onOpenNotes: {})
        case "auth": AuthView()
        case "password-help": ForgotPasswordView(initialEmail: "")
        case "password-reset": ResetPasswordView()
        case "profile-recovery": ProfileLoadFailedView()
        case "calendar": DatePickerSheet(selected: .now, onPick: { _ in })
        case "body": NavigationStack { BodyHubView(todayVM: TodayViewModel(), heightCm: 175) }
        case "weight-history": NavigationStack { BodyMetricHistoryView(metric: .weight) }
        case "fat-history": NavigationStack { BodyMetricHistoryView(metric: .bodyFat) }
        case "lean-history": NavigationStack { BodyMetricHistoryView(metric: .leanMass) }
        case "waist-history": NavigationStack { BodyMetricHistoryView(metric: .site(.waist)) }
        case "body-goals": BodyGoalsSheet(current: nil, onSave: { _, _, _ in })
        case "body-entry": BodyCompositionSheet(current: .init(), heightCm: 175, onSave: { _, _, _, _, _, _ in })
        case "workout": WorkoutEntrySheet(onSave: { _, _, _, _ in })
        case "edit-food": EditFoodLogSheet(log: foods[0], onSave: { _, _ in })
        case "analytics": AnalyticsView(initialRange: .month)
        case "experiments": ExperimentsView(activeGoals: [])
        case "about-you": NavigationStack { AboutYouView() }
        case "food-access": NavigationStack { FoodAccessPreferencesView() }
        case "feedback": SendFeedbackSheet(vm: profile)
        case "notifications": NavigationStack { SmartNotificationSettingsView() }
        case "notification-history": NavigationStack { SmartNotificationHistoryView() }
        case "dose-history": NavigationStack { GLP1HistoryView() }
        case "medications": MedicationSettingsView()
        case "medication-editor": MedicationEditorView(store: .shared)
        case "medication-history": NavigationStack { MedicationHistoryView() }
        case "food-consent": FoodAIConsentSheet()
        case "pulse-consent": PulseConsentSheet()
        case "memory-editor": PulseMemoryEditor(proposed: "I prefer simple meals when work gets busy.", readOnlyPreview: true)
        case "offline-notes": OfflineMealNotesView()
        case "usual-save": SaveUsualMealSheet(foods: foods)
        case "lighter-tracking": LighterTrackingSheet()
        case "shot-check-in": ShotCycleCheckInSheet(cycleDay: 2, existing: nil, onSave: { _ in false })
        case "protein-rescue": ProteinRescueSheet(date: .now, proteinGap: 30, calorieRoom: 400, onLogged: {}, onBuildMyOwn: {})
        case "recipe": EasierDayRecipeView(owner: AppStoreScreenshotPreview.sampleUser, preview: true)
        default: Text("Unknown audit screen: \(screen)")
        }
    }
}
#endif
