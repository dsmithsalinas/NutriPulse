# Three ways to start with Footing

October 20, 2026 · Design proposals only · No onboarding code changed

**Recommendation: Start with what matters.** It establishes why the person wants Footing before asking for measurements. It gives Pulse an explicitly approved starting focus and preserves the inputs needed for meaningful targets. A warmer welcome is the smaller launch change; Try one small thing is the larger, longer-term direction.

Open `review.html` for the three final storyboards and a short comparison. Each image depicts five representative states of one flow, not five competing designs. The third storyboard's final frame is an optional later branch, not an additional gate before Today. The first storyboard omits unchanged intermediate questions.

## What I reviewed

I launched the current read-only onboarding preview and captured its actual welcome (`current/welcome.png`). I read the router, shared layouts, all step sources, completion writes, current privacy/consent work, and approved brand/character guidance. The remaining steps below are source-reviewed; this was **not a complete new physical-device walkthrough**. Native simulator UI control was unavailable in the current computer-use surface. No account, Health authorization, AI request or profile save was performed.

Current authenticated onboarding has eleven surfaces: welcome, nine question screens, and summary. Sign-in occurs before this flow.

| Step | Current surface | Assessment and useful change |
| --- | --- | --- |
| 1 | Welcome | Captured: Pulse avatar and introduction lead; Footing's new product logo and Cove are absent. Source also delays the primary button during the intro animation. Lead with Footing, explain the immediate benefit, and enable the action immediately. |
| 2 | First name | Clear single task. Retain or prefill an available first name; allow editing rather than asking twice. |
| 3 | Biological sex | Explains its role in target estimates. Keep the explanation, clarify the field's purpose, and avoid presenting an unchosen value as a decision the person made. |
| 4 | Birth date | Source picker permits ages 13–120 while the current public policy says 18+. Align eligibility and input limits before collecting health details. |
| 5 | Height and weight | Necessary for the current target estimator, but arrives before a personally meaningful goal. Explain why these are requested; keep units clear. |
| 6 | Activity | Useful for target estimates. Prefer concrete examples over ambiguous activity labels; don't add a workout questionnaire. |
| 7 | Weight direction | Covers lose/maintain/gain, but doesn't capture “what I want help with.” Add an optional, user-authored support focus without equating success with weight loss. |
| 8 | Apple Health | Optional connection has a specific benefit. Source copy says active calories count toward a net calorie goal: verify that promise against actual goal behavior before retaining it. Request access only after Connect is tapped. Don't treat an unknowable read-permission state as confirmed permission. |
| 9 | GLP-1 setup | Keep optional; avoid asking for a full medication history just to enter the app. Ask notification permission only when someone chooses a reminder. |
| 10 | Allergies / eating patterns | Useful and skippable. A natural place for the optional focus sentence in the light-refresh option. Preserve explicit allergy confirmation and reliable saving. |
| 11 | Starting targets / finish | Gives a concrete result. Describe targets as estimates, make editing easy, and distinguish creating targets from agreeing to AI or saving a lasting Pulse focus. |

Visual limits: contrast and spacing were inspected in the welcome and mockups, but VoiceOver, keyboard navigation, large text, consent cancellation, and device-size layouts still need implementation testing. Mockup numbers, form choices and saved-entry states are illustrative—not real user records or verified nutrition calculations.

## A warmer welcome — smallest change

Keep the existing question order and target calculation. Replace the Pulse-first opening with the current Footing wordmark, quiet Cove and a concise product promise. Fold an optional goal sentence into the existing “Anything Pulse should know?” step. Add a skippable Pulse permission surface near completion, followed by explicit focus approval on the existing summary.

Full route: branded welcome → existing name / sex / birth date / height-weight / activity / weight-direction questions → optional Health → optional GLP-1 → optional focus + preferences → optional Pulse disclosure → target review / explicit save-focus choice → Today.

The mock depicts welcome, name, optional context, permission and summary. The current body/activity questions remain between name and optional context; it is not a five-screen rewrite. Fewer questions is not the benefit of this option; clearer identity and agency are.

**Tradeoff:** least disruption, but people still complete a relatively long profile before experiencing Footing. If chosen, keep the permission surface optional rather than adding an unavoidable final gate.

## Start with what matters — recommended

Lead with an easy focus choice, then an optional sentence. Gather the profile inputs needed for targets in a focused grouped form. Offer Pulse with an explicit explanation, then show the starting targets and exactly what focus would be saved.

Route: choose a support focus → optional “Your goal, in your words” → profile for estimated targets → optional Pulse consent → review / save focus → Today. Food preferences, Health and medication setup stay available afterward as optional setup, with allergies checked before relevant food advice.

Example prompt: **“What would you like Pulse to help you with?”** A follow-up hint can say **“A sentence is enough. For example: simple meals and keeping my strength.”** Suggested chips reduce typing, but “Something else” and Skip remain equally usable.

**Tradeoff:** moderate implementation work and a denser form. At large text, split the form into two short pages without losing progress. The mock's age field is conceptual: use a genuine age model or retain the current DOB input; do not fabricate a birth date from an age. Example selections must not become silent defaults. Keep the complete typed focus verbatim in final review; don't silently shorten or AI-rewrite it as the storyboard's compact example quote does.

## Try one small thing — lightest entry, bigger product change

