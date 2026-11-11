# iPhone Duo readiness audit

2026-11-07

Footing has dedicated expanded layouts for Today, Progress, Pulse, Profile and shot logging, with a reserved navigation rail in wide landscape windows. Secondary pages and custom sheets use bounded reading widths, and short-window water and confirmation flows can scroll. Simulator coverage is recorded below. Physical Duo display transitions and live integrations remain release checks.

## Layout by screen family

| Screen family | Current behavior | Verification scope |
| --- | --- | --- |
| App shell | Landscape windows at least 720 pt wide use a 68 pt reserved rail lane with 44 pt controls. Portrait keeps the floating bottom bar. The same TabView, selected tab, navigation stacks and logger state remain mounted. | Rail reachability, reserved space, tab selection, Log action and portrait restoration tested. |
| Today | A 55/45 dashboard split gives the overview enough width for paired protein and calories/macros beside meals/notes. Date and the ranked priority card share the top row; the ordinary Pulse check-in becomes compact in rail mode. | Paired tile geometry, initial viewport fit, open logger retention and compact fallback tested. |
| Progress | Floor-day results/notices occupy the left lane; statistics and report links occupy the right. Narrow layouts preserve hero, statistics, notices, reports order. The count has its own row so the comparison badge cannot squeeze its label. | Column placement and selected range retention through rotation tested. |
| Pulse | Suggestions and conversation/composer scroll independently in expanded windows. The sidebar is 240 pt, the canvas is capped at 1100 pt, and rail mode removes the bottom-bar spacer. Accessibility text returns to one column. | Start/conversation placement, transcript scrolling and an unsent draft surviving collapse/expansion tested. |
| Profile | Identity header spans the canvas. Targets/highlights and health settings use the wider left lane; coaching and support/account settings use the right. Existing AnyView boundaries protect the device stack budget. | Expanded controls, rotation, large-text rendering and device stack-budget checks tested. |
| Shot logging | Dose and site controls use the left lane; hold-to-log and next-shot reminder use the right. Narrow/large-text layouts stack. At large text the site grid becomes one column and the hold target grows. Confirmation content can scroll. | Normal controls fit without scrolling; unsaved dose and site selection survive rotation. Large-text reachability is included in the final sweep. No dose is submitted. |
| Food logging | At 700 pt of available width or more, meal controls and methods occupy a scrolling 220 pt sidebar beside the active workspace. The canvas is capped at 1100 pt; narrow windows and XXXL text or larger retain the stacked layout. Compact height reduces secondary chrome while typing, with manual entry/attribution in scrolling content. | Actual-sheet Talk draft retention, Search query/meal retention across methods and rotation, method target sizes, keyboard results and Close reachability tested. Scan/Favorites share the workspace; live camera/microphone checks remain outstanding. |
| Barcode scan | Preview uses AVFoundation's rotation coordinator; the viewfinder fits the preview height. | Source/build checks. Camera input, camera switching and interruption recovery need hardware. |
| Onboarding | Header, actions and page content share a 600 pt width limit. Nutrition-target editing and the legacy step container are bounded too. | All five steps rotate with their screen titles retained; editing and large-text routes still need full device review. |
| Goals and Strong Week | Main canvases and experiment details have reading-width limits. Existing loading, retry, navigation and generation state ownership remain unchanged. | Goals and Strong Week fixture screens rotate in the secondary-family sweep. Live generation is not exercised. |
| Everyday Tools and health patterns | Main tools, recipe, experiment/health details and memory editors have bounded canvases. | Tools chooser rotates in the sweep. The remaining nested editors have source/build coverage. |
| Water and movement | Water has a scrollable outer canvas and bounded history viewport; accessibility text stacks presets. Movement uses a bounded scrolling canvas. | Water rotation and Close reachability are covered. Actual additions/deletions are not exercised. |
| Consent and preferences | Pulse/Food AI consent, What Pulse Knows, shot-cycle check-in, lighter tracking and related custom sheets now have explicit width limits. | Source/build coverage; individual permission and destructive-action states remain device checks. |
| Meal notes and usual meals | Note editors, offline notes, usual meals, rescue and repeat-meal confirmation have bounded canvases. Saved repeat-meal confirmation can scroll in short windows. | Source/build coverage. Live saves, undo, failure and retry states remain device checks. |
| Auth and password recovery | Sign-in, password-help and password-reset content is scrollable and bounded. | Source/build coverage. Authentication and recovery delivery need an account/device pass. |
| Body, Analytics, medications and settings forms | Shared `.daylightSubpage` and `.daylightForm` styles bound their canvases at 720 pt. | Source/build coverage and existing render checks; real histories, pickers and notification routes need device review. |
| Widgets | Separate extension and layout families. | Built with the app; widget and StandBy interaction checks remain separate. |

