# Full Duo screen audit

2026-11-08

Source checks covered every SwiftUI view file under App and Features for width/scroll policy and fixed-size risks, including nested sheets and recovery states. Each active screen family was then reviewed with simulator captures. The simulator gallery opens production views with local/read-only inputs. It never submits authentication, grants permissions/consent, sends feedback or chat, saves food/doses, or resolves conflicts. Width/scroll policies are source evidence; they are not physical Duo certification.

## Findings addressed

1. Calendar: lower weeks were cut off in landscape. The calendar now scrolls inside a 600 pt canvas; Cancel and Done stay in the navigation bar.
2. Profile recovery: largest text clipped the connection message and Sign Out. The recovery content now scrolls in a bounded canvas. Startup loading/offline-note access uses the same bounded scrolling approach.
3. Feedback: large segmented labels exceeded their track. Larger text uses stacked category choices; the message editor has keyboard Done.
4. Completed goals: fixed 148 × 100 pt cards clipped names, dates and results. Cards grow with content; the full completed list uses one column for large text.
5. Nested canvases: medication settings/editor/correction/conflict review, goal detail/day detail/completed list, experiment list, notification explainer, saved memories/data, and onboarding focus editing now have explicit width limits. Existing actions and ownership/save guards remain intact.

## Source coverage

The table includes embedded components and legacy onboarding components as well as active screen entry points. Embedded children inherit their host proposal; an independent width cap is not appropriate for every card. Legacy onboarding step components and splash have no active route in the current five-step onboarding flow.

