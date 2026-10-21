# Start with what matters — implementation

October 21, 2026. Selected visual: `marketing/onboarding-review-2026-10-20/mockups/02-start-with-what-matters-revised.png`.

New accounts see five app-owned screens after authentication:

1. Choose support with the current living-dot wordmark and approved Cove artwork. Confirm adult eligibility before continuing to personal health details.
2. Optionally describe a personal focus in up to 300 Unicode scalars. The selected support changes the prompt. Typing creates only a local in-memory draft; no provider call or durable memory.
3. Enter the grouped profile details used by the existing GoalCalculator, including imperial/metric inputs. The date picker and save validation require adulthood. Estimates are editable later.
4. Choose Pulse permission. “Review & allow Pulse” opens the existing full disclosure, with the provider, data categories, privacy policy, and explicit server-backed consent action. Continuing without Pulse saves a decline and keeps normal tracking available. Food AI consent remains separate at first use.
5. Review the exact full focus text and three optional shortcuts: nutrition targets, the focus draft, and Apple Health. The primary action explicitly saves focus only when Pulse permission is active and the focus is nonempty. Starting without saving creates no memory. Skipping an empty focus or declining Pulse gives “Start with today.”

Targets can be reviewed or edited without another mandatory screen. Numeric edit buffers update the model as typed; invalid/empty targets block completion with an explanation. Apple Health can be requested from the final screen or later in Profile; the result does not claim to know private read grants. Shot tracking and food preferences remain available later in Profile.

## Persistence and accounts

The existing daily-goal, weight-log and profile writes remain. Profile full_name is still committed last, preserving the existing completion gate and keeping returning accounts out of onboarding. No onboarding-completion schema change is necessary because every new user still supplies the required basic profile. Existing complete profiles are returned without changing their setup.

Only the explicit save-focus action writes an approved `pulse_memories` row. Its UUID stays stable for the view model's lifetime. Before saving, the repository checks for the same approved content on the current account, so a fresh app run after an interrupted finish cannot encounter a duplicate-content conflict. A subsequent skip removes only the focus created by that same setup attempt; it does not delete a pre-existing memory. Failures remain retryable, rather than silently claiming the save succeeded.

The onboarding view is keyed to the authenticated user and discards drafts on account change. The production repository checks the current session before memory writes/deletes. Completion checks the expected session and applies the saved profile only to that account. These use the existing owner-based RLS policies; a read-only check on project dcabdzuhuixlcgwavtsc confirmed SELECT/INSERT/UPDATE/DELETE ownership policies and RLS enabled for pulse_memories and pulse_profiles. No schema or server-function deployment was made.

## Brand and evidence

CoveOnboarding is an unchanged copy of the owner-approved `marketing/characters/cove/pose-library-v2-1/png/07-wry-front.png`. It is decorative, never the coach or a navigation control. Existing light/dark FootingWordmark assets are used in onboarding and the loading state. No new character or logo art was generated.

Actual simulator captures and the combined source/implementation comparison are under `marketing/onboarding-review-2026-10-20/implemented/`. The app uses live SwiftUI controls, existing Theme tokens, Bricolage/Figtree fonts, and SF Symbols. System status/safe areas remain native. The full source focus is preserved rather than shortened to the illustrative quote in the mockup.

Validation: 498 unit tests executed, 491 passed, seven optional live checks skipped. Three simulator UI tests cover all five screens, adult confirmation, skipping/declining, editing targets, editing focus with the keyboard, the Health shortcut in a no-write fixture, full privacy-disclosure presentation, and the largest accessibility text size. The no-account fixture never records consent, saves data, requests Health authorization, or calls AI. Physical-device Apple Health authorization and a fresh signed-in onboarding write were not performed in this pass. No TestFlight build or upload was made.
