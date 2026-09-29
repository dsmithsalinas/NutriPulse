# Goals option 3 — design QA

- Source visual truth: `/Users/dustinsmith-salinas/.codex/generated_images/01a05397-0175-79f1-94c0-3f4894972f4f/exec-85789fef-166a-4991-b34a-9ca2665dd84e.png`
- Implementation screenshot: `/Users/dustinsmith-salinas/.codex/visualizations/2026/08/30/01a05397-0175-79f1-94c0-3f4894972f4f/goals-option3-implementation-final.png`
- Source pixels: 853 × 1844; generated mobile target: 390 × 844 points.
- Implementation pixels: 1206 × 2622 at simulator 3× density; iPhone 17 viewport: 402 × 874 points.
- Density normalization: both artifacts were opened together at aspect-fit scale. Evaluation is limited to app-owned content; the implementation's iOS status area and home-safe-area infrastructure are excluded from fidelity findings.
- State: light mode, Active goals, August 30, caffeine intervention goal with known success/miss/missing days, automatic monthly step goal.

## Full-view comparison evidence

The implementation preserves the selected direction's hierarchy: Goals/date header, plus action, Active/Completed segment, a single intervention hero, seven-day evidence, explicit Yes/Not today/No data actions, a restrained Pulse explanation, an automatic-source goal row, and the existing Footing bottom bar. The screen uses Footing's real adaptive lavender ground, card/hairline tokens, rounded system typography, indigo primary color, Pulse asset, and SF Symbols rather than rasterizing the mockup.

The reference omits operating-system chrome as requested, while the native capture includes it. That reduces the amount of lower content visible before scrolling but does not obscure the persistent bottom bar or any control in the hero task.

## Focused-region evidence

The hero region was inspected at original density in both artifacts. The first implementation pass wrapped the goal title, used a generic check-in question, and rendered the missing-data action as weak plain text. The final pass keeps the title on one line, uses the goal-specific caffeine question, and gives No data / Skip a full-width outlined affordance with an accessibility explanation.

## Required fidelity surfaces

- Fonts and typography: native rounded/system Footing scale, matching weight hierarchy and improved single-line goal title. Dynamic Type remains enabled, intentionally taking precedence over pixel locking.
- Spacing and layout rhythm: 16-point outer/card padding, compact 14-point hero rhythm, continuous card radii, and persistent controls remain visible. Lower supporting rows scroll because the native viewport includes system safe areas.
- Colors and visual tokens: uses `Theme.Colors.ground`, `surfaceCard`, `surfaceInset`, `hairline`, primary indigo, and restrained semantic green/red state tints. Contrast remains readable in the captured light state.
- Image and icon fidelity: the real Pulse asset and platform SF Symbols are used. There are no emoji, placeholder assets, handcrafted SVGs, or rasterized UI.
- Copy and content: distinguishes confirmed misses from missing data, avoids causal language, and keeps Pulse's statement limited to facts available in the preview state. The mock's sleep association is intentionally absent until an experiment supplies real outcome evidence.

## Findings

No actionable P0, P1, or P2 visual differences remain.

## Comparison history

- Pass 1 — P2: the intervention title wrapped, the check-in question was generic, and Skip was visually too weak. Fix: compacted header typography, added goal-specific wording, and promoted missing data to an outlined action.
- Pass 2 — P2: the hero remained taller than the reference and pushed more supporting content below the fold. Fix: reduced internal spacing and supporting type sizes while retaining Dynamic Type and 44-point tap targets.
- Pass 3 — passed: hero hierarchy, interaction priority, Footing tokens, copy safety, and persistent navigation match the selected direction. Remaining viewport difference is expected native OS infrastructure.

## Implementation checklist

- [x] Match selected option 3 hierarchy and visual language.
- [x] Keep Yes, Not today, and No data semantically distinct.
- [x] Preserve Dynamic Type, accessibility labels, and safe-area navigation.
- [x] Use real Footing tokens and assets.
- [x] Verify the native target builds and renders on iPhone 17 simulator.

## Follow-up polish

- P3: add a small state legend only if usability testing shows the check, X, and dash are not sufficiently self-explanatory.
- P3: verify dark mode and accessibility text sizes in a later device matrix pass.

final result: passed

---

# Progress — all five summary improvements design QA

## Evidence

