# Onboarding and dose controls — November 15, 2026

The profile setup uses Daylight pill buttons for Activity, Weight direction, Sex for estimates and Units. Selected options are lime with selected accessibility traits. Options stack at accessibility text sizes, with at least 44-point touch targets. Activity retains its explanatory text.

Imperial height has independent feet and inches edit buffers; centimeters remain canonical. Empty/invalid components block continuation, inches must be below 12, and unit toggles do not rewrite an unchanged height. Height inputs stack at accessibility text sizes. Validation guidance follows the chosen unit system.

On Today's compact medication card, tapping a not-logged dose records Taken immediately through the existing store. Long-press opens Skip dose; VoiceOver also exposes Skip dose as a custom action. Tapping a completed dose opens undo/history actions. Historical dates remain review-only and conflict protection remains in force. Recording remains account-scoped and revision-checked; no medication data model or server migration changed.

Validation: the onboarding UI tests cover initial and edited feet/inches, empty/invalid inches, centimeter conversion, repeated unit changes, selected pills and the largest accessibility text size. The medication interaction test covers independent doses, single-tap Taken, long-press Skip and Undo. The normal and accessibility screenshots were inspected. Results: `build/OnboardingAllPillsVerified-20261115.xcresult` (two tests passed) and `build/MedicationTapVerified-20261115.xcresult` (one test passed). Earlier full onboarding/medication UI coverage passed all other cases; the initial undo query failure was a nested native accessibility-button match, fixed by selecting the first matching dialog button.

Source is ready for the next combined TestFlight build. No archive or TestFlight upload was made; the owner has kept the build on hold.