| Source | Views inspected |
| --- | --- |
| [Analytics/AnalyticsInsightCards.swift](../NutriPulse/Features/Analytics/AnalyticsInsightCards.swift) | CycleAwareAnalyticsCard |
| [Analytics/AnalyticsView.swift](../NutriPulse/Features/Analytics/AnalyticsView.swift) | AnalyticsView, AnalyticsQuestionCard, AnalyticsSummaryCard, CaloriesChartContent, MacrosChartContent, MovementChartContent, BodyFatChartContent, ProteinSourcesChart, WeightTrendChart |
| [Auth/AuthView.swift](../NutriPulse/Features/Auth/AuthView.swift) | AuthView |
| [Auth/ForgotPasswordView.swift](../NutriPulse/Features/Auth/ForgotPasswordView.swift) | ForgotPasswordView |
| [Auth/ResetPasswordView.swift](../NutriPulse/Features/Auth/ResetPasswordView.swift) | ResetPasswordView |
| [Body/BodyGoalsSheet.swift](../NutriPulse/Features/Body/BodyGoalsSheet.swift) | BodyGoalsSheet |
| [Body/BodyHubView.swift](../NutriPulse/Features/Body/BodyHubView.swift) | BodyHubView |
| [Body/BodyMetricHistoryView.swift](../NutriPulse/Features/Body/BodyMetricHistoryView.swift) | BodyMetricHistoryView |
| [Coach/CoachView.swift](../NutriPulse/Features/Coach/CoachView.swift) | CoachView, MessageBubble, FoodSuggestionCards, FoodSuggestionCard, RememberSuggestionCards, RememberSuggestionCard, RecapCard, WeeklyProteinBars, PulseAvatar, PulseTypingIndicator |
| [Coach/HealthInsightStyle.swift](../NutriPulse/Features/Coach/HealthInsightStyle.swift) | HealthMetricTile, HealthSummaryCard |
| [Coach/PulseMemoryViews.swift](../NutriPulse/Features/Coach/PulseMemoryViews.swift) | PulseAttentionSection, PulseMemoriesSection, PulseMemoryEditor |
| [EverydayTools/EasierDayRecipeView.swift](../NutriPulse/Features/EverydayTools/EasierDayRecipeView.swift) | EasierDayRecipeView |
| [EverydayTools/EverydayToolsView.swift](../NutriPulse/Features/EverydayTools/EverydayToolsView.swift) | EverydayToolsView |
| [EverydayTools/ExperimentHealthCard.swift](../NutriPulse/Features/EverydayTools/ExperimentHealthCard.swift) | ExperimentHealthCard, ExperimentHealthDetailView, ExperimentObservationEditor, ExperimentHealthLinkEditor |
| [EverydayTools/ExperimentWrapUpView.swift](../NutriPulse/Features/EverydayTools/ExperimentWrapUpView.swift) | ExperimentWrapUpView |
| [FoodLogging/BarcodeScanView.swift](../NutriPulse/Features/FoodLogging/BarcodeScanView.swift) | BarcodeScanView, ViewfinderOverlay |
| [FoodLogging/BreakfastCheckinViews.swift](../NutriPulse/Features/FoodLogging/BreakfastCheckinViews.swift) | BreakfastCheckinSettings, BreakfastCheckinCard |
| [FoodLogging/Components/FatSecretAttribution.swift](../NutriPulse/Features/FoodLogging/Components/FatSecretAttribution.swift) | FatSecretAttribution |
| [FoodLogging/Components/FavoriteStar.swift](../NutriPulse/Features/FoodLogging/Components/FavoriteStar.swift) | FavoriteStar |
| [FoodLogging/Components/LogSheetChrome.swift](../NutriPulse/Features/FoodLogging/Components/LogSheetChrome.swift) | LogSheetHeader, LogTabBar |
| [FoodLogging/FamiliarFoodReview.swift](../NutriPulse/Features/FoodLogging/FamiliarFoodReview.swift) | FamiliarFoodReview |
| [FoodLogging/FavoritesView.swift](../NutriPulse/Features/FoodLogging/FavoritesView.swift) | FavoritesView, FavoriteTile, RecentRow |
| [FoodLogging/FoodLoggingView.swift](../NutriPulse/Features/FoodLogging/FoodLoggingView.swift) | FoodLoggingView |
| [FoodLogging/FoodSearchView.swift](../NutriPulse/Features/FoodLogging/FoodSearchView.swift) | FoodSearchView, SearchResultRow, FoodDetailSheet, MacroPreviewRow |
| [FoodLogging/ManualEntryView.swift](../NutriPulse/Features/FoodLogging/ManualEntryView.swift) | ManualEntryView, MacroField |
| [FoodLogging/MealNoteSheet.swift](../NutriPulse/Features/FoodLogging/MealNoteSheet.swift) | MealNoteSheet |
| [FoodLogging/OfflineMealNotesView.swift](../NutriPulse/Features/FoodLogging/OfflineMealNotesView.swift) | OfflineMealNotesView |
| [FoodLogging/ProteinRescueSheet.swift](../NutriPulse/Features/FoodLogging/ProteinRescueSheet.swift) | ProteinRescueSheet |
| [FoodLogging/RepeatedMealConfirmationSheet.swift](../NutriPulse/Features/FoodLogging/RepeatedMealConfirmationSheet.swift) | RepeatedMealConfirmationSheet |
| [FoodLogging/RestaurantLoggingViews.swift](../NutriPulse/Features/FoodLogging/RestaurantLoggingViews.swift) | RestaurantContextBar, RestaurantPickerView, RestaurantClarificationView, RestaurantIngredientChecklist |
| [FoodLogging/TalkToLogView.swift](../NutriPulse/Features/FoodLogging/TalkToLogView.swift) | TalkToLogView, MicPulseRing, ConfirmRowView |
| [FoodLogging/UsualMealViews.swift](../NutriPulse/Features/FoodLogging/UsualMealViews.swift) | SaveUsualMealSheet, UsualMealsSection, UsualMealReview |
| [GLP1/AuroraView.swift](../NutriPulse/Features/GLP1/AuroraView.swift) | AuroraView |
| [GLP1/GLP1TrackerView.swift](../NutriPulse/Features/GLP1/GLP1TrackerView.swift) | GLP1TrackerView, DoseSkipControl |
| [GLP1/HoldToConfirmButton.swift](../NutriPulse/Features/GLP1/HoldToConfirmButton.swift) | HoldToConfirmButton |
| [GLP1/InjectionRitualView.swift](../NutriPulse/Features/GLP1/InjectionRitualView.swift) | InjectionRitualView, OrbitRing |
| [GLP1/ShotCycleCheckInSheet.swift](../NutriPulse/Features/GLP1/ShotCycleCheckInSheet.swift) | ShotCycleCheckInSheet, CheckInScale, ShotCyclePlanCard |
| [Goals/CreateGoalView.swift](../NutriPulse/Features/Goals/CreateGoalView.swift) | CreateGoalView |
| [Goals/ExperimentDetailView.swift](../NutriPulse/Features/Goals/ExperimentDetailView.swift) | ExperimentDetailView |
| [Goals/ExperimentsView.swift](../NutriPulse/Features/Goals/ExperimentsView.swift) | ExperimentsView, CreateExperimentView |
| [Goals/GoalsView.swift](../NutriPulse/Features/Goals/GoalsView.swift) | GoalsView, ExperimentTile, GoalCompactRow, CompletedGoalsView, GoalTrophyTile, ProteinFloorCard, GoalHeroCard, GoalDayDetailView, GoalAutomaticProgress, GoalDetailContainer, GoalDetailView |
| [Medications/MedicationViews.swift](../NutriPulse/Features/Medications/MedicationViews.swift) | MedicationSettingsView, MedicationEditorView, MedicationTodaySection, MedicationDoseRow, MedicationHistoryView, MedicationCorrectionView, MedicationStoreStatusView, MedicationConflictReviewView, MedicationReminderStatusView, MedicationErrorText |
| [Onboarding/OnboardingComponents.swift](../NutriPulse/Features/Onboarding/OnboardingComponents.swift) | DrawablePulseMark, OnboardingPulseAvatar, OnboardingProgressDots, NarratedStepLayout, OnboardingOptionCard, OnboardingPill, OnboardingSegmented, OnboardingAuroraWash |
| [Onboarding/OnboardingSetupViews.swift](../NutriPulse/Features/Onboarding/OnboardingSetupViews.swift) | OnboardingBasicsView, OnboardingTargetsView, OnboardingNumberField |
| [Onboarding/OnboardingSplashView.swift](../NutriPulse/Features/Onboarding/OnboardingSplashView.swift) | OnboardingSplashView |
| [Onboarding/OnboardingView.swift](../NutriPulse/Features/Onboarding/OnboardingView.swift) | OnboardingView |
| [Onboarding/Steps/ActivityStepView.swift](../NutriPulse/Features/Onboarding/Steps/ActivityStepView.swift) | ActivityStepView |
| [Onboarding/Steps/BiologicalSexStepView.swift](../NutriPulse/Features/Onboarding/Steps/BiologicalSexStepView.swift) | BiologicalSexStepView |
| [Onboarding/Steps/DobStepView.swift](../NutriPulse/Features/Onboarding/Steps/DobStepView.swift) | DobStepView |
| [Onboarding/Steps/GLP1SetupStepView.swift](../NutriPulse/Features/Onboarding/Steps/GLP1SetupStepView.swift) | GLP1SetupStepView |
| [Onboarding/Steps/GoalStepView.swift](../NutriPulse/Features/Onboarding/Steps/GoalStepView.swift) | GoalStepView |
| [Onboarding/Steps/HealthKitStepView.swift](../NutriPulse/Features/Onboarding/Steps/HealthKitStepView.swift) | HealthKitStepView |
| [Onboarding/Steps/HeightWeightStepView.swift](../NutriPulse/Features/Onboarding/Steps/HeightWeightStepView.swift) | HeightWeightStepView, MeasureField |
| [Onboarding/Steps/NameStepView.swift](../NutriPulse/Features/Onboarding/Steps/NameStepView.swift) | NameStepView |
| [Onboarding/Steps/PulseAboutYouStepView.swift](../NutriPulse/Features/Onboarding/Steps/PulseAboutYouStepView.swift) | PulseAboutYouStepView |
| [Onboarding/Steps/SummaryStepView.swift](../NutriPulse/Features/Onboarding/Steps/SummaryStepView.swift) | SummaryStepView |
| [Profile/AboutYouView.swift](../NutriPulse/Features/Profile/AboutYouView.swift) | AboutYouView, ToggleChip, RemovableChip, AddChipField |
| [Profile/FoodAIConsentSheet.swift](../NutriPulse/Features/Profile/FoodAIConsentSheet.swift) | FoodAIConsentSheet |
| [Profile/FoodAccessPreferencesView.swift](../NutriPulse/Features/Profile/FoodAccessPreferencesView.swift) | FoodAccessPreferencesView |
| [Profile/FootingSiriSection.swift](../NutriPulse/Features/Profile/FootingSiriSection.swift) | FootingSiriSection |
| [Profile/GLP1HistoryView.swift](../NutriPulse/Features/Profile/GLP1HistoryView.swift) | GLP1HistoryView |
| [Profile/ProfileView.swift](../NutriPulse/Features/Profile/ProfileView.swift) | ProfileView, SettingsTile, EditProfileSheet, EditGoalsSheet, LogInjectionSheet, SmartNotificationExplainerSheet |
| [Profile/PulseConsentSheet.swift](../NutriPulse/Features/Profile/PulseConsentSheet.swift) | PulseConsentSheet |
| [Profile/SendFeedbackSheet.swift](../NutriPulse/Features/Profile/SendFeedbackSheet.swift) | SendFeedbackSheet |
| [Profile/SmartNotificationViews.swift](../NutriPulse/Features/Profile/SmartNotificationViews.swift) | SmartNotificationSettingsView, SmartNotificationHistoryView |
| [Progress/ProgressView.swift](../NutriPulse/Features/Progress/ProgressView.swift) | ProgressDashboardView, FloorDaysHero, FloorDaysGraphic, Sparkline, AvgProteinStatTile, WeightTrendStatTile, MovedStatTile, LoggedStatTile, NoticeTile, ProgressDestinationRow, ProgressSummariesView, SummaryTimelineGraphic, ProgressLegend, SummaryReviewCard, ProgressHistoryRow |
| [StrongWeek/StrongWeekFeedbackView.swift](../NutriPulse/Features/StrongWeek/StrongWeekFeedbackView.swift) | StrongWeekFeedbackView, RatingChip |
| [StrongWeek/StrongWeekView.swift](../NutriPulse/Features/StrongWeek/StrongWeekView.swift) | StrongWeekCard, StrongWeekView, CircumstanceChip |
| [Today/BodyCompositionSheet.swift](../NutriPulse/Features/Today/BodyCompositionSheet.swift) | BodyCompositionSheet |
| [Today/Components/BodyCompositionCard.swift](../NutriPulse/Features/Today/Components/BodyCompositionCard.swift) | BodyCompositionCard |
| [Today/Components/CycleFitCard.swift](../NutriPulse/Features/Today/Components/CycleFitCard.swift) | CycleFitCard |
| [Today/Components/DoseDayCard.swift](../NutriPulse/Features/Today/Components/DoseDayCard.swift) | DoseDayCard, CompletedCheck, PulseDot |
| [Today/Components/EditFoodLogSheet.swift](../NutriPulse/Features/Today/Components/EditFoodLogSheet.swift) | EditFoodLogSheet |
| [Today/Components/FirstDayChecklist.swift](../NutriPulse/Features/Today/Components/FirstDayChecklist.swift) | FirstDayChecklistCard |
| [Today/Components/GentlerDayCard.swift](../NutriPulse/Features/Today/Components/GentlerDayCard.swift) | GentlerDayCard |
| [Today/Components/HealthPatternsView.swift](../NutriPulse/Features/Today/Components/HealthPatternsView.swift) | HealthPatternsView |
| [Today/Components/HealthStatsCard.swift](../NutriPulse/Features/Today/Components/HealthStatsCard.swift) | HealthStatsCard |
| [Today/Components/HomeSupportActions.swift](../NutriPulse/Features/Today/Components/HomeSupportActions.swift) | HomeSupportActions |
| [Today/Components/LowAppetitePreparationCard.swift](../NutriPulse/Features/Today/Components/LowAppetitePreparationCard.swift) | LowAppetitePreparationCard, ShotCycleCheckInCard |
| [Today/Components/MealSectionView.swift](../NutriPulse/Features/Today/Components/MealSectionView.swift) | MealSectionView, FoodLogRowView, SwipeToDeleteRow |
| [Today/Components/MovementCard.swift](../NutriPulse/Features/Today/Components/MovementCard.swift) | MovementCard |
| [Today/Components/RecoveryCoachCard.swift](../NutriPulse/Features/Today/Components/RecoveryCoachCard.swift) | RecoveryCoachCard, RepeatYesterdayCard |
| [Today/Components/RecoveryContextCard.swift](../NutriPulse/Features/Today/Components/RecoveryContextCard.swift) | RecoveryContextCard |
| [Today/Components/RetargetCard.swift](../NutriPulse/Features/Today/Components/RetargetCard.swift) | RetargetCard |
| [Today/Components/TodayHeaderView.swift](../NutriPulse/Features/Today/Components/TodayHeaderView.swift) | TodayHeaderView, DatePickerSheet |
| [Today/Components/TodayTiles.swift](../NutriPulse/Features/Today/Components/TodayTiles.swift) | ProteinTile, FloorClearedFizz, FizzBubble, LiquidFill, CaloriesTile, ShotCycleTile, WaterTile, MovedTile, MovementSheet, SheetHeader |
| [Today/Components/UnderEatingNudgeCard.swift](../NutriPulse/Features/Today/Components/UnderEatingNudgeCard.swift) | UnderEatingNudgeCard |
| [Today/Components/WaterPickerSheet.swift](../NutriPulse/Features/Today/Components/WaterPickerSheet.swift) | WaterPickerSheet |
| [Today/OffScriptSheet.swift](../NutriPulse/Features/Today/OffScriptSheet.swift) | OffScriptSheet |
| [Today/TodayView.swift](../NutriPulse/Features/Today/TodayView.swift) | TodayView, SyncStatusBanner, EmptyDayView, ReturnToTodayCard |
| [Today/WorkoutEntrySheet.swift](../NutriPulse/Features/Today/WorkoutEntrySheet.swift) | WorkoutEntrySheet |
| [Tracking/LighterTrackingSheet.swift](../NutriPulse/Features/Tracking/LighterTrackingSheet.swift) | LighterTrackingSheet |