- Selected visual: `/Users/dustinsmith-salinas/.codex/generated_images/01a05b69-b960-71e0-a258-da8242e4f152/exec-a7a78e22-ec1c-4e92-9667-6ab1afec1e04.png` (853 × 1844; target 390 × 844 points).
- Native 30-day implementation: `/Users/dustinsmith-salinas/.codex/visualizations/2026/09/01/01a05b69-b960-71e0-a258-da8242e4f152/progress-all-five/02-progress-30-final.png` (1206 × 2622; iPhone 17 simulator at 402 × 874 points, 3× density).
- Native 90-day implementation: `/Users/dustinsmith-salinas/.codex/visualizations/2026/09/01/01a05b69-b960-71e0-a258-da8242e4f152/progress-all-five/01-progress-90-weeks.png` (1206 × 2622; same viewport and density).
- Native Since last shot summary: `/Users/dustinsmith-salinas/.codex/visualizations/2026/09/01/01a05b69-b960-71e0-a258-da8242e4f152/progress-all-five/03-summary-since-shot.png` (1206 × 2622; same viewport and density).
- The selected visual and native implementation were opened together at original density. States exercised: 30 days, 90 days, Since last shot, current summary, previous summaries, and range-preserving All Trends navigation.

## Full-view and focused-region comparison

The native implementation preserves the selected direction's hierarchy and visual language while extending it to the requested range-specific states. The 30-day landing view retains the range control, evidence-aware hero, Worth Noticing directly below it, and grouped Progress destinations. At 90 days the daily strip becomes exactly 13 weekly intervals so the graphic remains readable. Progress Summaries adds Since last shot, 7, 30, and 90-day periods without disturbing the landing-page hierarchy.

The summary hero and timeline were inspected as the focused region. Period labels, date context, measured-day totals, and prior-period cards agree with the same deterministic preview dataset. Insufficient evidence is visibly differentiated from below-goal evidence, and the summary does not imply a trend until its minimum evidence threshold is met.

## Required fidelity surfaces

- Typography: Footing's native rounded/system scale and Dynamic Type preserve the selected hierarchy; summary metadata remains subordinate to the result.
- Layout and spacing: 16-point outer margins, compact segmented controls, continuous card radii, and native safe-area behavior match the established Progress system. Scrolling preserves full access on smaller devices.
- Color: existing `ground`, `surfaceCard`, `surfaceInset`, `hairline`, `ringTrack`, indigo, green, and orange tokens are used consistently.
- Images and icons: real SF Symbols and Footing assets only; no emoji, placeholders, handcrafted SVG, or rasterized interface UI.
- Copy: neutral language replaces unsupported claims; no-goal periods say Logged rather than Met; confident observations require repeated evidence across at least two shot cycles.

## Primary interactions tested

- Changing 7/30/90 on Progress reloads that range and displays a loading state rather than stale values.
- Progress Summaries opens with the landing-page period selected and supports Since last shot, 7, 30, and 90 days.
- A 90-day selection renders exactly 13 weekly intervals covering the complete 90-day window.
- Since last shot uses the latest injection date and presents a clear empty state when no shot is available.
- Previous summaries show comparable completed periods; All Trends receives and preserves the selected range.
- Aggregate timeline accessibility labels distinguish measured, below-goal, unknown, and insufficient-evidence intervals.

## Comparison history

- Pass 1 — P1 trust issue: the Summary preview generator did not match the Progress landing totals for the same 30-day period. Fix: consolidated the preview assumptions so both surfaces report the same 18 of 24 measured days.
- Pass 2 — P3 accessibility copy: the aggregate label could say “1 were below.” Fix: added singular/plural grammar for both the noun and verb.
- Pass 3 — passed: hierarchy, range continuity, evidence thresholds, 13-week readability, prior summaries, accessibility semantics, and Footing visual tokens are aligned.

## Verification

- Native build succeeds for the iOS simulator.
- Full XCTest suite passes after the final accessibility-copy correction.
- No actionable P0, P1, or P2 differences remain.

final result: passed

---

# Progress — selected option 2 revision design QA

## Evidence