The [56-file scrolling/form inventory](iphone-duo-screen-inventory.md) distinguishes shared canvas coverage from embedded components. It is not a claim that every state in every file has been visually certified.

## Shared rules

- Use the current window proposal instead of screen dimensions or device names.
- `DaylightDashboardLayout` changes placement of stable children. At XXXL text or larger it stacks; compact section order is preserved. The nominal combined lane minimum is 600 pt plus the theme gap; Today/Profile assign 55 percent of that space to their first lane.
- `DaylightTileRow` retains its 160 pt per-tile minimum and large-text fallback. Wider overview lanes keep pairs intact at the tested rail width.
- Main expanded canvases are capped at 1100 pt. Forms/subpages and custom sheets generally cap at 720 pt; onboarding uses 600 pt.
- The rail reserves horizontal space and removes bottom clearance. It never floats over the page or Pulse composer.
- Existing Pulse consent gates, shot confirmation timing, save/retry guards and account ownership checks remain intact.
- iPhone device-family support and the iOS 17 deployment target are unchanged. This work does not declare iPad support.

## Simulator verification

Environment: Xcode 27.2, iPhone 17 Pro and iPhone SE (3rd generation) on iOS 26.5. No Duo simulator profile is installed. Preview routes use fixtures and unsigned builds, without live AI messages, permission grants or dose saves.

The broad sweep covers dashboard layouts, rail navigation, food search/keyboard behavior, Pulse draft retention, shot draft retention, Profile/layout rendering and device stack budget. The secondary-family rotation test opens all five onboarding steps, Goals, water, Strong Week and Everyday Tools. Earlier smaller-phone checks cover food search and navigation on iPhone SE. Final source changes add a large-text shot check and repeat the secondary sweep.

Transient SwiftUI invalid-frame diagnostics still appear during keyboard focus changes; their source is not established. Focused checks verify the affected controls remain reachable. Unsigned simulator HealthKit entitlement diagnostics do not verify live Health access.

## Remaining release checks

1. On physical Duo, fold/unfold on every main tab with a pushed destination, scrolling and an open sheet. Check selected day/range, draft, focus and navigation retention.
2. Repeat while saving or loading. Verify no lost edits, duplicate request or duplicate save, including food, medication and shot flows.
3. Test narrow side-by-side windows, both landscape orientations, accessibility text, VoiceOver, dark appearance and Reduce Motion with real data, long names and empty/error/loading states.
4. Scan and dictate across display transitions and app interruptions. Check camera selection/orientation, permission handling and resumption.
5. Verify live authentication, Health access, reminder delivery, notification deep links, undo/retry and confirmation states. Check widgets independently.
6. Review the keyboard diagnostic on device, then capture actual closed/open Duo screenshots before describing the release as Duo optimized.

## Platform references

Apple's [iPhone Duo overview](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/) describes display changes, rotation and side-by-side use. Its [layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout) recommends adapting to available space. The scanner follows the documented [preview rotation coordinator](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator/videorotationangleforhorizonlevelpreview).

## Verification results for the expanded shot and cross-screen pass

The initial broad run passed 19 tests, covering the main navigation/dashboard/Pulse/logging flows, shot draft retention, layout sizing and Profile rendering. The final run passed 12 tests: nine layout/Profile checks, the nine-screen secondary rotation sweep, normal expanded shot controls/draft retention, and large-text shot control reachability. The nine secondary screens comprise five onboarding steps, Goals, water, Strong Week and Everyday Tools.

