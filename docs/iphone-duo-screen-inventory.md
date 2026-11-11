# iPhone Duo screen layout inventory

2026-11-08

Source inventory of 60 feature files containing a scroll view or form. Some files contain multiple screens or embedded components. A width policy is source evidence, not physical-device certification or proof that every nested state has been tested. Runtime coverage and outstanding checks are in [the readiness audit](iphone-duo-readiness.md).

| Source | Layout coverage |
| --- | --- |
| [Auth/ResetPasswordView.swift](../NutriPulse/Features/Auth/ResetPasswordView.swift) | Has an explicit bounded, scrollable recovery canvas |
| [Analytics/AnalyticsView.swift](../NutriPulse/Features/Analytics/AnalyticsView.swift) | Uses shared form/subpage width limit |
| [Auth/AuthView.swift](../NutriPulse/Features/Auth/AuthView.swift) | Has an explicit bounded canvas or dashboard |
| [Auth/ForgotPasswordView.swift](../NutriPulse/Features/Auth/ForgotPasswordView.swift) | Has an explicit bounded canvas or dashboard |
| [Body/BodyGoalsSheet.swift](../NutriPulse/Features/Body/BodyGoalsSheet.swift) | Uses shared form/subpage width limit |
| [Body/BodyHubView.swift](../NutriPulse/Features/Body/BodyHubView.swift) | Uses shared form/subpage width limit |
| [Body/BodyMetricHistoryView.swift](../NutriPulse/Features/Body/BodyMetricHistoryView.swift) | Uses shared form/subpage width limit |
| [Coach/CoachView.swift](../NutriPulse/Features/Coach/CoachView.swift) | Has an explicit bounded canvas or dashboard |
| [Coach/PulseMemoryViews.swift](../NutriPulse/Features/Coach/PulseMemoryViews.swift) | Has an explicit bounded canvas or dashboard |
| [EverydayTools/EasierDayRecipeView.swift](../NutriPulse/Features/EverydayTools/EasierDayRecipeView.swift) | Has an explicit bounded canvas or dashboard |
| [EverydayTools/EverydayToolsView.swift](../NutriPulse/Features/EverydayTools/EverydayToolsView.swift) | Has an explicit bounded canvas or dashboard |
| [EverydayTools/ExperimentHealthCard.swift](../NutriPulse/Features/EverydayTools/ExperimentHealthCard.swift) | Has an explicit bounded canvas or dashboard |
| [EverydayTools/ExperimentWrapUpView.swift](../NutriPulse/Features/EverydayTools/ExperimentWrapUpView.swift) | Has an explicit bounded canvas or dashboard |
| [FoodLogging/BarcodeScanView.swift](../NutriPulse/Features/FoodLogging/BarcodeScanView.swift) | Camera bounded by workspace; permission fallback scrolls |
| [FoodLogging/FamiliarFoodReview.swift](../NutriPulse/Features/FoodLogging/FamiliarFoodReview.swift) | Two review lanes when wide; scrolling body with persistent header/save |
| [FoodLogging/FoodLoggingView.swift](../NutriPulse/Features/FoodLogging/FoodLoggingView.swift) | Shared expanded logging workspace with independently scrolling method rail |
| [FoodLogging/FavoritesView.swift](../NutriPulse/Features/FoodLogging/FavoritesView.swift) | Bounded by FoodLoggingView |
| [FoodLogging/FoodSearchView.swift](../NutriPulse/Features/FoodLogging/FoodSearchView.swift) | Detail: serving and nutrition form columns at expanded widths; stacked at large text |
| [FoodLogging/ManualEntryView.swift](../NutriPulse/Features/FoodLogging/ManualEntryView.swift) | Food and nutrition form columns when expanded; reserved footer and explicit keyboard focus |
| [FoodLogging/MealNoteSheet.swift](../NutriPulse/Features/FoodLogging/MealNoteSheet.swift) | Context/editor lanes when expanded; focused editor with keyboard, Close/Save outside the scrolling body |
| [FoodLogging/OfflineMealNotesView.swift](../NutriPulse/Features/FoodLogging/OfflineMealNotesView.swift) | Has an explicit bounded canvas or dashboard |
| [FoodLogging/ProteinRescueSheet.swift](../NutriPulse/Features/FoodLogging/ProteinRescueSheet.swift) | Has an explicit bounded canvas or dashboard |
| [FoodLogging/RepeatedMealConfirmationSheet.swift](../NutriPulse/Features/FoodLogging/RepeatedMealConfirmationSheet.swift) | Has an explicit bounded canvas or dashboard |
| [FoodLogging/RestaurantLoggingViews.swift](../NutriPulse/Features/FoodLogging/RestaurantLoggingViews.swift) | Uses shared form/subpage width limit |
| [FoodLogging/TalkToLogView.swift](../NutriPulse/Features/FoodLogging/TalkToLogView.swift) | Bounded by FoodLoggingView |
| [FoodLogging/UsualMealViews.swift](../NutriPulse/Features/FoodLogging/UsualMealViews.swift) | Has an explicit bounded canvas or dashboard |
| [GLP1/GLP1TrackerView.swift](../NutriPulse/Features/GLP1/GLP1TrackerView.swift) | Has an explicit bounded canvas or dashboard |
| [GLP1/InjectionRitualView.swift](../NutriPulse/Features/GLP1/InjectionRitualView.swift) | Has an explicit bounded canvas or dashboard |
| [GLP1/ShotCycleCheckInSheet.swift](../NutriPulse/Features/GLP1/ShotCycleCheckInSheet.swift) | Has an explicit bounded canvas or dashboard |
| [Goals/CreateGoalView.swift](../NutriPulse/Features/Goals/CreateGoalView.swift) | Uses shared form/subpage width limit |
| [Goals/ExperimentDetailView.swift](../NutriPulse/Features/Goals/ExperimentDetailView.swift) | Has an explicit bounded canvas or dashboard |
| [Goals/ExperimentsView.swift](../NutriPulse/Features/Goals/ExperimentsView.swift) | Uses shared form/subpage width limit |
| [Goals/GoalsView.swift](../NutriPulse/Features/Goals/GoalsView.swift) | Has an explicit bounded canvas or dashboard |
| [Medications/MedicationViews.swift](../NutriPulse/Features/Medications/MedicationViews.swift) | Uses shared form/subpage width limit |
| [Onboarding/OnboardingComponents.swift](../NutriPulse/Features/Onboarding/OnboardingComponents.swift) | Has an explicit bounded canvas or dashboard |
| [Onboarding/OnboardingSetupViews.swift](../NutriPulse/Features/Onboarding/OnboardingSetupViews.swift) | Has an explicit bounded canvas or dashboard |
| [Onboarding/OnboardingView.swift](../NutriPulse/Features/Onboarding/OnboardingView.swift) | Has an explicit bounded canvas or dashboard |
| [Onboarding/Steps/SummaryStepView.swift](../NutriPulse/Features/Onboarding/Steps/SummaryStepView.swift) | Bounded by onboarding page container |
| [Profile/AboutYouView.swift](../NutriPulse/Features/Profile/AboutYouView.swift) | Has an explicit bounded canvas or dashboard |
| [Profile/FoodAIConsentSheet.swift](../NutriPulse/Features/Profile/FoodAIConsentSheet.swift) | Has an explicit bounded canvas or dashboard |
| [Profile/FoodAccessPreferencesView.swift](../NutriPulse/Features/Profile/FoodAccessPreferencesView.swift) | Uses shared form/subpage width limit |
| [Profile/ProfileView.swift](../NutriPulse/Features/Profile/ProfileView.swift) | Uses shared form/subpage width limit |
| [Profile/PulseConsentSheet.swift](../NutriPulse/Features/Profile/PulseConsentSheet.swift) | Has an explicit bounded canvas or dashboard |
| [Profile/SendFeedbackSheet.swift](../NutriPulse/Features/Profile/SendFeedbackSheet.swift) | Uses shared form/subpage width limit |
| [Profile/SmartNotificationViews.swift](../NutriPulse/Features/Profile/SmartNotificationViews.swift) | Uses shared form/subpage width limit |
| [Progress/ProgressView.swift](../NutriPulse/Features/Progress/ProgressView.swift) | Uses shared form/subpage width limit |
| [StrongWeek/StrongWeekFeedbackView.swift](../NutriPulse/Features/StrongWeek/StrongWeekFeedbackView.swift) | Uses shared form/subpage width limit |
| [StrongWeek/StrongWeekView.swift](../NutriPulse/Features/StrongWeek/StrongWeekView.swift) | Uses shared form/subpage width limit |
| [Today/BodyCompositionSheet.swift](../NutriPulse/Features/Today/BodyCompositionSheet.swift) | Uses shared form/subpage width limit |
| [Today/Components/EditFoodLogSheet.swift](../NutriPulse/Features/Today/Components/EditFoodLogSheet.swift) | Uses shared form/subpage width limit |
| [Today/Components/HealthPatternsView.swift](../NutriPulse/Features/Today/Components/HealthPatternsView.swift) | Has an explicit bounded canvas or dashboard |
| [Today/Components/MealSectionView.swift](../NutriPulse/Features/Today/Components/MealSectionView.swift) | Embedded in Today dashboard |
| [Today/Components/RecoveryCoachCard.swift](../NutriPulse/Features/Today/Components/RecoveryCoachCard.swift) | Embedded in Today dashboard; its scroll is a horizontal repeat-meal row |
| [Today/Components/TodayTiles.swift](../NutriPulse/Features/Today/Components/TodayTiles.swift) | Has an explicit bounded canvas or dashboard |
| [Today/Components/TodayHeaderView.swift](../NutriPulse/Features/Today/Components/TodayHeaderView.swift) | Day picker has a bounded scrolling calendar so lower weeks remain reachable |
| [Today/Components/WaterPickerSheet.swift](../NutriPulse/Features/Today/Components/WaterPickerSheet.swift) | Has an explicit bounded canvas or dashboard |
| [Today/OffScriptSheet.swift](../NutriPulse/Features/Today/OffScriptSheet.swift) | Has an explicit bounded canvas or dashboard |
| [Today/TodayView.swift](../NutriPulse/Features/Today/TodayView.swift) | Has an explicit bounded canvas or dashboard |
| [Today/WorkoutEntrySheet.swift](../NutriPulse/Features/Today/WorkoutEntrySheet.swift) | Uses shared form/subpage width limit |
| [Tracking/LighterTrackingSheet.swift](../NutriPulse/Features/Tracking/LighterTrackingSheet.swift) | Has an explicit bounded canvas or dashboard |

The full 2026-11-08 audit also checks nested sheets individually, including non-scrolling App recovery states. See [full screen audit](duo-full-screen-audit.md). A file's main width policy does not automatically cover every sheet declared inside it.