- Selected visual: `/Users/dustinsmith-salinas/.codex/generated_images/01a05b69-b960-71e0-a258-da8242e4f152/exec-a7a78e22-ec1c-4e92-9667-6ab1afec1e04.png` (853 × 1844; generated target 390 × 844 points).
- Native implementation: `/Users/dustinsmith-salinas/.codex/visualizations/2026/09/01/01a05b69-b960-71e0-a258-da8242e4f152/progress-implementation-final.png` (1206 × 2622; iPhone 17 simulator at 402 × 874 points and 3× density).
- Both artifacts were opened in the same comparison input at original density. The native status area and home-safe-area infrastructure are excluded from app-content fidelity findings because the source intentionally omitted device chrome.
- State: light mode, 30 days selected, 24 measured days, 18 protein-floor days, six unknown days, one active goal, one active experiment.

## Full-view comparison evidence

The implementation preserves the selected hierarchy: Progress header, 7/30/90-day range control, date range, evidence-aware protein summary, met/below/unknown day marks, Worth Noticing directly beneath the summary, and a single grouped destination surface for Goals, All trends, Progress summaries, and Personal experiments. The custom Footing bottom bar now labels this destination Progress.

The native view uses real Footing tokens and SF Symbols. It does not rasterize the mockup or introduce generated UI assets. Content scrolls when Dynamic Type or a smaller device requires it; all four destination rows fit in the captured default iPhone 17 state after the final spacing pass.

## Focused-region evidence

The summary and destination regions were inspected at original density. The ring communicates the same 75% result, the day strip preserves explicit unknown days, and Goals includes the creation-management hint. The destination rows expose full accessibility labels and retain at least 52-point row heights.

## Required fidelity surfaces

- Fonts and typography: native rounded/system Footing typography preserves the source hierarchy and Dynamic Type. The implementation uses real data-safe wrapping rather than fixed image text.
- Spacing and layout rhythm: 16-point outer margins, compact native segmented control, continuous card radii, and a tightened 12-point section rhythm keep all primary content visible despite native safe areas.
- Colors and visual tokens: `Theme.Colors.ground`, `surfaceCard`, `hairline`, `ringTrack`, primary indigo, and calorie orange map directly to the established app palette.
- Image and icon fidelity: SF Symbols provide the target, trend, document, flask, drop, and navigation icons. There are no placeholder images, emoji, handcrafted SVGs, or rasterized interface elements.
- Copy and content: measured, below-target, and unknown days remain distinct. Worth Noticing derives from available shot-cycle evidence and uses an honest learning-state message when evidence is insufficient rather than displaying the mock's claim unconditionally.

## Findings and fixes

- Pass 1 — P2: native status and home safe areas pushed Personal experiments below the initial viewport. Fix: reduced nonessential vertical gaps, hero padding, ring size, day-mark height, and row padding while preserving readable type and minimum tap heights.
- Pass 2 — passed: all four destinations are visible, the requested Worth Noticing placement is preserved, and the persistent bottom navigation remains unobscured.

## Primary interactions tested

- Goals opens the existing Goals hub; its Create a goal control is exposed and accessible.
- All trends opens the existing analytics charts with a native back path.
- Progress summaries opens a dated, evidence-qualified summary and Pulse weekly review.
- Personal experiments opens the existing experiment surface.
- The 7/30/90-day selector is wired to reload the corresponding analytics range.

## Follow-up polish

- P3: evaluate whether the range-specific hero headline should compare against the preceding period once a dedicated comparison query is added.
- P3: capture dark mode and accessibility text-size variants in a later device-matrix pass.

final result: passed

---

# Goal Builder — Option 1 Design QA

## Evidence

- Selected visual: `/Users/dustinsmith-salinas/.codex/generated_images/01a05397-0175-79f1-94c0-3f4894972f4f/exec-e645bfe9-b77d-483c-a9a7-ddd6615b6ccb.png` (853 × 1844).
- Native implementation: `/Users/dustinsmith-salinas/.codex/visualizations/2026/08/30/01a05397-0175-79f1-94c0-3f4894972f4f/goal-builder-option1-final.png` (1206 × 2622, iPhone 17 simulator).
- Both artifacts were opened together for the final comparison at the same portrait interaction state: editable protein suggestion, Food & Protein Logs selected, step 1 of 3.

## Fidelity review

