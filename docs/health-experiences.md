# Health-connected experiences

Implemented locally October 24, 2026. TestFlight remains on hold. No migration, Edge Function deployment, release archive or upload is part of this change.

## Experiments with less logging

In Make today easier → Try a small change, Apple Health linking is optional and off initially. New experiments can observe walking workouts within an editable local-clock time window, or use following-night sleep hours as the outcome. A sleep-outcome experiment asks only for an explicit tried/not-tried confirmation; it never creates a made-up 1–5 sleep rating. Existing experiments can add Health observations without replacing their original outcome or ratings.

Health observations are read on opening, explicit refresh, and foreground return. Up to 14 recent experiment days are shown. Walking intervals are clipped to the selected window and overlaps merged; steps alone do not imply a particular walk or a meal time. Sleep following an experiment day is paired with that day, and today's morning sleep window must end before comparison. Source-conflicting/implausible sleep is excluded. No samples means unknown, including when read access is unavailable.

Only explicitly confirmed tried/not-tried days form comparison groups, with at least three observed days in each group. Comparisons describe observations, not causation. Health readings never automatically mark an experiment complete or a day missed. Unlinking leaves the person's own entries intact. Old experiment files decode without the optional linkage/outcome fields. Rating-less confirmations are supported without manufacturing subjective ratings.

## Personal shot-cycle picture and weekly reflection

Pulse’s opening screen now presents compact on-device summary cards for a linked experiment, a qualifying shot-cycle picture and the weekly reflection. Only available, useful summaries appear; an exploration link provides setup when there are none. Tapping opens a detail view rather than a conversation. The standalone Today entry has been removed. The shared, screen-owned loader reads the current account's existing check-ins and injection/skip history and combines them with this phone's available Health observations. No AI request or new remote write occurs.

Cycle matching uses actual injection dates, not modulo-seven arithmetic. It requires the same cycle day in at least three distinct completed cycles at the current medication/dose. The current cycle, different regimens, interrupted/skipped or irregular intervals, future injections and other accounts' reports are excluded. Up to six qualifying previous cycles and 84 days of check-ins are considered. Sleep and steps are reported only with at least three matched observations; sleep is the night preceding the check-in. Patterns describe recorded experience without predicting symptoms, inferring a medication effect or suggesting dose changes.

Beyond the scale reflects the last seven complete days: Health-recorded strength sessions, walking-workout days, steps per observed day, sleep per observed night, and self-reported energy. Coverage accompanies summaries. Sleep, steps and energy need at least three observations. Missing movement is not a rest day. No score, streak, catch-up requirement, or scale-only verdict is added.

## Gentler days and recovery

A shorter-sleep priority card offers familiar food, lighter tracking, or dismissal for today. It requires sleep at least one hour below a personal baseline with at least three prior observations, and excludes source changes/conflicts, implausible/abrupt changes and inconsistent-wear flags. It respects lighter tracking, return support and tailored weekly circumstances, and asks how the person feels rather than assigning readiness.

Workout recovery offers familiar favorite-based protein options through the existing review/logging flow, and opens the water size picker instead of silently choosing an amount. Diary gaps are explicitly provisional; logged targets do not establish recovery. Buttons stack, and the recovery eyebrow sits above the header for accessibility text sizes.

## Ownership and privacy

- Experiment settings and confirmations use the existing protected, per-account local store and generation guards.
- Health observations are ephemeral and refreshed from this phone. They are not uploaded or added to an approved memory. Pulse reflection receives the person's existing experiment summary, not the Health samples or computed Health comparison.
- Pattern reads filter saved rows to the expected owner in addition to existing server RLS. Ownership is checked after awaits; account changes invalidate requests, clear view data and close the sheet.
- Apple Health is a device store, not a Footing-account store. The screen explicitly asks to use this phone's Health data. Access choices remain controlled by Apple Health, and empty reads are never represented as proof of permission denial.
- No new Health categories or server tables are requested. Existing Pulse consent and explicit memory approval remain unchanged.

## Verification and remaining device checks

The full regression run executed 508 unit tests: 501 passed, seven optional live checks skipped, zero failures. Six related UI tests passed (Everyday Tools, search and Health experiences). After final sleep-outcome/local-clock changes, 14 focused unit/rendering tests and three Health UI tests passed. Tests cover legacy files, overlap deduplication, local-clock daylight-saving windows, unknown-day preservation, minimum group sizes, dose/account/skip exclusions, sparse data and partial-day exclusion. Large-text screenshots were inspected and a cramped recovery header corrected.

No-network fixtures use fictional data. They do not authenticate, request Health access, read HealthKit or persist anything. Captures are in `build/health-experiences/` and result bundles are recorded in the task's tool logs.