Additional source fixes bound custom consent, memory, meal, health/experiment and recovery canvases. Water and saved repeat-meal confirmation can scroll in short windows; password reset now has a scrolling recovery form. The final app build verifies those source changes. Expanded-shot screenshots use a preview dose and do not record a dose.

## Expanded food logging workspace

Food logging uses AnyLayout to move the same active workspace between a stacked phone layout and a sidebar arrangement. The sidebar contains the meal menu, Close, Talk/Search/Scan/Favorites, meal notes and restaurant context. Past-day logging shows its date. Both the method list and active workspace can scroll independently in short windows.

Talk uses a shorter horizontal microphone panel in expanded windows, with typing and usual meals below. The microphone's expanded hit area stays fixed rather than including its decorative idle pulse. Method rows have explicit labels and rectangular 44 pt targets. Search keeps its existing result actions and attribution. Save/undo, consent gates and restaurant locking retain their existing state and callbacks.

Fixture tests cover the actual sheet opened from Today, Talk draft retention through rotation, Search query and selected meal retention across method changes and rotation, sidebar/workspace placement, 44 pt targets, and Close access with the keyboard open. Existing portrait search keyboard regressions are also run. These checks do not capture audio, request camera permission or save food.

Expanded food logging verification: all three existing food-search/navigation keyboard regressions passed, followed by both final expanded-layout checks passing with zero failures. The actual-sheet Talk capture and fixture Search captures were exported from the successful final build. Live scan, audio capture and save/undo verification remain device checks.

## Scan and Favorites expanded pass

Scan stays clipped to the active logging workspace. The viewfinder accounts for short-window height and keeps its instruction inside the bottom edge. Camera permission guidance scrolls independently so Settings remains reachable. DEBUG-only screenshot routes render an explicitly labelled simulated camera and the denied-permission state without requesting permission or initializing capture hardware.

Favorites uses adaptive columns with a 160 pt minimum, content-sized cards and 44 pt add/star controls. XXXL and accessibility text use one column with unrestricted food-name wrapping; the Recents heading stacks. At these sizes the shared logging method selector becomes a menu to avoid truncating four adjacent labels. The regular expanded sidebar and portrait segmented control remain at smaller text sizes. Preview favorites use read-only fixtures.

Verification: six focused simulator UI tests passed with zero failures (two existing expanded food logging checks and four Scan/Favorites checks). Coverage includes method/meal retention through rotation, adjacent favorite cards, largest accessibility text single-column scrolling, Scan caption bounds and reachable permission controls. Exported captures show the normal expanded Scan/Favorites workspaces plus permission and large-text states. The camera image is simulated; live barcode capture and physical Duo display transitions remain release checks.

## Food detail and confirmation review

Food detail places serving/meal/quantity controls beside nutrition in windows at least 700 pt wide, capped at 1100 pt. Each form column scrolls independently. Expanded nutrition rows use smaller vertical insets; the large-text fallback stacks the form. The Log Food action remains outside the scrolling region and bounded to 720 pt. Failed detail loading can scroll, retaining retry and navigation access. Cancel also dismisses the presented sheet after resetting detail state.

Parsed Talk confirmation uses adaptive food cards, with inclusion targets of 44 pt and separate quantity rows so steppers do not compress food names. Large text uses one column, names wrap, and the primary action can grow vertically. Estimate acceptance, inclusion, serving changes, correction and save/retry behavior retain their existing bindings and guards.

Familiar-food review uses the shared two-lane layout for food context and serving/nutrition controls. Its body now scrolls between a persistent header and save action. Repeat-meal confirmation places its item list beside an adaptive macro grid when space allows and stacks at larger text sizes. DEBUG-only fixtures exercise the real views without database lookups or food saves.