After sign-in and adult eligibility, let someone choose a small manual action: water, a meal note, or simply exploring Today. Review the action before saving and provide Undo. Then open Today with optional setup available when useful.

Route: welcome → choose one action → review and save (or skip) → Today. Optional later branches: targets, Pulse focus + disclosure, Health and GLP-1. The fifth mock frame illustrates a later Pulse setup branch, not a requirement to finish onboarding.

**Tradeoff:** biggest implementation change. A name currently marks onboarding completion; that must become an explicit completion state. Today must handle unknown/unset targets clearly, and estimated calorie/protein targets must wait until the needed profile inputs exist. No invented numbers, zero-intake claims, compulsory diary completion or forced tutorial log. Water and note branches need no AI permission.

## Where consent belongs

| Permission | Proposed moment | If declined |
| --- | --- | --- |
| Pulse AI sharing | Optional setup near completion, before the first coach request | Continue with normal tracking; offer Profile controls later |
| AI food parsing | First time Parse / AI food logging is chosen | Search, scan, usual meals and manual logging remain usable |
| Apple Health | After tapping Connect, with a specific explanation | Use manual records; don't repeatedly prompt |
| Notifications | When a particular reminder is enabled | Save the schedule without claiming notifications are enabled |
| Microphone / speech | First tap to speak a meal | Typing or non-AI logging remains available |

Do not combine these into “Accept all,” preselect consent, make access conditional on AI, or confuse tapping Continue with permission. The storyboard's short disclosure must expand into the complete, readable provider/data explanation—not hide essential categories behind a link. Reuse the independently tested account-scoped consent mechanisms already prepared in the codebase.

## A Pulse starting focus is memory—with separate approval

Treat this as a dedicated, user-authored **Pulse focus**, rather than silently extracting permanent facts from onboarding text. Typing and choosing a chip only creates a draft. No AI call happens during typing or profile questions. On review, **Save focus & start** explicitly stores the person's exact chosen words; **Start without saving focus** discards the proposed memory.

Pulse data-sharing permission and memory approval are distinct. If Pulse is declined, don't store a lasting Pulse focus or send it to the provider; offer the ordinary start path instead. A skipped/empty goal must also change the final button to “Start with today,” without an empty memory write.

Implementation requirements after selection: account-owned storage with owner-only policies, deletion cascade, no global shared defaults, stale-request/account-switch protection, editable/forgettable focus in Profile, no clinician/dosing promises, and no inferred diagnoses or allergies. Sending a saved focus to Pulse still requires AI sharing permission. Consent is not permission to keep every onboarding sentence forever.

## Logo, Cove and loading

Use the approved living-dot Footing wordmark and lime-window icon. Cove welcomes and accompanies; Pulse remains the coach. No Cove speech bubbles, invented poses, reward theatrics or conflated identities. The final mockups correct the retired ring-plus-wordmark that appeared in early generated drafts.

Show the new logo on the first usable welcome/sign-in surface and, if needed, the app-owned auth-restoration loading view. Don't add a timed logo splash or replay onboarding on every launch. Keep the system launch screen close to the first screen's background/layout; branding content belongs in the usable welcome. No animation should delay Continue; respect Reduce Motion.

## Scope and sources

No production onboarding, loading view, backend, App Store record or TestFlight release was changed. These are image-based concept storyboards, not interactive prototypes or new canonical Cove assets. Generated mockups may approximate fine typography/art details; implementation must use the original approved logo/character files, not crop masters out of a mockup. Native output files are preserved; final selected versions are copied unchanged into `mockups/`. `provenance.json` records exact prompts, revisions, references and hashes.

- Current sources: `NutriPulse/Features/Onboarding/`, `NutriPulse/App/RootView.swift`, `NutriPulse/Features/Auth/AuthView.swift`, `NutriPulse/Info.plist`.
- Brand authority: `docs/cove.md`, `docs/brand-architecture.md`, `docs/approved-cove-brand.md`, `marketing/brand/current/`, approved v2.1 pose library and original identity board.
- [Apple onboarding guidance](https://developer.apple.com/design/human-interface-guidelines/onboarding): keep setup focused and use contextual guidance where possible.
- [Apple privacy guidance](https://developer.apple.com/design/human-interface-guidelines/privacy): make the reason for a permission clear in context.
- [Apple launching guidance](https://developer.apple.com/design/human-interface-guidelines/launching): keep launch fast and distinguish system launch from onboarding.

Choose the light refresh for the smallest pre-review change. Choose the goal-first flow for a more personal launch experience. Keep the try-first flow as a deliberate product decision rather than a rushed cosmetic change.

## Selected flow revision — October 21

[Revised Start with what matters storyboard](mockups/02-start-with-what-matters-revised.png). The first four screens retain the selected direction. The final screen adds one grouped “Make it yours” section: Set nutrition targets (review/edit existing estimates), Tell Pulse what matters (review/edit the current draft), and Connect Apple Health (optional). These are shortcuts, not extra required steps. The explicit save-focus and start-without-saving actions remain. If Pulse was declined, use the ordinary start path and do not save or send a Pulse focus. Original concepts are preserved. No app changes or build were made for this revision.

## Native implementation — October 21

[Actual simulator screens](implemented/five-screens.jpg) · [Design QA](implemented/design-qa.md) · [Implementation notes](../../docs/onboarding-start-with-what-matters.md). The approved flow is implemented locally, with no TestFlight upload or server deployment.