Before release, verify on a signed-in iPhone with real Health history: access allowed/denied/partial; a recorded walk inside/outside the chosen window; overnight sleep after a confirmed experiment day; deletion/revocation and refresh; foreground refresh; account switch during a read; sparse and sufficient real cycle history; water/favorite review actions; and short-sleep dismissal/lighter tracking. Simulator fixtures cannot validate physical-device Health permissions or Watch ingestion. TestFlight stays on hold pending that acceptance work and the user's next build request.


## Pulse placement and detail redesign

The Pulse opening screen places Worth a look beneath the greeting and ahead of conversation starters. One card is featured in violet; secondary cards use the existing white Daylight surfaces. There are no automatic AI messages, memory writes, or new attention-budget questions.

Experiment details have a violet summary, a labelled recorded-data chart, and explicit tried/not-tried group averages when eligible. Weekly and cycle details use a tonal hero and large metric tiles with coverage. Methodology, source limits, privacy and refresh/access controls live under How Footing worked this out. Confirmation remains separate and initially unknown. Existing eligibility thresholds are unchanged.

The same experiment detail is reachable through Pulse, Make today easier → experiments, and Progress → Personal experiments. Open Experiments from Pulse opens the existing Personal experiments area; its small-experiment cards and management link preserve access to the local tools and original goal-based experiments.

The ephemeral Pulse snapshot is published atomically only if its original owner/request still matches. New unit tests exercise a delayed account-A response arriving after account B has loaded, plus signed-out reads and owner-scoped cache invalidation. Nothing from A is published into B. UI tests traverse summary cards to details and the existing Experiments page. Screenshots use fictional fixtures and genuine production views, including the Footing tab bar.

Updated review images: `build/pulse-health-review/`. TestFlight remains on hold; physical-device HealthKit acceptance remains outstanding.

Placement/redesign verification: ten focused unit tests and four native UI tests passed with zero failures. The UI tests cover opening details from Pulse, opening the same Health experiment from Experiments, navigating to Personal experiments, preserving unknown confirmations, methodology disclosure, and largest accessibility text-size navigation. The final simulator build also passed. Normal captures in `build/pulse-health-review/` were inspected against current Daylight surfaces/type and the production Pulse header/tab bar. Physical HealthKit acceptance remains outstanding.

## Today’s fit, an easier-day recipe, and a quiet finish

The cycle detail now asks Does this fit today? Sounds familiar, Today feels different and Not useful are explicit local choices, keyed to the local day/cycle day in the protected account file. Today feels different leads the Pulse summary/detail instead of treating prior-cycle observations as today's experience. Not useful hides the cycle card for today with an explicit restore link on Pulse. It never changes check-in ratings or learns a lasting pattern. The short bounded feedback history is device-only; only today's matching choice affects the UI. Tell Pulse about today is a separate explicit handoff through the existing AI consent flow; no message is sent on selection.

Sounds familiar offers Keep what helps on days like this. The recipe accepts a situation and any useful combination of familiar food, a water shortcut and support preferences. It shows its full character budget and opens the existing exact-wording memory editor. No recipe is remembered until Approve and remember succeeds. The confirmation displays exactly the text passed to the successful save, and editing is disabled while that save is pending. Cancel, failed approval and account changes cannot produce an approved state. Recipe approval changes no targets or reminder settings; the approved memory remains editable/forgettable in What Pulse knows.

After six distinct newly confirmed observation days, a quiet reflection offers Keep trying, Make it easier or Finish here. Keep trying preserves the experiment and leaves the prompt until six more confirmed days. Make it easier archives the original and creates a separate linked version with zero confirmations; original observations are never pooled into the new action. The Health observation configuration carries over and can be reviewed/unlinked in Experiments. Finish here retains observations and an optional reflection without a success/failure verdict. Capacity or validation failure leaves the original untouched. A successful reflection offers the recipe builder; a reflection note can prefill an editable support draft, but still needs separate memory approval.

The new fields are optional so older account files decode unchanged. Tests exercise local-day expiry, undo, owner switching/stale generation, recipe limits, wrap-up eligibility, fresh-version history, capacity, and codec compatibility. Native UI checks cover different-day feedback, editable recipe review with preview approval disabled, and next-step validation. Fixtures never write memories or modify experiments.

Final checks for these three additions: 519 unit tests executed with seven optional live checks skipped and zero failures; six related native UI tests passed. The nine memory-isolation tests were rerun successfully after tightening the approval confirmation to use stored wording. Captures are in `build/health-nextsteps/`. TestFlight remains on hold; no release archive, server deployment or upload was performed.