- Hierarchy: preserves the three-step header, editable suggested goal hero, source question, automatic source list, compact manual choices, and persistent Continue action.
- Typography and spacing: uses Footing’s real rounded system scale and native safe areas. The native header is centered by platform navigation while the mock’s title is leading-aligned; this is expected template-owned iOS infrastructure.
- Color and surfaces: matches Footing’s lavender ground, white card surfaces, indigo selection, subtle hairlines, and restrained secondary text.
- Icons: uses SF Symbols only. No emoji, fake imagery, custom SVG, or rasterized interface elements were introduced.
- Interaction: the title is editable; automatic and manual sources are mutually exclusive; Apple Health exposes specific metrics; steps 2 and 3 configure success and review the finished goal.
- Product correctness: protein is labeled Food & Protein Logs, water is labeled Water Logs, and workout data is described as Footing plus Apple Health. The mock visually selected both food logs and Yes / No; the implementation intentionally resolves that contradiction by allowing exactly one source.

## Findings and fixes

- Pass 1 — P2: Body Measurements added a fifth automatic row and pushed the manual input choices below the first viewport. Fix: retained the source model for future use but removed it from this focused first-release list.
- Pass 1 — P2: the selected automatic source relied only on a trailing checkmark. Fix: added the selected row’s indigo outline and lavender inset treatment.
- Pass 2 — passed: the complete core decision fits in the native viewport, the selected data source is unmistakable, and the main Continue action remains persistent.

## Follow-up polish

- P3: consider exposing Body Measurements under a later “More connected sources” affordance once source discovery is tested with users.
- P3: validate the three-step builder at accessibility text sizes after the beta feedback pass.

final result: passed

---

# Progress — pre-build naming and ownership fixes

## Evidence

- Source visual truth: `/Users/dustinsmith-salinas/.codex/visualizations/2026/09/01/01a05b69-b960-71e0-a258-da8242e4f152/prebuild-audit/02-progress.png`, `04-all-trends.png`, and `01-since-shot.png`.
- Revised implementation: `/Users/dustinsmith-salinas/.codex/visualizations/2026/09/01/01a05b69-b960-71e0-a258-da8242e4f152/prebuild-fixes/01-progress-analytics.png`, `02-analytics-clean.png`, and `03-summary-copy.png`.
- Viewport: iPhone 17 simulator, 402 × 874 points at 3× density. Every capture is 1206 × 2622 pixels, so no density normalization was required.
- State: light mode, 30 days selected, deterministic Progress preview data.
- Source and implementation screenshots were opened together in a single comparison input at original density.

## Comparison

- Full view: the Progress layout, spacing, hierarchy, and destination-card proportions are unchanged. “Analytics” replaces “All trends” without wrapping or displacing another row. Analytics now leads directly with its cycle-pattern chart and the 30-day selector remains selected.
- Focused regions: the destination title/subtitle, Analytics header/first card, Summary period picker, and suggestion label were readable in the full-density comparison. No separate crop was needed.
- Typography and spacing: established Footing rounded/system typography and native spacing remain intact; the shorter labels fit their existing controls.
- Colors and tokens: no palette or semantic-color changes.
- Images and icons: existing SF Symbols and Footing assets remain unchanged; no generated or placeholder imagery was introduced.
- Copy and content: Analytics is discoverable by its established name; the trailing-seven-day review no longer implies it describes a selected 30-day period; “ONE THING TO TRY” no longer implies a tracked experiment; “Last shot” is compact and consistent with the full explanatory heading.

## Comparison history

- Pass 1 — P1: the destination omitted the known Analytics name, and the selected 30-day Analytics screen opened with a seven-day card titled “Your week.” Fix: restored the Analytics title and removed the weekly narrative card from that screen.
- Pass 1 — P2: an untracked suggestion was labeled “ONE EXPERIMENT,” overlapping the meaning of Personal Experiments. Fix: renamed it “ONE THING TO TRY.”
- Pass 1 — P3: “Since shot” was less natural than the full heading. Fix: shortened the picker label to “Last shot.”
- Pass 2 — passed: all corrected labels fit, Analytics begins with detailed trend content, and the Summary hierarchy remains unchanged.

## Verification

- Progress → Analytics and Progress → Progress Summaries interactions were exercised in the simulator.
- Accessibility tree confirms the updated Analytics destination/title and suggestion label.
- Full XCTest suite passes; `git diff --check` passes.
- No actionable P0, P1, or P2 differences remain.

final result: passed