Verification: all six review UI checks passed after correcting test selectors for the native familiar-food Stepper. Detail serving edits and recalculated nutrition survive portrait/landscape rotation, including Cancel dismissal. Talk inclusion survives rotation with 44 pt controls. Familiar-food edits retain recalculated nutrition. Repeat-meal actions remain reachable in both orientations. Largest accessibility text checks keep primary actions reachable in detail, familiar review, repeat confirmation and Talk confirmation. The two existing expanded Talk/Search regressions also passed. Captures were inspected after fixing split serving labels and reducing expanded nutrition row insets so all five nutrition rows are visible above Log Food at the tested 874 × 402 pt window. Physical Duo transitions and live food saves remain device verification tasks.

## Manual entry and meal notes

Manual entry puts food identity, meal and quantity beside nutrition fields at widths of at least 700 pt, capped at 1100 pt. Large text uses a stacked form. Food identity comes first; each expanded form column scrolls independently. The Log action reserves its own footer space and can wrap long food names. Explicit field focus and a keyboard Done action support both regular and decimal keyboards. Numeric fields still commit sanitized values per keystroke, retaining zero-calorie food support and existing save validation.

Meal/day note editing uses the shared two-lane layout: context beside the editor and character count. The body scrolls between the header and save action. While typing, context and Save collapse so the editor fills the available width; Done restores the review layout. Larger text stacks these lanes. Existing note validation, save/retry state, edit handling and undo callbacks remain in place. DEBUG screenshot launch flags block food/note persistence; no save actions are invoked during layout checks.

Verification: the final three focused UI tests passed with zero failures. They cover manual food/calorie entry, note typing, explicit keyboard disappearance after Done, draft retention across portrait/landscape, active calorie-field bounds above the reserved Log footer, and primary-control reachability at the largest accessibility text size. Both expanded screens and their keyboard states were captured. A follow-up keyboard review found the note editor was losing its viewport to persistent chrome; the focused typing layout now collapses context/Save and bounds the editor to its visible scrolling area. No food or note was saved. Physical Duo fold/unfold, VoiceOver and live persistence remain release checks.

The final focused-note check passed after reducing typing-mode vertical padding: the editor's full frame stays within the visible scroll area and above the keyboard. Done restores the two-column context/editor layout without losing text. Final normal and keyboard captures were re-exported and visually inspected.

## App-wide audit — 2026-11-08

The final source sweep covers all App/Features SwiftUI view files, including nested sheets instead of relying only on a file's main width modifier. The scrolling/form inventory now includes 60 feature files; the broader catalog records 92 feature view files, embedded children and inactive legacy onboarding components. See [the full audit](duo-full-screen-audit.md) for every source and captured state.

Remaining layout fixes bound medication settings/edit/correction/conflict canvases, nested goal details/completed lists, experiment lists, notification explanations, saved memories/data sheets and the optional onboarding focus editor. Calendar and recovery states now scroll in short windows. Completed-goal cards grow with content and use one column for large text. Feedback uses stacked choices for large text and has keyboard Done. The main reserved rail/portrait bottom bar behavior remains intact.

All 54 distinct final checks passed (45 UI and 9 rendering/layout checks); Debug and unsigned simulator Release builds succeeded. These include all major screen families, nine secondary rotation routes, current food/shot/draft/keyboard regressions, large-text exceptions, reachable primary actions and populated chart fixtures. Final captures were exported for the review gallery. No authentication, AI/chat/feedback submission, consent/permission grant, food/dose save or conflict resolution was performed. Physical Duo transitions, live account histories, camera/audio/Health access, real save/undo during resizing, notifications and system widgets remain device release checks.

## Regular iPhone portrait verification — 2026-11-11

`PortraitReviewCaptureUITests.testMainScreensInPortrait` passed on the iPhone 18 Pro simulator (iOS 27.0). It opens Today, Progress, Pulse and Profile with read-only tour fixtures, checks portrait geometry and selected bottom-navigation tabs, and captures each screen. All four captures were visually reviewed. No production behavior changed for this capture pass.

Screenshots: `/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/portrait-2026-11-11/`. Result bundle: `/tmp/footing-portrait-review.xcresult`. This confirms the tested regular-phone portrait states; it does not replace physical Duo transition or live integration verification.