App-level coverage: Root loading, profile-load recovery, authentication/recovery routing, main tabs, reserved expanded navigation rail and portrait bottom bar. Widget source under Shared/NutriPulseWidgets is system-family driven and was inspected separately; Home Screen/Lock Screen rendering remains a device check.

## Evidence limits

The installed simulator is an iPhone 17 Pro on iOS 26.5, using portrait and an 874 × 402 pt expanded window. A physical Duo profile is not installed. Native system alerts, permission sheets and keyboard behavior depend on the OS. Live authenticated histories, network loading/error variations, actual Health/camera/microphone access, notifications, save/undo during a display transition and physical fold/unfold still require device verification. The gallery's empty/error states do not prove the populated authenticated variants.

## Verification results

54 distinct checks passed across the final verification runs: 45 UI checks and 9 layout/rendering checks. Debug and unsigned simulator Release builds succeeded. Early failures exposed feedback menu placement and an action-test gesture outside the active scroll content; the final stacked choices and corrected action checks passed. The calendar test selects the last week of the previous month and retains that selection through rotation. Medication and feedback drafts retain edits; all three feedback categories remain visible with at least 44 pt targets at the largest text size.

The gallery includes 59 audit entry points plus main-app regression captures, populated analytics/body-history fixtures, keyboard, permission/error and large-text states. Populated chart fixtures validate rendering, not live Health/backend accuracy.

