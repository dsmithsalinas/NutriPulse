# Everyday tools and Siri

Implemented October 19, 2026, before the next TestFlight build.

## Entry points

Today → **Make today easier** opens four compact tools:

- **Try:** one small experiment, without an active goal prerequisite. An explicit tried/not-tried observation plus a subjective 1–5 rating can be saved or updated for today. Blank days remain unknown. Both groups need at least three explicit observations before the descriptive comparison appears; comparisons never claim causation. Pause/resume, finish while preserving observations, remove observations, delete, and a user-initiated **Reflect with Pulse** handoff are available. Existing detailed goal-linked experiments remain available separately.
- **Keep:** a situation and what helped are composed into an editable proposal. **Review before remembering** opens the existing explicit approval flow. The account-owned practical memory library supports edit/forget and is used by Pulse’s existing server context. Nothing is silently promoted from an experiment or a meal note.
- **Save:** “Had some · Saved the rest” creates a qualitative meal note and a leftovers card. “Finished the rest” creates a separate qualitative note, never a second numeric portion. Stable note IDs, durable pending status and the original requested finish date make retries safe across restarts. “Undo finished” uses the existing note outbox deletion. Removing a reminder leaves its notes intact, as stated in the UI. No food-storage safety advice is generated.
- **Decide:** food, movement or one grocery addition; constraints are saved per category. A user action sends one narrow request to Pulse through the existing enabled/consent gate. “Ask for a different option” refers to the prior conversation; “Done with this decision” clears the draft without claiming food/activity completion. Pulse answers in its existing chat, rather than in a second chat UI.

Experiments, leftovers cards and decision drafts are **device-only** in this version. The screen explicitly says they do not sync across devices. Separate account files use atomic writes and complete file protection. A failed read blocks replacement, and the screen provides Retry. Auth switches clear in-memory state and rotate a generation token, including A→B→A. Account deletion removes the local file. None of this new local data is automatically sent to Pulse. Meal/day notes and approved memories retain their existing cloud sync/RLS.

No additional proactive notifications, medication recommendations, inferred nutrition, goal grading or catch-up obligations are added.

## Siri

Profile → **Siri and shortcuts** contains the supported starter phrases and Apple’s native Shortcuts link.

New app intents:

- **Record water:** asks for amount and unit, validates 1–3,000 ml equivalent, confirms, then commits to the existing local water outbox. Supports ml and US fluid ounces. A failed local write throws and does not claim success. Entries appear in removable water history in the water picker.
- **Save a quick note:** validates 1–1,000 Unicode scalars, confirms the text, then saves a qualitative day note to the existing durable note outbox. No nutrition or approved memory is created.
- **Today went sideways:** opens the existing three-option off-script screen.

The two direct saves require system authentication, capture the signed-in owner before confirmation and check it again before writing. Siri does not mark a medication dose taken. Existing water/favorite/food/dose quick actions remain available. App intents live in the app target, sharing its initialized SwiftData store and signed-in Supabase client; no separate extension credential store is introduced.

Use “Record water in Footing” and answer the parameters, or configure an action in Shortcuts. Arbitrary free-form command recognition, speech accuracy and locked-device confirmation still require a physical iPhone check; simulator tests do not establish those behaviors.

## Verification

`EverydayToolsTests.swift` covers missing-day semantics, bounded descriptive comparisons, stable leftover note identity, decision scope, water conversions/invalid values, protected file restart, account separation, A→B→A generation fencing, deletion cleanup, and preserving unreadable local files.

Verification: 472 iOS tests executed, 465 passed, 7 opt-in live checks skipped, 0 failures. The compiled App Intents metadata contains all three new intents with authentication required; water and note saves have `openAppWhenRun = false`. Four production-view read-only previews were inspected on the disposable simulator. Final copy/lifecycle refinements passed all 10 focused tests and a fresh app build. Final screen captures: `/private/tmp/footing-tools-try.png`, `/private/tmp/footing-tools-keep.png`, `/private/tmp/footing-tools-save.png`, `/private/tmp/footing-tools-decide.png`. No database migration, Pulse server deployment, TestFlight archive or upload is part of this change.

Read-only Debug fixtures: `--everyday-tools-preview`, with optional `--tools-library`, `--tools-leftovers`, or `--tools-decision`. Fixtures use the production views, disable all interaction, skip auth observation and memory network loads, and never write a personal account’s data.