[Open the full screenshot gallery](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/index.html) — changed screens are shown first; turn off the filter to see all captures.

## Captured steps

Each row describes a captured state rather than claiming every live-data variant is covered. The source inventory above also includes embedded and inactive legacy components.

| Step | State | Layout health | Screenshot |
| --- | --- | --- | --- |
| 1 | 01-health-link | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/01-health-link.png) |
| 2 | 01-pulse-summary-cards | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/01-pulse-summary-cards.png) |
| 3 | 01-support | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/01-support.png) |
| 4 | 01-tools | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/01-tools.png) |
| 5 | 02-experiment | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/02-experiment.png) |
| 6 | 02-experiment-detail | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/02-experiment-detail.png) |
| 7 | 02-focus | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/02-focus.png) |
| 8 | 03-basics | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/03-basics.png) |
| 9 | 03-experiment-from-pulse | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/03-experiment-from-pulse.png) |
| 10 | 03-memory | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/03-memory.png) |
| 11 | 04-cycle-detail | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/04-cycle-detail.png) |
| 12 | 04-leftovers | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/04-leftovers.png) |
| 13 | 04-permission | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/04-permission.png) |
| 14 | 05-decision | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/05-decision.png) |
| 15 | 05-ready | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/05-ready.png) |
| 16 | 05-week-detail | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/05-week-detail.png) |
| 17 | 06-edit-targets | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/06-edit-targets.png) |
| 18 | 06-large-text | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/06-large-text.png) |
| 19 | 06-large-text-week | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/06-large-text-week.png) |
| 20 | 07-no-pulse | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/07-no-pulse.png) |
| 21 | 08-focus-keyboard | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/08-focus-keyboard.png) |
| 22 | 09-large-text-permission | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/09-large-text-permission.png) |
| 23 | 10-privacy-disclosure | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/10-privacy-disclosure.png) |
| 24 | audit-about-you | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-about-you.png) |
| 25 | audit-action-auth | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-action-auth.png) |
| 26 | audit-action-medication-editor | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-action-medication-editor.png) |
| 27 | audit-action-password-help | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-action-password-help.png) |
| 28 | audit-action-password-reset | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-action-password-reset.png) |
| 29 | audit-action-usual-save | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-action-usual-save.png) |
| 30 | audit-analytics | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-analytics.png) |
| 31 | audit-analytics-0 | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-analytics-0.png) |
| 32 | audit-analytics-1 | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-analytics-1.png) |
| 33 | audit-analytics-2 | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-analytics-2.png) |
| 34 | audit-analytics-3 | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-analytics-3.png) |
| 35 | audit-analytics-4 | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-analytics-4.png) |
| 36 | audit-analytics-5 | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-analytics-5.png) |
| 37 | audit-auth | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-auth.png) |
| 38 | audit-body | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-body.png) |
| 39 | audit-body-entry | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-body-entry.png) |
| 40 | audit-body-goals | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-body-goals.png) |
| 41 | audit-breakfast-settings | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-breakfast-settings.png) |
| 42 | audit-calendar | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-calendar.png) |
| 43 | audit-calendar-last-week | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-calendar-last-week.png) |
| 44 | audit-dose-edit | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-dose-edit.png) |
| 45 | audit-dose-history | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-dose-history.png) |
| 46 | audit-edit-food | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-edit-food.png) |
| 47 | audit-error-dose-history | Error/recovery variant; live account data not verified | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-error-dose-history.png) |
| 48 | audit-experiment-create | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-experiment-create.png) |
| 49 | audit-experiment-wrap | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-experiment-wrap.png) |
| 50 | audit-experiments | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-experiments.png) |
| 51 | audit-fat-history | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-fat-history.png) |
| 52 | audit-feedback | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-feedback.png) |
| 53 | audit-feedback-draft | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-feedback-draft.png) |
| 54 | audit-food-access | Error/recovery variant; live account data not verified | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-food-access.png) |
| 55 | audit-food-consent | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-food-consent.png) |
| 56 | audit-goal-builder | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-goal-builder.png) |
| 57 | audit-goal-completed | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-goal-completed.png) |
| 58 | audit-goal-day | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-goal-day.png) |
| 59 | audit-goal-detail | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-goal-detail.png) |
| 60 | audit-health-link | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-health-link.png) |
| 61 | audit-large-body-entry | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-body-entry.png) |
| 62 | audit-large-calendar | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-calendar.png) |
| 63 | audit-large-feedback | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-feedback.png) |
| 64 | audit-large-goal-completed | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-goal-completed.png) |
| 65 | audit-large-loading | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-loading.png) |
| 66 | audit-large-medication-conflict | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-medication-conflict.png) |
| 67 | audit-large-medication-editor | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-medication-editor.png) |
| 68 | audit-large-notification-explainer | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-notification-explainer.png) |
| 69 | audit-large-profile-recovery | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-profile-recovery.png) |
| 70 | audit-large-recovery-actions | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-recovery-actions.png) |
| 71 | audit-large-shot-check-in | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-shot-check-in.png) |
| 72 | audit-large-tools-data | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-large-tools-data.png) |
| 73 | audit-lean-history | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-lean-history.png) |
| 74 | audit-lighter-tracking | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-lighter-tracking.png) |
| 75 | audit-loading | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-loading.png) |
| 76 | audit-medication-conflict | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-medication-conflict.png) |
| 77 | audit-medication-correction | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-medication-correction.png) |
| 78 | audit-medication-draft | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-medication-draft.png) |
| 79 | audit-medication-editor | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-medication-editor.png) |
| 80 | audit-medication-history | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-medication-history.png) |
| 81 | audit-medications | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-medications.png) |
| 82 | audit-memory-editor | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-memory-editor.png) |
| 83 | audit-notification-explainer | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-notification-explainer.png) |
| 84 | audit-notification-history | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-notification-history.png) |
| 85 | audit-notifications | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-notifications.png) |
| 86 | audit-observation | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-observation.png) |
| 87 | audit-offline-notes | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-offline-notes.png) |
| 88 | audit-onboarding-focus | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-onboarding-focus.png) |
| 89 | audit-password-help | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-password-help.png) |
| 90 | audit-password-reset | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-password-reset.png) |
| 91 | audit-profile-edit | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-profile-edit.png) |
| 92 | audit-profile-recovery | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-profile-recovery.png) |
| 93 | audit-protein-rescue | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-protein-rescue.png) |
| 94 | audit-pulse-consent | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-pulse-consent.png) |
| 95 | audit-recipe | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-recipe.png) |
| 96 | audit-restaurant-picker | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-restaurant-picker.png) |
| 97 | audit-shot-check-in | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-shot-check-in.png) |
| 98 | audit-targets-edit | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-targets-edit.png) |
| 99 | audit-tools-data | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-tools-data.png) |
| 100 | audit-tools-decision | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-tools-decision.png) |
| 101 | audit-tools-experiment | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-tools-experiment.png) |
| 102 | audit-tools-leftovers | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-tools-leftovers.png) |
| 103 | audit-tools-library | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-tools-library.png) |
| 104 | audit-tools-memories | Updated and checked | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-tools-memories.png) |
| 105 | audit-usual-review | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-usual-review.png) |
| 106 | audit-usual-save | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-usual-save.png) |
| 107 | audit-waist-history | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-waist-history.png) |
| 108 | audit-weight-history | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-weight-history.png) |
| 109 | audit-workout | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/audit-workout.png) |
| 110 | food-detail-large-text | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-detail-large-text.png) |
| 111 | food-expanded-confirmation | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-confirmation.png) |
| 112 | food-expanded-detail | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-detail.png) |
| 113 | food-expanded-familiar-review | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-familiar-review.png) |
| 114 | food-expanded-favorites | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-favorites.png) |
| 115 | food-expanded-repeat-confirmation | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-repeat-confirmation.png) |
| 116 | food-expanded-scan | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-scan.png) |
| 117 | food-expanded-scan-permission | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-scan-permission.png) |
| 118 | food-expanded-search | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-search.png) |
| 119 | food-expanded-search-keyboard | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-search-keyboard.png) |
| 120 | food-expanded-talk | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-expanded-talk.png) |
| 121 | food-favorites-large-text | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/food-favorites-large-text.png) |
| 122 | gentler-day-and-recovery | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/gentler-day-and-recovery.png) |
| 123 | health-support-large-text | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/health-support-large-text.png) |
| 124 | landscape-profile-navigation | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/landscape-profile-navigation.png) |
| 125 | landscape-search-draft | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/landscape-search-draft.png) |
| 126 | manual-expanded | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/manual-expanded.png) |
| 127 | manual-expanded-keyboard | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/manual-expanded-keyboard.png) |
| 128 | meal-note-expanded | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/meal-note-expanded.png) |
| 129 | meal-note-expanded-keyboard | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/meal-note-expanded-keyboard.png) |
| 130 | portrait-bottom-navigation | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/portrait-bottom-navigation.png) |
| 131 | profile-expanded-rail | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/profile-expanded-rail.png) |
| 132 | progress-dedicated-expanded | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/progress-dedicated-expanded.png) |
| 133 | progress-expanded-week | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/progress-expanded-week.png) |
| 134 | pulse-expanded-conversation | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/pulse-expanded-conversation.png) |
| 135 | pulse-expanded-draft | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/pulse-expanded-draft.png) |
| 136 | pulse-expanded-start | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/pulse-expanded-start.png) |
| 137 | rail-progress | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/rail-progress.png) |
| 138 | rail-pulse | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/rail-pulse.png) |
| 139 | rail-today | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/rail-today.png) |
| 140 | search-keyboard-open | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/search-keyboard-open.png) |
| 141 | shot-cycle-not-saved | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/shot-cycle-not-saved.png) |
| 142 | shot-cycle-saved | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/shot-cycle-saved.png) |
| 143 | shot-logging-expanded | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/shot-logging-expanded.png) |
| 144 | today-dedicated-expanded | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/today-dedicated-expanded.png) |
| 145 | today-paired-metrics-rail | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/today-paired-metrics-rail.png) |
| 146 | usual-meal-bookmark-dark | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/usual-meal-bookmark-dark.png) |
| 147 | usual-meal-bookmark-light | Checked captured state | [View](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/duo-audit-2026-11-08/usual-meal-bookmark-light.png) |
